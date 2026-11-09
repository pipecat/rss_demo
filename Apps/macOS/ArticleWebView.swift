import SwiftUI
import WebKit

struct ArticleWebView: NSViewRepresentable {
    var html: String
    var articleID: String
    var openLink: (URL) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(openLink: openLink) }
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsBackForwardNavigationGestures = false
        return webView
    }
    func updateNSView(_ view: WKWebView, context: Context) {
        context.coordinator.openLink = openLink
        guard context.coordinator.lastHTML != html else { return }
        context.coordinator.lastHTML = html
        view.loadHTMLString(html, baseURL: nil)
    }
    final class Coordinator: NSObject, WKNavigationDelegate {
        var openLink: (URL) -> Void
        var lastHTML = ""
        init(openLink: @escaping (URL) -> Void) { self.openLink = openLink }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
            if url.scheme == "about", url.absoluteString.hasPrefix("about:blank") { decisionHandler(.allow); return }
            if navigationAction.navigationType == .linkActivated { openLink(url) }
            decisionHandler(.cancel)
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            NotificationCenter.default.post(name: .readerRendered, object: webView)
        }
    }
}

extension Notification.Name { static let readerRendered = Notification.Name("ReaderRendered") }
