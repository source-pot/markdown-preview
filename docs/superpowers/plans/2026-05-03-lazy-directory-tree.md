# Lazy directory tree implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the recursive up-front directory scan with on-demand lazy loading and an explicit refresh button, fixing the WebKit PAC crash on large directories and making opening any directory feel instant.

**Architecture:** `DirectoryNode` becomes a reference-typed `ObservableObject` whose children are loaded only when its `DisclosureGroup` is expanded. The `DirectoryWatcher` is removed entirely; the sidebar gains a refresh button (Cmd+R) that collapses the "current directory" and re-scans it. Auto-opening of the first markdown file is removed — the existing right-pane empty state handles the no-selection case.

**Tech Stack:** Swift, SwiftUI, AppKit, Combine, Swift Package Manager. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-05-03-lazy-directory-tree-design.md`

---

## File map

- **Modify:** `Sources/mdview/DirectoryNode.swift` — replace the `struct` with a class-based `ObservableObject` that loads children on demand.
- **Modify:** `Sources/mdview/AppState.swift` — drop watcher integration and auto-open; add `selectedNodeURL`; add `refreshCurrentDirectory()`.
- **Modify:** `Sources/mdview/DirectoryBrowser.swift` — replace `OutlineGroup` with a recursive `NodeRow` view built on `DisclosureGroup`; add a refresh-button toolbar.
- **Delete:** `Sources/mdview/DirectoryWatcher.swift`.
- **Untouched:** `Sources/mdview/ContentView.swift`, `FileWatcher.swift`, `MarkdownRenderer.swift`, `ThemeManager.swift`, `AppIcon.swift`, `MdviewApp.swift`, `main.swift`.

The build will be broken between Tasks 1 and 4. The single commit happens after Task 6 (manual verification passes).

---

### Task 1: Rewrite `DirectoryNode.swift` as a lazy-loading class

**Files:**
- Modify: `Sources/mdview/DirectoryNode.swift` (full replacement)

- [ ] **Step 1: Replace the file's contents in full**

Replace the entire contents of `Sources/mdview/DirectoryNode.swift` with:

```swift
import Foundation
import Combine

final class DirectoryNode: ObservableObject, Identifiable, Hashable {
    let id: URL
    let url: URL
    let name: String
    let isDirectory: Bool

    @Published var children: [DirectoryNode]?
    @Published var isExpanded: Bool = false

    private init(url: URL, isDirectory: Bool) {
        self.id = url
        self.url = url
        self.name = url.lastPathComponent
        self.isDirectory = isDirectory
    }

    static func make(url: URL) -> DirectoryNode {
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        return DirectoryNode(url: url, isDirectory: isDir)
    }

    func loadChildrenIfNeeded() {
        guard isDirectory, children == nil else { return }
        children = scanImmediateChildren()
    }

    func refresh() {
        guard isDirectory else { return }
        isExpanded = false
        children = scanImmediateChildren()
    }

    private func scanImmediateChildren() -> [DirectoryNode] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var dirs: [DirectoryNode] = []
        var files: [DirectoryNode] = []

        for child in contents {
            let isDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir {
                dirs.append(DirectoryNode(url: child, isDirectory: true))
            } else if child.pathExtension.lowercased() == "md" {
                files.append(DirectoryNode(url: child, isDirectory: false))
            }
        }

        dirs.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        files.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return dirs + files
    }

    static func == (lhs: DirectoryNode, rhs: DirectoryNode) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
```

Notes:
- `private init` keeps construction funnelled through `make(url:)` and the internal `scanImmediateChildren()` paths.
- `Hashable`/`Equatable` are by `id` (URL) so SwiftUI's `ForEach` and `List(selection:)` behave consistently with the previous implementation.
- The file/directory predicate is `.skipsHiddenFiles` and `.md` extension only — same as before, just non-recursive.
- No `firstMarkdownFile()` — auto-open is removed.

---

### Task 2: Delete `DirectoryWatcher.swift`

**Files:**
- Delete: `Sources/mdview/DirectoryWatcher.swift`

- [ ] **Step 1: Remove the file**

```bash
rm Sources/mdview/DirectoryWatcher.swift
```

There are no other references to `DirectoryWatcher` in the codebase besides `AppState.swift`, which Task 3 strips out.

---

### Task 3: Rework `AppState.swift`

**Files:**
- Modify: `Sources/mdview/AppState.swift` (full replacement)

- [ ] **Step 1: Replace the file's contents in full**

Replace the entire contents of `Sources/mdview/AppState.swift` with:

```swift
import Foundation
import Combine

