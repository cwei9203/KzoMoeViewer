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
            return parser.parseDetail(from: html, fallback: manga) ?? emptyDetail
        } catch {
            return emptyDetail
        }
    }
}
