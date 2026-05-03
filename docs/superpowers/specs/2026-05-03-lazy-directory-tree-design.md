# Lazy-load directory tree — design

## Background

`mdview <dir>` builds the sidebar tree by recursively scanning the directory on
the main thread before the window is shown. For large trees (e.g. a project
containing `node_modules`, where a single subtree contained ~117 K entries in
testing), this synchronous scan blocks the UI for several seconds and reliably
triggers a WebKit pointer-authentication crash inside
`initXTCopyPropertiesForAllFontsWithOptions` (called during the first
`WKWebView.loadHTMLString`, itself triggered by the first split-view layout
pass).

The WebKit crash is an OS-level bug we can't fix, but we control the conditions
that trigger it. Removing the up-front recursive scan also makes opening any
large directory feel instant.

## Goals

- Open large directories without crashing or blocking the UI.
- Sidebar lists only the immediate contents of a directory until the user
  expands a child.
- Provide an explicit refresh action, since automatic filesystem watching is
  removed (see "Non-goals" / "Removed behaviour" below).

## Non-goals

- Filtering well-known noise directories (`node_modules`, `dist`, etc.). Lazy
  loading alone is enough to avoid the crash; expanding such a directory is
  bounded by the user's deliberate click.
- Persisting expansion state across launches.
- Async background scans. Each lazy scan is one directory level on the main
  thread, which is fast even on cold cache.

## Removed behaviour

- Recursive up-front scan of the directory tree on open.
- Automatic discovery and auto-open of "the first markdown file anywhere in
  the tree" (`DirectoryNode.firstMarkdownFile()`).
- The `DirectoryWatcher` (per-directory `DispatchSource` file watchers
  recursing through the entire tree). Replaced by an explicit refresh button.

`FileWatcher` (which watches the single currently-displayed file) is unchanged.

## Design

### Tree model — `DirectoryNode.swift`

`DirectoryNode` becomes a `class` conforming to `ObservableObject, Identifiable,
Hashable`. Reference semantics are required because the tree mutates in place
on lazy load and refresh, and per-node `@Published` properties are required so
SwiftUI re-renders the affected row when its children load.

Shape:

```swift
final class DirectoryNode: ObservableObject, Identifiable, Hashable {
    let id: URL                // == url
    let url: URL
    let name: String
    let isDirectory: Bool
    @Published var children: [DirectoryNode]?  // nil = unloaded (dirs) or N/A (files)
    @Published var isExpanded: Bool = false
}
```

Methods:

- `static func make(url: URL) -> DirectoryNode` — constructs a node *without*
  loading children. `isDirectory` is determined from the filesystem.
- `func loadChildrenIfNeeded()` — no-op if `children != nil` or
  `isDirectory == false`. Otherwise scans the immediate contents of `url`
  using `.skipsHiddenFiles`, builds child nodes for every subdirectory and
  every `.md` file, sorts directories first then files (case-insensitive),
  and assigns to `children`. **No pruning** — every subdirectory is shown
  regardless of whether it contains markdown.
- `func refresh()` — sets `isExpanded = false`, then re-runs the scan and
  reassigns `children`. Old descendant nodes are dropped, so any deeper
  expansion or load state is forgotten.

`Hashable`/`Equatable` are by `id` (URL). `firstMarkdownFile()` is removed.

### Sidebar — `DirectoryBrowser.swift`

The current `OutlineGroup` cannot drive lazy loading because it doesn't expose
expand events. Replace it with a small recursive `NodeRow` view built on
`DisclosureGroup` bound to `node.isExpanded`. On expansion (`onChange` of
`isExpanded` going `true`), call `node.loadChildrenIfNeeded()`.

Structure:

```
VStack(spacing: 0) {
    HStack { Spacer(); refreshButton }   // thin toolbar
    List(selection: $appState.selectedNodeURL) {
        Section(header: Text(rootNode.name).font(.headline)) {
            ForEach(rootNode.children ?? []) { child in
                NodeRow(node: child)
            }
        }
    }
    .listStyle(.sidebar)
}
```

`NodeRow` is recursive: a directory renders a `DisclosureGroup` whose body is
`ForEach(node.children ?? []) { NodeRow(node: $0) }`; a file renders a
`Label`. Each row holds an `@ObservedObject var node: DirectoryNode`.

The refresh button is an icon-only `Button` with `Image(systemName:
"arrow.clockwise")`, a "Refresh" tooltip, and a `.keyboardShortcut("r",
modifiers: .command)`. It calls `appState.refreshCurrentDirectory()`.