class AppState: ObservableObject {
    @Published var currentFile: URL?
    @Published var markdownContent: String = ""
    @Published var refreshTrigger: UUID = UUID()
    @Published var rootDirectory: URL?
    @Published var directoryTree: DirectoryNode?
    @Published var selectedNodeURL: URL?

    private var fileWatcher: FileWatcher?

    func openFile(_ url: URL) {
        stopWatchingFile()
        currentFile = url
        loadContent()
        startWatchingFile()
    }

    func openDirectory(_ url: URL) {
        rootDirectory = url
        let root = DirectoryNode.make(url: url)
        root.loadChildrenIfNeeded()
        directoryTree = root
        selectedNodeURL = nil
    }

    func closeFile() {
        stopWatchingFile()
        currentFile = nil
        markdownContent = ""
        rootDirectory = nil
        directoryTree = nil
        selectedNodeURL = nil
    }

    func loadContent() {
        guard let url = currentFile else { return }

        do {
            markdownContent = try String(contentsOf: url, encoding: .utf8)
        } catch {
            markdownContent = "Error loading file: \(error.localizedDescription)"
        }
    }

    func triggerRefresh() {
        refreshTrigger = UUID()
    }

    func refreshCurrentDirectory() {
        guard let tree = directoryTree else { return }

        let target: DirectoryNode
        if let selURL = selectedNodeURL, let node = findNode(in: tree, url: selURL) {
            if node.isDirectory {
                target = node
            } else {
                target = parent(of: node, in: tree) ?? tree
            }
        } else if let curFile = currentFile,
                  let parentDir = findNode(in: tree, url: curFile.deletingLastPathComponent()) {
            target = parentDir
        } else {
            target = tree
        }

        target.refresh()

        if let curFile = currentFile, curFile.deletingLastPathComponent() == target.url {
            let stillThere = (target.children ?? []).contains { $0.url == curFile }
            if !stillThere {
                stopWatchingFile()
                currentFile = nil
                markdownContent = ""
                selectedNodeURL = (target.url == tree.url) ? nil : target.url
            }
        }
    }

    private func findNode(in node: DirectoryNode, url: URL) -> DirectoryNode? {
        if node.url == url { return node }
        for child in node.children ?? [] {
            if let found = findNode(in: child, url: url) { return found }
        }
        return nil
    }

    private func parent(of target: DirectoryNode, in node: DirectoryNode) -> DirectoryNode? {
        for child in node.children ?? [] {
            if child.url == target.url { return node }
            if let found = parent(of: target, in: child) { return found }
        }
        return nil
    }

    private func startWatchingFile() {
        guard let url = currentFile else { return }

        fileWatcher = FileWatcher(url: url) { [weak self] in
            DispatchQueue.main.async {
                self?.loadContent()
            }
        }
        fileWatcher?.start()
    }

    private func stopWatchingFile() {
        fileWatcher?.stop()
        fileWatcher = nil
    }
}
```

Notes:
- `openDirectory` no longer calls `openFile` — the right pane's existing empty-state branch in `ContentView.swift:21-26` covers the resulting state automatically.
- `closeFile` now also resets `selectedNodeURL`.
- All `directoryWatcher`-related code is gone.
- `refreshCurrentDirectory()`'s "selected node lookup" uses the in-memory tree's `isDirectory` flag rather than re-statting the filesystem — the spec calls this out explicitly under "Whether the selected URL is a file or directory".
- The deleted-file fallback walks the post-refresh `children` (not the filesystem) and sets selection to `nil` when the refreshed directory is the root, since `Section` headers aren't selectable rows.

---

### Task 4: Rewrite `DirectoryBrowser.swift`

**Files:**
- Modify: `Sources/mdview/DirectoryBrowser.swift` (full replacement)

- [ ] **Step 1: Replace the file's contents in full**

Replace the entire contents of `Sources/mdview/DirectoryBrowser.swift` with:

```swift
import SwiftUI

