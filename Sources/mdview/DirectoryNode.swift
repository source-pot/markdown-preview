import Foundation

struct DirectoryNode: Identifiable, Hashable {
    let id: URL
    let url: URL
    let name: String
    let isDirectory: Bool
    var children: [DirectoryNode]?

    static func scan(directory: URL) -> DirectoryNode {
        let children = scanChildren(of: directory)
        return DirectoryNode(
            id: directory,
            url: directory,
            name: directory.lastPathComponent,
            isDirectory: true,
            children: children
        )
    }

    private static func scanChildren(of directory: URL) -> [DirectoryNode] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var dirs: [DirectoryNode] = []
        var files: [DirectoryNode] = []

        for url in contents {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

            if isDir {
                let children = scanChildren(of: url)
                guard !children.isEmpty else { continue }
                dirs.append(DirectoryNode(
                    id: url,
                    url: url,
                    name: url.lastPathComponent,
                    isDirectory: true,
                    children: children
                ))
            } else if url.pathExtension.lowercased() == "md" {
                files.append(DirectoryNode(
                    id: url,
                    url: url,
                    name: url.lastPathComponent,
                    isDirectory: false,
                    children: nil
                ))
            }
        }

        dirs.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        files.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return dirs + files
    }

    func firstMarkdownFile() -> URL? {
        if !isDirectory { return url }
        for child in children ?? [] {
            if let found = child.firstMarkdownFile() { return found }
        }
        return nil
    }
}
