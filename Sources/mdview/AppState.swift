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