struct DirectoryBrowser: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var rootNode: DirectoryNode

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: { appState.refreshCurrentDirectory() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh")
                .keyboardShortcut("r", modifiers: .command)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            Divider()

            List(selection: $appState.selectedNodeURL) {
                Section(header: Text(rootNode.name).font(.headline)) {
                    ForEach(rootNode.children ?? []) { child in
                        NodeRow(node: child)
                    }
                }
            }
            .listStyle(.sidebar)
            .onChange(of: appState.selectedNodeURL) { newValue in
                guard let url = newValue else { return }
                guard let node = findNode(in: rootNode, url: url), !node.isDirectory else { return }
                appState.openFile(url)
            }
            .onAppear {
                appState.selectedNodeURL = appState.currentFile
            }
        }
    }

    private func findNode(in node: DirectoryNode, url: URL) -> DirectoryNode? {
        if node.url == url { return node }
        for child in node.children ?? [] {
            if let found = findNode(in: child, url: url) { return found }
        }
        return nil
    }
}

private struct NodeRow: View {
    @ObservedObject var node: DirectoryNode

    var body: some View {
        if node.isDirectory {
            DisclosureGroup(isExpanded: $node.isExpanded) {
                ForEach(node.children ?? []) { child in
                    NodeRow(node: child)
                }
            } label: {
                Label(node.name, systemImage: "folder")
            }
            .tag(node.url)
            .onChange(of: node.isExpanded) { newValue in
                if newValue {
                    node.loadChildrenIfNeeded()
                }
            }
        } else {
            Label(node.name, systemImage: "doc.text")
                .tag(node.url)
        }
    }
}
```

Notes:
- The refresh `Button` uses `.borderless` style so it sits cleanly above the list and inherits the expected hover/press affordances.
- `List(selection:)` is bound to `$appState.selectedNodeURL`; tags on each row + the `DisclosureGroup` provide the selectable values.
- The `onChange(of: appState.selectedNodeURL)` only triggers `openFile` for non-directory nodes; directory selections remain inert (used only by refresh).
- `findNode` is duplicated from `AppState` because `AppState`'s copy is private. Acceptable for a 6-line helper; promoting it to a shared file is YAGNI for now.

---

### Task 5: Build

**Files:** none (compile only)

- [ ] **Step 1: Build the package**

Run, from the repo root:

```bash
swift build
```

Expected: build succeeds with no errors. Warnings about deprecated APIs (e.g. `onChange(of:perform:)` vs the iOS 17+ two-parameter form) are acceptable — the project targets `.macOS(.v13)` per `Package.swift`.

If the build fails:
- Check that `DirectoryWatcher.swift` is actually deleted (Task 2) — leaving it in causes "use of unresolved identifier" errors only if something still references it; but compile errors inside the deleted file are also possible if it had typos.
- Re-read the diff against this plan, particularly type names (`DirectoryNode.make` vs `init`).

Do NOT fix compile errors by deviating from the plan — re-check the plan first.

---

### Task 6: Manual verification

**Files:** none (runtime testing)

The repro directory used during diagnosis: `/Volumes/T9/Developer/work/classic-classmanager/.worktrees/improvements` (~117 K entries, previously crashed). The "good" directory: `/Volumes/T9/Developer/work/classic-classmanager/.worktrees/improvements/docs` (~126 entries).

For each step below, launch the app via the built binary directly (NOT `swift run`, because the detach-from-terminal logic in `main.swift` interacts oddly with `swift run`'s wrapper):

```bash
.build/debug/mdview <path>
```

The window should open in the foreground; the launching shell returns immediately.

- [ ] **Step 1: Open the previously-crashing directory**

```bash
.build/debug/mdview /Volumes/T9/Developer/work/classic-classmanager/.worktrees/improvements
```

Expected:
- Window opens within ~1 second (no multi-second hang).
- Sidebar shows the root section header `improvements` and 13 immediate entries: 9 directories (`be`, `company-databases`, `development`, `docker`, `docs`, `infrastructure`, `local`, `openspec`, `tests`) followed by 2 files (`CODE_REVIEW_GUIDELINES.md`, `README.md`). (Directories first; files alphabetised.)
- Right pane shows "Select a Markdown file from the sidebar".
- **No crash.**

- [ ] **Step 2: Lazy expansion**

In the sidebar, click the disclosure triangle on `docs/`.

Expected: it expands and shows `docs`'s immediate children. No noticeable delay. Other top-level directories (e.g. `be/`) remain collapsed.

Now click the disclosure triangle on `be/`.

Expected: it expands. Because the immediate scan of `be/` is non-recursive, it should be fast even though `be/` contains tens of thousands of nested entries; only `be/`'s direct children (likely `src/`, `node_modules/`, etc.) are listed.

- [ ] **Step 3: Open a file**

Click `README.md` at the root level.

Expected: it loads in the right pane, rendered. The sidebar row is highlighted as selected.

- [ ] **Step 4: Refresh while a file is selected**

Press `Cmd+R` (or click the refresh button above the sidebar).

Expected: the parent directory of the selected file (the root `improvements/`) has its children re-scanned. Any expanded subdirectories of root collapse (they were rebuilt as fresh nodes). The currently-displayed `README.md` remains displayed in the right pane (the refresh re-found it; no deletion happened).

- [ ] **Step 5: Refresh with a directory selected**

Single-click `docs/` (the row, not the disclosure triangle) to select it. Expand it (triangle), expand `docs/architecture/` (triangle).

Press `Cmd+R`.

Expected: `docs/` collapses, its children are re-scanned. Re-expanding `docs/` shows its children with all sub-expansions reset.

- [ ] **Step 6: Refresh handles deleted file**

Make sure a file is open (e.g. `README.md` from Step 3). In another terminal:

```bash
mv /Volumes/T9/Developer/work/classic-classmanager/.worktrees/improvements/README.md /tmp/README.md.bak
```

Back in mdview, press `Cmd+R`.

Expected:
- `README.md` disappears from the sidebar.
- The right pane reverts to the empty-state message.
- No row is selected (because the refreshed directory is the root, which isn't a selectable section header).

Restore the file:

```bash
mv /tmp/README.md.bak /Volumes/T9/Developer/work/classic-classmanager/.worktrees/improvements/README.md
```

Press `Cmd+R` again. Expected: `README.md` reappears in the sidebar.

- [ ] **Step 7: Single-file mode regression check**

Quit the app (Cmd+Q). Then:

```bash
.build/debug/mdview /Volumes/T9/Developer/vibes/markdown-viewer/test.md
```

Expected: window opens with no sidebar (single-file mode), the file's contents render, no crash, no behaviour change vs. before this work. (This verifies we didn't break the "open a single file" path, which doesn't go through `openDirectory`.)

- [ ] **Step 8: Small directory regression check**

Quit. Then:

```bash
.build/debug/mdview /Volumes/T9/Developer/work/classic-classmanager/.worktrees/improvements/docs
```

Expected: window opens with the sidebar, right pane shows the empty-state message (we no longer auto-open a file). Clicking `index.md` opens it.

If any step fails, stop and report which one. Do not proceed to commit.

---

### Task 7: Commit

**Files:** all modified/deleted files in this plan.

- [ ] **Step 1: Inspect the working tree**

```bash
git status
git diff --stat
```

Expected: `Sources/mdview/DirectoryNode.swift`, `Sources/mdview/AppState.swift`, `Sources/mdview/DirectoryBrowser.swift` modified; `Sources/mdview/DirectoryWatcher.swift` deleted. No other changes.

- [ ] **Step 2: Stage and commit**

```bash
git add Sources/mdview/DirectoryNode.swift \
        Sources/mdview/AppState.swift \
        Sources/mdview/DirectoryBrowser.swift \
        Sources/mdview/DirectoryWatcher.swift

git commit -m "$(cat <<'EOF'
Lazy-load directory tree and add refresh button

Replaces the recursive up-front directory scan with on-demand children
loading. Opening a directory containing very large subtrees (e.g.
node_modules) no longer hangs the UI or triggers a WebKit
pointer-authentication crash inside font registration.

Removes the per-directory DispatchSource watcher in favour of an
explicit Cmd+R refresh button on the sidebar. Refresh collapses the
"current directory" (parent of selected file, or the selected dir
itself, or the root) and re-scans it; a deleted current file is
detected and the right pane reverts to its empty state.

Auto-opening of the first markdown file on `mdview <dir>` is removed;
the existing right-pane empty-state branch covers the new initial
state.

See docs/superpowers/specs/2026-05-03-lazy-directory-tree-design.md
for the design.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 3: Verify the commit**

```bash
git log -1 --stat
```

Expected: one commit, four files touched (3 modified, 1 deleted).
