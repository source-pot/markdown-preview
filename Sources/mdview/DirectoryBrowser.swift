import SwiftUI

struct DirectoryBrowser: View {
    @EnvironmentObject var appState: AppState
    let rootNode: DirectoryNode
    @State private var selection: URL?

    var body: some View {
        List(selection: $selection) {
            Section(header: Text(rootNode.name).font(.headline)) {
                OutlineGroup(rootNode.children ?? [], children: \.children) { node in
                    Label(node.name, systemImage: node.isDirectory ? "folder" : "doc.text")
                        .tag(node.url)
                }
            }
        }
        .listStyle(.sidebar)
        .onChange(of: selection) { newValue in
            guard let url = newValue, !url.hasDirectoryPath else { return }
            appState.openFile(url)
        }
        .onAppear {
            selection = appState.currentFile
        }
    }
}
