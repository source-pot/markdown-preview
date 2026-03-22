import Foundation

class DirectoryWatcher {
    private let rootURL: URL
    private let callback: () -> Void
    private var sources: [(source: DispatchSourceFileSystemObject, fd: Int32)] = []
    private var debounceWorkItem: DispatchWorkItem?

    init(rootURL: URL, callback: @escaping () -> Void) {
        self.rootURL = rootURL
        self.callback = callback
    }

    func start() {
        stop()
        watchRecursively(rootURL)
    }

    func stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        for entry in sources {
            entry.source.cancel()
        }
        sources.removeAll()
    }

    private func watchRecursively(_ directory: URL) {
        watchDirectory(directory)

        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for url in contents {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir {
                watchRecursively(url)
            }
        }
    }

    private func watchDirectory(_ directory: URL) {
        let fd = open(directory.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            self?.debouncedCallback()
        }

        source.setCancelHandler {
            close(fd)
        }

        sources.append((source: source, fd: fd))
        source.resume()
    }

    private func debouncedCallback() {
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.callback()
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    deinit {
        stop()
    }
}
