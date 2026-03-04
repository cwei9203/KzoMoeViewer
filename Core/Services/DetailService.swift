import Foundation

protocol DetailServicing {
    func loadDetail(for manga: Manga) async -> MangaDetail
}

final class DetailService: DetailServicing {
    private let parser: DetailParsing
    private let baseURL = URL(string: "https://kzo.moe")!

    init(parser: DetailParsing = DetailParser()) {
        self.parser = parser
    }

    func loadDetail(for manga: Manga) async -> MangaDetail {
        let emptyDetail = MangaDetail(
            manga: manga,
            summary: "",
            tags: [manga.status.capitalized].filter { !$0.isEmpty },
            rating: 0,
            reads: "--",
            chapters: []
        )
        guard let path = manga.path else { return emptyDetail }

        let url: URL
        if let absolute = URL(string: path), absolute.scheme != nil {
            url = absolute
        } else {
            url = URL(string: path, relativeTo: baseURL) ?? baseURL
        }

        do {
            let html = try await NetworkClient.shared.fetchHTML(url: url)
            guard var detail = parser.parseDetail(from: html, fallback: manga) else {
                return emptyDetail
            }

            if let hash = extractBookDataHash(from: html),
               let bookDataURL = URL(string: "/book_data.php?h=\(hash)", relativeTo: baseURL) {
                let bookDataHTML = try await NetworkClient.shared.fetchHTML(
                    url: bookDataURL,
                    headers: ["Referer": url.absoluteString]
                )
                let chapters = parser.parseChapters(from: bookDataHTML)
                if !chapters.isEmpty {
                    detail = MangaDetail(
                        manga: detail.manga,
                        summary: detail.summary,
                        tags: detail.tags,
                        rating: detail.rating,
                        reads: detail.reads,
                        chapters: chapters,
                        subtitle: detail.subtitle,
                        region: detail.region,
                        language: detail.language,
                        lastPublish: detail.lastPublish,
                        updateDate: detail.updateDate,
                        version: detail.version,
                        scanner: detail.scanner,
                        maintainer: detail.maintainer,
                        subscribed: detail.subscribed,
                        favorited: detail.favorited,
                        readCount: detail.readCount,
                        heat: detail.heat,
                        isColor: detail.isColor
                    )
                }
            }

            return detail
        } catch {
            return emptyDetail
        }
    }

    private func extractBookDataHash(from html: String) -> String? {
        HTMLParsingSupport.firstMatch(in: html, pattern: #"/book_data\.php\?h=([a-zA-Z0-9]+)"#)
    }
}
