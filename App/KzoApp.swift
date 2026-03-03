import SwiftUI

@main
struct KzoApp: App {
    @StateObject private var authStore = AuthSessionStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .background(AppTheme.Colors.background.ignoresSafeArea())
                .environmentObject(authStore)
                .task {
                    NetworkClient.shared.updateCookieHeader(authStore.cookieHeader)
                }
        }
    }
}
