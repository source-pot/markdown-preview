import Foundation
import Combine

class AppState: ObservableObject {
    @Published var currentFile: URL?
    @Published var markdownContent: String = ""
    @Published var refreshTrigger: UUID = UUID()

    private var fileWatcher: FileWatcher?

    func openFile(_ url: URL) {
        currentFile = url
        loadContent()
        startWatching()
    }

    func closeFile() {
        stopWatching()
        currentFile = nil
        markdownContent = ""
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

    private func startWatching() {
        guard let url = currentFile else { return }

        fileWatcher = FileWatcher(url: url) { [weak self] in
            DispatchQueue.main.async {
                self?.loadContent()
            }
        }
        fileWatcher?.start()
    }

    private func stopWatching() {
        fileWatcher?.stop()
        fileWatcher = nil
    }
}
