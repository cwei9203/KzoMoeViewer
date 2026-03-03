import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authStore: AuthSessionStore
    @State private var showLoginSheet = false
    @State private var verificationMessage = ""

    private let testCookie =
        "VLIBSID=c3htullb9u0ao57n4fo2gums8t; VOLSESS=1772363705; VOLSKEY=6ac21af7757f9ced61807d46937b8e32177236374610522035"

    var body: some View {
        VStack(spacing: AppTheme.Spacing.l) {
            CardContainer {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Profile")
                        .font(.title3.weight(.bold))
                    Text("Use this page for account, cache and settings.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }

            CardContainer {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Account")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    if authStore.isLoggedIn {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("当前状态：已登录")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.Colors.success)
                                Spacer()
                                Button("退出登录", role: .destructive) {
                                    authStore.clearSession()
                                    verificationMessage = ""
                                }
                                .buttonStyle(.bordered)
                            }

                            if !verificationMessage.isEmpty {
                                Text(verificationMessage)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("当前状态：未登录")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Colors.textSecondary)

                            Button {
                                showLoginSheet = true
                            } label: {
                                Text("H5 登录")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.Colors.primary)

                            Button {
                                Task {
                                    let ok = authStore.applyCookieHeader(testCookie)
                                    guard ok else {
                                        verificationMessage = "测试 Cookie 格式无效"
                                        return
                                    }
                                    verificationMessage = await verifySearchRequest()
                                }
                            } label: {
                                Text("注入测试 Cookie 并验证搜索")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            if !verificationMessage.isEmpty {
                                Text(verificationMessage)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            }
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(AppTheme.Spacing.l)
        .background(AppTheme.Colors.background)
        .navigationTitle("Profile")
        .sheet(isPresented: $showLoginSheet) {
            LoginView()
                .environmentObject(authStore)
        }
    }

    private func verifySearchRequest() async -> String {
        guard let url = URL(string: "https://kzo.moe/list.php?s=%E4%B8%80%E4%BA%BA%E4%B9%8B%E4%B8%8B") else {
            return "验证失败：URL 无效"
        }
        do {
            let html = try await NetworkClient.shared.fetchHTML(
                url: url,
                headers: ["Referer": "https://kzo.moe/login.php"]
            )
            let hasResultScript = html.contains("disp_divinfo(")
            return "验证完成：htmlLength=\(html.count), hasDispDivInfo=\(hasResultScript)"
        } catch {
            return "验证失败：\(error.localizedDescription)"
        }
    }
}
