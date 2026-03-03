import Foundation

protocol DetailParsing {
    func parseDetail(from html: String, fallback: Manga) -> MangaDetail?
}

struct DetailParser: DetailParsing {
    func parseDetail(from html: String, fallback: Manga) -> MangaDetail? {
        guard html.contains("<html") else { return nil }

        let titleRaw =
            HTMLParsingSupport.firstMatch(in: html, pattern: "<h1[^>]*>(.*?)</h1>") ??
            HTMLParsingSupport.firstMatch(in: html, pattern: "<title[^>]*>(.*?)</title>")
        let title = HTMLParsingSupport.stripTags(titleRaw ?? fallback.title)
        guard !title.isEmpty else { return nil }

        let authorRaw =
            HTMLParsingSupport.firstMatch(in: html, pattern: "(?:Author|作者)\\s*[:：]?\\s*</?[^>]*>\\s*([^<\\n]+)") ??
            HTMLParsingSupport.firstMatch(in: html, pattern: "class=[\"'][^\"']*author[^\"']*[\"'][^>]*>(.*?)<")
        let author = HTMLParsingSupport.stripTags(authorRaw ?? fallback.author)

        let summaryRaw =
            HTMLParsingSupport.firstMatch(in: html, pattern: "(?:Synopsis|Description|简介)\\s*</?[^>]*>\\s*(.*?)</(?:p|div)>") ??
            HTMLParsingSupport.firstMatch(in: html, pattern: "<meta\\s+name=[\"']description[\"']\\s+content=[\"']([^\"']+)")
        let summary = HTMLParsingSupport.stripTags(summaryRaw ?? "")

        let ratingRaw = HTMLParsingSupport.firstMatch(in: html, pattern: "([0-5](?:\\.[0-9])?)\\s*(?:/\\s*5|rating|评分)")
        let rating = Double(ratingRaw ?? "") ?? 0

        let chapterMatches = HTMLParsingSupport.allMatches(
            in: html,
            pattern: "<a[^>]*href=[\"'][^\"']*(?:chapter|ch)[^\"']*[\"'][^>]*>(.*?)</a>"
        )
        let chapters = chapterMatches
            .prefix(20)
            .enumerated()
            .map { idx, item in
                MangaChapter(
                    id: idx + 1,
                    title: HTMLParsingSupport.stripTags(item),
                    date: "Unknown",
                    isFree: idx % 3 != 0
                )
            }

        let tags = [fallback.status.capitalized].filter { !$0.isEmpty }

        let manga = Manga(
            id: fallback.id,
            title: title,
            author: author.isEmpty ? fallback.author : author,
            coverName: fallback.coverName,
            status: fallback.status,
            path: fallback.path
        )

        return MangaDetail(
            manga: manga,
            summary: summary,
            tags: tags,
            rating: rating,
            reads: "--",
            chapters: chapters
        )
    }
}
