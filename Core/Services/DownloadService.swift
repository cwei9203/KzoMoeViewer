import Foundation

/// 下载格式类型
enum DownloadFormat: Int, CaseIterable {
    case mobi = 1
    case epub = 2
    
    var title: String {
        switch self {
        case .mobi: return "Kindle (.mobi)"
        case .epub: return "EPUB (iPad/小米)"
        }
    }
    
    var fileExtension: String {
        switch self {
        case .mobi: return "mobi"
        case .epub: return "epub"
        }
    }
}

/// 下载线类型
enum DownloadLine: Int {
    case line1 = 0
    case line2 = 1
}

/// 漫画下载任务
struct MangaDownloadTask: Identifiable, Hashable {
    let id: UUID
    let bookID: Int
    let volID: Int
    let title: String
    let format: DownloadFormat
    var sizeMB: Double
    var downloadedMB: Double
    var state: DownloadState
    let date: String
    
    var progress: Double {
        guard sizeMB > 0 else { return 0 }
        return min(max(downloadedMB / sizeMB, 0), 1)
    }
    
    init(
        id: UUID = UUID(),
        bookID: Int,
        volID: Int,
        title: String,
        format: DownloadFormat,
        sizeMB: Double,
        downloadedMB: Double = 0,
        state: DownloadState = .waiting,
        date: String
    ) {
        self.id = id
        self.bookID = bookID
        self.volID = volID
        self.title = title
        self.format = format
        self.sizeMB = sizeMB
        self.downloadedMB = downloadedMB
        self.state = state
        self.date = date
    }
}

/// 下载服务协议
protocol DownloadServicing {
    /// 获取下载URL
    func getDownloadURL(bookID: Int, volID: Int, format: DownloadFormat, line: DownloadLine) async throws -> URL
    
    /// 下载文件
    func downloadFile(from url: URL, to destination: URL, progress: @escaping (Double) -> Void) async throws
    
    /// 下载文件（带bookID）
    func downloadFile(from url: URL, to destination: URL, progress: @escaping (Double) -> Void, bookID: Int?) async throws
}

/// 下载服务实现
final class DownloadService: DownloadServicing {
    static let shared = DownloadService()
    
    private let baseURL = URL(string: "https://kzo.moe")!
    private var session: URLSession
    
    // 存储登录后的 Cookie
    var authCookie: String? {
        get { UserDefaults.standard.string(forKey: "kzo_auth_cookie") }
        set { UserDefaults.standard.set(newValue, forKey: "kzo_auth_cookie") }
    }
    
    // 从 NetworkClient 获取当前Cookie
    var currentCookie: String {
        NetworkClient.shared.currentCookie
    }
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }
    
    /// 构建下载请求头
    private func buildHeaders(for bookID: Int) -> [String: String] {
        var headers: [String: String] = [
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7",
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36",
            "Referer": "https://kzo.moe/c/\(bookID).htm",
            "Upgrade-Insecure-Requests": "1"
        ]
        
        // 添加 Cookie
        if !currentCookie.isEmpty {
            headers["Cookie"] = currentCookie
        }
        
        return headers
    }
    
    /// 获取下载URL - 根据网页请求流程
    /// - Parameters:
    ///   - bookID: 漫画ID
    ///   - volID: 卷ID
    ///   - format: 下载格式 (mobi=1/epub=2)
    ///   - line: 下载线路 (0=线路1, 1=线路2)
    /// - Returns: 实际的下载URL
    func getDownloadURL(bookID: Int, volID: Int, format: DownloadFormat, line: DownloadLine) async throws -> URL {
        // 构建下载请求URL: /dl/{bookID}/{volID}/{line}/{format}/0/
        let downloadPageURL = URL(string: "/dl/\(bookID)/\(volID)/\(line.rawValue)/\(format.rawValue)/0/", 
                                 relativeTo: baseURL)!
        
        var request = URLRequest(url: downloadPageURL)
        request.httpMethod = "GET"
        
        // 设置请求头
        let headers = buildHeaders(for: bookID)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // 发送请求获取重定向URL
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DownloadError.invalidResponse
        }
        
        // 检查是否有重定向
        if let location = httpResponse.value(forHTTPHeaderField: "Location"),
           let redirectURL = URL(string: location) {
            return redirectURL
        }
        
        // 如果没有重定向，使用页面URL（可能会通过JS重定向）
        return downloadPageURL
    }
    
    /// 下载文件 - 支持302重定向
    /// - Parameters:
    ///   - url: 下载URL
    ///   - destination: 目标文件路径
    ///   - progress: 进度回调 (0.0 - 1.0)
    func downloadFile(from url: URL, to destination: URL, progress: @escaping (Double) -> Void) async throws {
        try await downloadFile(from: url, to: destination, progress: progress, bookID: nil)
    }
    
    /// 下载文件 - 支持302重定向（带bookID版本）
    /// - Parameters:
    ///   - url: 下载URL
    ///   - destination: 目标文件路径
    ///   - progress: 进度回调 (0.0 - 1.0)
    ///   - bookID: 漫画ID（用于设置Referer）
    func downloadFile(from url: URL, to destination: URL, progress: @escaping (Double) -> Void, bookID: Int?) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // 设置请求头
        var headers: [String: String] = [
            "Accept": "*/*",
            "Accept-Language": "zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7",
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36"
        ]
        
        // 添加Cookie
        if !currentCookie.isEmpty {
            headers["Cookie"] = currentCookie
        }
        
        // 设置Referer
        if bookID != nil {
            headers["Referer"] = "https://kzo.moe/"
        }
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // 使用默认session处理重定向下载
        let defaultSession = URLSession.shared
        let (tempURL, response) = try await defaultSession.download(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw DownloadError.downloadFailed
        }
        
        let fileManager = FileManager.default
        
        // 确保目标目录存在
        let directory = destination.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        
        // 如果目标文件已存在，删除它
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        
        // 移动下载的文件到目标位置
        try fileManager.moveItem(at: tempURL, to: destination)
        
        progress(1.0)
    }
    
    /// 获取Documents目录下的下载保存路径
    func downloadsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("Downloads", isDirectory: true)
    }
    
    /// 生成下载文件名
    func generateFilename(for manga: Manga, chapter: MangaChapter, format: DownloadFormat) -> String {
        let sanitizedTitle = manga.title.replacingOccurrences(of: "/", with: "-")
        let sanitizedChapter = chapter.title.replacingOccurrences(of: "/", with: "-")
        return "\(sanitizedTitle) - \(sanitizedChapter).\(format.fileExtension)"
    }
}

/// 下载错误
enum DownloadError: LocalizedError {
    case invalidResponse
    case downloadFailed
    case saveFailed
    case notLoggedIn
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "获取下载链接失败"
        case .downloadFailed:
            return "下载失败"
        case .saveFailed:
            return "保存文件失败"
        case .notLoggedIn:
            return "请先登录"
        }
    }
}
