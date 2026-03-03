import SwiftUI
import WebKit

struct LoginWebView: UIViewRepresentable {
    let loginURL: URL
    let successHosts: [String]
    let loginPathHints: [String]
    let onCookiesExtracted: ([HTTPCookie]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: loginURL))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let parent: LoginWebView
        private var hasCompleted = false
        private let requiredCookieNames: Set<String> = ["VLIBSID", "VOLSESS", "VOLSKEY"]

        init(parent: LoginWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !hasCompleted else { return }
            guard let url = webView.url else { return }

            let hostMatched = parent.successHosts.contains(where: { url.host?.contains($0) == true })
            guard hostMatched else { return }

            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                let hasAuthCookies = self.containsRequiredAuthCookies(cookies)
                let path = url.path.lowercased()
                let isLoginPath = self.parent.loginPathHints.contains(where: { path.contains($0.lowercased()) })
                guard hasAuthCookies || !isLoginPath else { return }

                self.hasCompleted = true
                DispatchQueue.main.async {
                    self.parent.onCookiesExtracted(cookies)
                }
            }
        }

        private func containsRequiredAuthCookies(_ cookies: [HTTPCookie]) -> Bool {
            let names = Set(cookies.map { $0.name.uppercased() })
            return requiredCookieNames.isSubset(of: names)
        }
    }
}
