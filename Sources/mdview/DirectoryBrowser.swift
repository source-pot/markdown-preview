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
                if appState.selectedNodeURL == nil {
                    appState.selectedNodeURL = appState.currentFile
                }
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