### App state — `AppState.swift`

Changes:

- `openDirectory(_:)` sets `rootDirectory`, builds a root `DirectoryNode` via
  `DirectoryNode.make(url:)`, calls `loadChildrenIfNeeded()` on it (one
  level), assigns to `directoryTree`, and **returns**. No call to `openFile`.
- New `@Published var selectedNodeURL: URL?`. Bound by the sidebar `List`'s
  selection. When this changes to a non-directory URL, `openFile` is invoked
  (this can be done with an `onChange` in `DirectoryBrowser` or via a
  `didSet` on the property — implementation detail).
- New `func refreshCurrentDirectory()`:

  1. Determine the target URL:
     - if `selectedNodeURL` points to a file, use its parent directory;
     - if it points to a directory, use it as-is;
     - if `nil`, use `rootDirectory`.
  2. Walk `directoryTree` to find the `DirectoryNode` with matching `url`.
     If not found (selected row is no longer in the tree), fall back to
     refreshing the root.
  3. Call `refresh()` on that node.
  4. If `currentFile != nil`, the file's parent equals the refreshed
     directory's URL, and the file no longer appears in the refreshed
     `children`, then: clear `currentFile` and `markdownContent`, and set
     `selectedNodeURL` to the refreshed directory's URL.

- Remove the `directoryWatcher` property, `startWatchingDirectory()`,
  `stopWatchingDirectory()`, the `startWatchingDirectory()` call inside
  `openDirectory(_:)`, and the `stopWatchingDirectory()` call inside
  `closeFile()`. The other lines in `closeFile()` (clearing `currentFile`,
  `markdownContent`, `rootDirectory`, `directoryTree`) stay.

#### Whether the selected URL is a file or directory

Determined by walking `directoryTree` to find the node whose `url` matches
`selectedNodeURL` and reading its `isDirectory` flag. We don't hit the
filesystem here — the tree's view of the world is the source of truth for
this decision, and the refresh path itself is what reconciles tree against
filesystem.

#### Refresh on the root directory

The root is rendered as a `Section` header, not a `DisclosureGroup`, so it
has no expand/collapse state. Refreshing the root therefore drops all
existing children (any expanded descendants disappear because they are
discarded with their parent), assigns a fresh `children` array of new
collapsed nodes, and leaves `selectedNodeURL = nil` rather than trying to
"select" the section header (which `List(selection:)` doesn't support).

### Right pane — `ContentView.swift`

No code change required. The existing branch at lines 21–26 already shows
"Select a Markdown file from the sidebar" when `markdownContent.isEmpty &&
rootDirectory != nil`, which is exactly the state after `openDirectory(_:)`
returns under the new behaviour.

### Files

- Modified: `DirectoryNode.swift`, `DirectoryBrowser.swift`, `AppState.swift`.
- Deleted: `DirectoryWatcher.swift`.
- Unchanged: `ContentView.swift`, `FileWatcher.swift`, `MarkdownRenderer.swift`,
  `ThemeManager.swift`, `AppIcon.swift`, `MdviewApp.swift`, `main.swift`.

## Behaviour matrix

| Scenario | Result |
|---|---|
| `mdview <dir>` | Window opens immediately; sidebar shows root's immediate dirs + `.md` files (sorted, dirs first); right pane shows the empty-state message. |
| Click a directory row | Row becomes selected; not expanded. |
| Click disclosure triangle on a directory | Expands; immediate children are scanned on first expansion only. |
| Click an `.md` file row | Loads it into the WebView. |
| Cmd+R / refresh button, file selected | Collapses and re-scans the parent directory. |
| Cmd+R / refresh button, directory selected | Collapses and re-scans that directory. |
| Cmd+R / refresh button, nothing selected | Re-scans the root. |
| Currently-viewed file deleted on disk, then refresh | File row disappears; WebView reverts to empty state; selection moves to the refreshed directory's row. |

## Risks and trade-offs

- **No pruning of empty subdirs.** Every subdirectory is shown regardless of
  whether it contains markdown. Accepted: pruning would require descending
  into each subdirectory to check, defeating the point of lazy loading.
- **No filesystem watching of directories.** Files added/removed/renamed in
  unexpanded subtrees won't appear until the user refreshes (or expands the
  containing directory for the first time). Accepted: refresh is a
  deliberate, low-friction action and the watcher's cost (one FD per
  directory) was unbounded.
- **Refresh discards descendant expansion state.** Re-expanding to a
  previous depth is manual. Accepted as a deliberate simplification per
  user direction.
