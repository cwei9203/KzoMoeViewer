import Foundation
import CoreFoundation

enum NetworkError: Error {
    case invalidResponse
    case badStatus(Int)
    case invalidCredentials
}

final class NetworkClient {
    static let shared = NetworkClient()

    private let session: URLSession
    private var cookieHeader: String = ""
    private let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36"

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
    }

    func updateCookieHeader(_ value: String) {
        cookieHeader = value
    }

    func login(email: String, password: String) async throws -> [HTTPCookie] {
        let baseURL = URL(string: "https://kzo.moe")!
        let loginURL = URL(string: "https://kzo.moe/login.php")!
        let loginDoURL = URL(string: "https://kzo.moe/login_do.php")!

        let cookieStorage = HTTPCookieStorage.shared
        if let existing = cookieStorage.cookies(for: baseURL) {
            for cookie in existing {
                cookieStorage.deleteCookie(cookie)
            }
        }

        var warmup = URLRequest(url: loginURL)
        applyCommonHeaders(to: &warmup, includeManualCookie: false)
        warmup.setValue(loginURL.absoluteString, forHTTPHeaderField: "Referer")
        _ = try await session.data(for: warmup)

        var request = URLRequest(url: loginDoURL)
        request.httpMethod = "POST"
        applyCommonHeaders(to: &request, includeManualCookie: false)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("https://kzo.moe", forHTTPHeaderField: "Origin")
        request.setValue(loginURL.absoluteString, forHTTPHeaderField: "Referer")

        let body = "email=\(urlEncode(email))&passwd=\(urlEncode(password))&keepalive=on"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.badStatus(httpResponse.statusCode)
        }

        let cookies = cookieStorage.cookies(for: baseURL) ?? []
        let required = Set(["VLIBSID", "VOLSESS", "VOLSKEY"])
        let names = Set(cookies.map { $0.name.uppercased() })
        guard required.isSubset(of: names) else {
            let html = decodeHTML(from: data).lowercased()
            if html.contains("password") || html.contains("passwd") || html.contains("login") {
                throw NetworkError.invalidCredentials
            }
            throw NetworkError.invalidCredentials
        }

        return cookies
    }

    func fetchHTML(url: URL, headers: [String: String] = [:]) async throws -> String {
        var request = URLRequest(url: url)
        applyCommonHeaders(to: &request, includeManualCookie: true)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.badStatus(httpResponse.statusCode)
        }

        return decodeHTML(from: data)
    }

    private func applyCommonHeaders(to request: inout URLRequest, includeManualCookie: Bool) {
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        if includeManualCookie, !cookieHeader.isEmpty {
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }
    }

    private func urlEncode(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
    }

    private func decodeHTML(from data: Data) -> String {
        let encodings: [String.Encoding] = [
            .utf8,
            .unicode,
            .utf16LittleEndian,
            .utf16BigEndian,
            .isoLatin1,
            .ascii
        ]

        for encoding in encodings {
            if let text = String(data: data, encoding: encoding), !text.isEmpty {
                return text
            }
        }

        let big5Encoding = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5.rawValue))
        if let text = NSString(data: data, encoding: big5Encoding) as String?, !text.isEmpty {
            return text
        }

        let gb18030 = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
        if let text = NSString(data: data, encoding: gb18030) as String?, !text.isEmpty {
            return text
        }

        return String(decoding: data, as: UTF8.self)
    }
}
