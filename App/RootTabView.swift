import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack { BookshelfView() }
                .tabItem { Label("Home", systemImage: "house") }

            NavigationStack { DownloadsView() }
                .tabItem { Label("Downloads", systemImage: "arrow.down.circle") }

            NavigationStack { ProfileView() }
                .tabItem { Label("Profile", systemImage: "person") }
        }
        .tint(AppTheme.Colors.primary)
    }
}
