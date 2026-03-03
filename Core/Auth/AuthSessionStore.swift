import Foundation

@MainActor
final class AuthSessionStore: ObservableObject {
    @Published private(set) var isLoggedIn: Bool = false
    @Published private(set) var cookieHeader: String = ""
    @Published private(set) var isAuthenticating: Bool = false
    @Published private(set) var loginErrorMessage: String?

    private let cookieHeaderKey = "auth.cookie.header"
    private let supportedHosts = ["kzo.moe", "koz.moe"]
    private let requiredCookieNames: Set<String> = ["VLIBSID", "VOLSESS", "VOLSKEY"]

    init() {
        cookieHeader = UserDefaults.standard.string(forKey: cookieHeaderKey) ?? ""
        isLoggedIn = !cookieHeader.isEmpty
    }

    func login(email: String, password: String) async -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            loginErrorMessage = "请输入用户名和密码"
            return false
        }

        isAuthenticating = true
        loginErrorMessage = nil
        defer { isAuthenticating = false }

        do {
            let cookies = try await NetworkClient.shared.login(email: trimmedEmail, password: password)
            handleLoginSuccess(cookies: cookies)
            NetworkClient.shared.updateCookieHeader(cookieHeader)
            return isLoggedIn
        } catch NetworkError.invalidCredentials {
            loginErrorMessage = "用户名或密码错误"
            return false
        } catch {
            loginErrorMessage = "登录失败，请稍后重试"
            return false
        }
    }

    func handleLoginSuccess(cookies: [HTTPCookie]) {
        let targetCookies = cookies.filter { cookie in
            supportedHosts.contains(where: { cookie.domain.contains($0) }) &&
            requiredCookieNames.contains(cookie.name.uppercased())
        }

        let cookieMap = Dictionary(uniqueKeysWithValues: targetCookies.map { ($0.name.uppercased(), $0.value) })
        let raw = composeOrderedCookieHeader(cookieMap: cookieMap)

        guard !raw.isEmpty else { return }

        cookieHeader = raw
        isLoggedIn = true
        loginErrorMessage = nil
        UserDefaults.standard.set(raw, forKey: cookieHeaderKey)
    }

    func clearSession() {
        cookieHeader = ""
        isLoggedIn = false
        loginErrorMessage = nil
        UserDefaults.standard.removeObject(forKey: cookieHeaderKey)
        NetworkClient.shared.updateCookieHeader("")
    }

    func applyCookieHeader(_ raw: String) -> Bool {
        let parsed = parseCookieHeader(raw)
        let normalized = composeOrderedCookieHeader(cookieMap: parsed)
        guard !normalized.isEmpty else { return false }

        cookieHeader = normalized
        isLoggedIn = true
        loginErrorMessage = nil
        UserDefaults.standard.set(normalized, forKey: cookieHeaderKey)
        NetworkClient.shared.updateCookieHeader(normalized)
        return true
    }

    private func composeOrderedCookieHeader(cookieMap: [String: String]) -> String {
        let orderedNames = ["VLIBSID", "VOLSESS", "VOLSKEY"]
        return orderedNames
            .compactMap { name in
                guard let value = cookieMap[name] else { return nil }
                return "\(name)=\(value)"
            }
            .joined(separator: "; ")
    }

    private func parseCookieHeader(_ raw: String) -> [String: String] {
        let parts = raw.split(separator: ";")
        var map: [String: String] = [:]
        for part in parts {
            let pair = part.split(separator: "=", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            guard pair.count == 2 else { continue }
            let name = pair[0].uppercased()
            guard requiredCookieNames.contains(name) else { continue }
            map[name] = pair[1]
        }
        return map
    }
}
