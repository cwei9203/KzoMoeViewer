import Foundation

protocol MangaServicing {
    func loadBookshelf() async -> [Manga]
    func searchBooks(keyword: String) async -> [Manga]
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

    func loadBookshelf() async -> [Manga] {
        await fetchBooks(path: "/", queryItems: nil)
    }

    func searchBooks(keyword: String) async -> [Manga] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return await loadBookshelf()
        }
        print("[MangaService] search keyword=\(trimmed)")
        if let mainPath = makeListPath(keyword: trimmed, page: nil) {
            let primaryResults = await fetchBooksByAbsolutePath(path: mainPath)
            if !primaryResults.isEmpty {
                let filtered = filterByRelevance(results: primaryResults, keyword: trimmed)
                return filtered.isEmpty ? primaryResults : filtered
            }
        }

        // Fallback: pull paged /l/... results and merge.
        let pagedResults = await fetchPagedListResults(keyword: trimmed, maxPages: 8)
        var merged = mergeUnique(pagedResults)

        // Final fallback if /l/ route is temporarily unavailable.
        if merged.isEmpty {
            let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            let listResults = await fetchBooks(
                path: "/list.php",
                queryItems: [URLQueryItem(name: "s", value: trimmed)],
                refererPath: "/list.php?s=\(encoded)"
            )
            merged = mergeUnique(listResults)
        }

        let filtered = filterByRelevance(results: merged, keyword: trimmed)
        return filtered.isEmpty ? merged : filtered
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
                print("[MangaService] url=\(url.absoluteString)")
                print("[MangaService] htmlLength=\(html.count) hasDispDivInfo=\(html.contains("disp_divinfo(")) parsed=\(parsed.count)")
                if parsed.count > best.count {
                    best = parsed
                }
            } catch {
                print("[MangaService] request failed endpoint=\(endpoint.absoluteString) path=\(path) error=\(error)")
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

    private func fetchPagedListResults(keyword: String, maxPages: Int) async -> [Manga] {
        var merged: [Manga] = []
        var emptyCount = 0

        for page in 1...maxPages {
            guard let pagePath = makeListPath(keyword: keyword, page: page) else { continue }
            let pageResults = await fetchBooksByAbsolutePath(path: pagePath)
            print("[MangaService] pagePath=\(pagePath) parsed=\(pageResults.count)")

            if pageResults.isEmpty {
                emptyCount += 1
                if emptyCount >= 2 {
                    break
                }
                continue
            }

            emptyCount = 0
            merged = mergeUnique(merged + pageResults)
        }

        return merged
    }

    private func makeListPath(keyword: String, page: Int?) -> String? {
        guard let encodedKeyword = keyword.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        let base = "/l/\(encodedKeyword),\(SearchDefaults.region),\(SearchDefaults.status),\(SearchDefaults.order),\(SearchDefaults.language),\(SearchDefaults.length),\(SearchDefaults.bl),\(SearchDefaults.color),\(SearchDefaults.hd)"
        if let page {
            return "\(base)/\(page).htm"
        }
        return "\(base)/"
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
                print("[MangaService] absUrl=\(url.absoluteString) htmlLength=\(html.count) parsed=\(parsed.count)")
                if parsed.count > best.count {
                    best = parsed
                }
            } catch {
                print("[MangaService] abs request failed endpoint=\(endpoint.absoluteString) path=\(path) error=\(error)")
                continue
            }
        }
        return best
    }

    private func mergeUnique(_ input: [Manga]) -> [Manga] {
        var seen = Set<String>()
        var output: [Manga] = []
        output.reserveCapacity(input.count)

        for manga in input {
            let key = "\(manga.path ?? "")|\(normalize(manga.title))|\(normalize(manga.author))"
            if seen.insert(key).inserted {
                output.append(manga)
            }
        }
        return output
    }

    private func normalize(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .widthInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
            .replacingOccurrences(of: "[\\p{Punct}·•・]", with: "", options: .regularExpression)
    }
}
