import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authStore: AuthSessionStore

    private let loginURL = URL(string: "https://kzo.moe/m/login.php")!

    var body: some View {
        NavigationStack {
            LoginWebView(
                loginURL: loginURL,
                successHosts: ["kzo.moe", "www.kzo.moe", "koz.moe", "www.koz.moe"],
                loginPathHints: ["login", "signin", "signup"]
            ) { cookies in
                authStore.handleLoginSuccess(cookies: cookies)
                NetworkClient.shared.updateCookieHeader(authStore.cookieHeader)
                dismiss()
            }
            .navigationTitle("登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}
