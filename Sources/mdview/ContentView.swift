import SwiftUI
@preconcurrency import WebKit

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

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let html = MarkdownRenderer.render(markdown, theme: theme)
        webView.loadHTMLString(html, baseURL: nil)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            // Allow internal navigation (loading HTML content, anchor links)
            if navigationAction.navigationType == .other {
                decisionHandler(.allow)
                return
            }

            // Open external http/https links in system browser
            if url.scheme == "http" || url.scheme == "https" {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }
    }
}
