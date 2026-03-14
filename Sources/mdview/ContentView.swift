import SwiftUI
import WebKit

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        WebView(
            markdown: appState.markdownContent,
            theme: ThemeManager.shared.currentTheme,
            refreshTrigger: appState.refreshTrigger
        )
        .frame(minWidth: 400, minHeight: 300)
    }
}

struct WebView: NSViewRepresentable {
    let markdown: String
    let theme: Theme
    let refreshTrigger: UUID

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let html = MarkdownRenderer.render(markdown, theme: theme)
        webView.loadHTMLString(html, baseURL: nil)
    }
}
