import Foundation

protocol MangaServicing {
    func loadBookshelf(page: Int) async -> [Manga]
    func searchBooks(keyword: String, page: Int) async -> [Manga]
}

final class MangaService: MangaServicing {
    private struct SearchDefaults {
        static let region = "all"
        static let status = "all"
        static let order = "sortpoint"
        static let language = "all"
        static let length = "all"
        static let bl = "BL"
        static let color = "0"
        static let hd = "0"
    }

    private let parser: BookshelfParsing
    private let endpoints: [URL] = [
        URL(string: "https://kzo.moe")!,
        URL(string: "https://koz.moe")!
    ]

    init(parser: BookshelfParsing = BookshelfParser()) {
        self.parser = parser
    }

    func loadBookshelf(page: Int) async -> [Manga] {
        let normalizedPage = max(1, page)
        let listResults = await fetchBooksByAbsolutePath(path: makeHomeListPath(page: normalizedPage))
        if Task.isCancelled { return [] }
        if !listResults.isEmpty {
            return listResults
        }

        // Fallback for first page only: if list route is temporarily unavailable, use homepage.
        if normalizedPage == 1 {
            let fallback = await fetchBooks(path: "/", queryItems: nil)
            return fallback
        }
        return []
    }

    func searchBooks(keyword: String, page: Int) async -> [Manga] {
        let normalizedPage = max(1, page)
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return await loadBookshelf(page: normalizedPage)
        }
        if let pagePath = makeListPath(keyword: trimmed, page: normalizedPage) {
            let pageResults = await fetchBooksByAbsolutePath(path: pagePath)
            if Task.isCancelled { return [] }
            if !pageResults.isEmpty {
                let filtered = filterByRelevance(results: pageResults, keyword: trimmed)
                return filtered.isEmpty ? pageResults : filtered
            }
        }

        // Fallback for first page only if /l/ route is temporarily unavailable.
        if normalizedPage == 1 {
            let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            let listResults = await fetchBooks(
                path: "/list.php",
                queryItems: [URLQueryItem(name: "s", value: trimmed)],
                refererPath: "/list.php?s=\(encoded)"
            )
            if Task.isCancelled { return [] }
            let filtered = filterByRelevance(results: listResults, keyword: trimmed)
            return filtered.isEmpty ? listResults : filtered
        }

        return []
    }

    private func fetchBooks(
        path: String,
        queryItems: [URLQueryItem]?,
        refererPath: String = "/"
    ) async -> [Manga] {
        var best: [Manga] = []

        for endpoint in endpoints {
            do {
                guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else { continue }
                components.path = path
                components.queryItems = queryItems
                guard let url = components.url else { continue }

                let html = try await NetworkClient.shared.fetchHTML(
                    url: url,
                    headers: [
                        "Referer": endpoint.absoluteString + refererPath
                    ]
                )
                let parsed = parser.parseBooks(from: html)
                if parsed.count > best.count {
                    best = parsed
                }
            } catch {
                if isCancellation(error) || Task.isCancelled {
                    return best
                }
                continue
            }
        }
        return best
    }

    private func filterByRelevance(results: [Manga], keyword: String) -> [Manga] {
        let key = normalize(keyword)
        guard !key.isEmpty else { return results }

        let exactTitle = results.filter { normalize($0.title).contains(key) }
        let authorMatches = results.filter { normalize($0.author).contains(key) && !exactTitle.contains($0) }
        let remaining = results.filter { !exactTitle.contains($0) && !authorMatches.contains($0) }
        return exactTitle + authorMatches + remaining
    }

    private func makeListPath(keyword: String, page: Int) -> String? {
        guard let encodedKeyword = keyword.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        let base = "/l/\(encodedKeyword),\(SearchDefaults.region),\(SearchDefaults.status),\(SearchDefaults.order),\(SearchDefaults.language),\(SearchDefaults.length),\(SearchDefaults.bl),\(SearchDefaults.color),\(SearchDefaults.hd)"
        return "\(base)/\(max(1, page)).htm"
    }

    private func makeHomeListPath(page: Int) -> String {
        "/l/--/\(max(1, page)).htm"
    }

    private func fetchBooksByAbsolutePath(path: String) async -> [Manga] {
        var best: [Manga] = []

        for endpoint in endpoints {
            do {
                guard let url = URL(string: endpoint.absoluteString + path) else { continue }
                let html = try await NetworkClient.shared.fetchHTML(
                    url: url,
                    headers: ["Referer": endpoint.absoluteString + "/"]
                )
                let parsed = parser.parseBooks(from: html)
                if parsed.count > best.count {
                    best = parsed
                }
            } catch {
                if isCancellation(error) || Task.isCancelled {
                    return best
                }
                continue
            }
        }
        return best
    }

    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    private func normalize(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .widthInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
            .replacingOccurrences(of: "[\\p{Punct}·•・]", with: "", options: .regularExpression)
    }
}
