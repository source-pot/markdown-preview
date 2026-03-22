import Foundation
import Combine

class AppState: ObservableObject {
    @Published var currentFile: URL?
    @Published var markdownContent: String = ""
    @Published var refreshTrigger: UUID = UUID()
    @Published var rootDirectory: URL?
    @Published var directoryTree: DirectoryNode?

    private var fileWatcher: FileWatcher?
    private var directoryWatcher: DirectoryWatcher?

    func openFile(_ url: URL) {
        stopWatchingFile()
        currentFile = url
        loadContent()
        startWatchingFile()
    }

    func openDirectory(_ url: URL) {
        rootDirectory = url
        scanDirectory()
        if let first = directoryTree?.firstMarkdownFile() {
            openFile(first)
        }
        startWatchingDirectory()
    }

    func scanDirectory() {
        guard let root = rootDirectory else { return }
        directoryTree = DirectoryNode.scan(directory: root)
    }

    func closeFile() {
        stopWatchingFile()
        stopWatchingDirectory()
        currentFile = nil
        markdownContent = ""
        rootDirectory = nil
        directoryTree = nil
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

    private func startWatchingDirectory() {
        guard let root = rootDirectory else { return }

        directoryWatcher = DirectoryWatcher(rootURL: root) { [weak self] in
            self?.scanDirectory()
            self?.startWatchingDirectory()
        }
        directoryWatcher?.start()
    }

    private func stopWatchingDirectory() {
        directoryWatcher?.stop()
        directoryWatcher = nil
    }
}
