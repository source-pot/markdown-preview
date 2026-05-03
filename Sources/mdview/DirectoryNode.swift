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
