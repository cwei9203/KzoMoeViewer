import Foundation

protocol DetailParsing {
    func parseDetail(from html: String, fallback: Manga) -> MangaDetail?
    func parseChapters(from bookDataHTML: String) -> [MangaChapter]
}

struct DetailParser: DetailParsing {
    func parseDetail(from html: String, fallback: Manga) -> MangaDetail? {
        guard html.contains("<html") else { return nil }

        let titleRaw =
            HTMLParsingSupport.firstMatch(in: html, pattern: "<font\\s+class=[\"']text_bglight_big[\"'][^>]*>(.*?)</font>") ??
            HTMLParsingSupport.firstMatch(in: html, pattern: "<title>(.*?)</title>")
        let title = cleanTitle(raw: titleRaw ?? fallback.title)
        guard !title.isEmpty else { return nil }

        let authorRaw =
            HTMLParsingSupport.firstMatch(in: html, pattern: "作者：\\s*(?:<font[^>]*>)?\\s*<a[^>]*>(.*?)</a>") ??
            HTMLParsingSupport.firstMatch(in: html, pattern: "(?:Author|作者)\\s*[:：]?\\s*([^<\\n]+)")
        let author = HTMLParsingSupport.stripTags(authorRaw ?? fallback.author).ifEmpty(fallback.author)

        let summaryRaw =
            HTMLParsingSupport.firstMatch(in: html, pattern: "div_desc_content\"\\)\\.innerHTML\\s*=\\s*\"(.*?)\";") ??
            HTMLParsingSupport.firstMatch(in: html, pattern: "<meta\\s+name=[\"']description[\"']\\s+content=[\"']([^\"']+)")
        let summary = normalizeSummary(raw: summaryRaw ?? "")

        let ratingRaw =
            HTMLParsingSupport.firstMatch(in: html, pattern: "<font\\s+style=[\"'][^\"']*font-size:30px[^\"']*[\"']>\\s*([0-9]+(?:\\.[0-9])?)\\s*</font>") ??
            HTMLParsingSupport.firstMatch(in: html, pattern: "([0-9]+(?:\\.[0-9])?)\\s*分")
        let rating = Double(ratingRaw ?? "") ?? 0

        let subtitle = HTMLParsingSupport.stripTags(
            HTMLParsingSupport.firstMatch(in: html, pattern: "<font\\s+class=[\"']text_bglight[\"']>\\s*(\\([^<]*\\))\\s*</font>") ?? ""
        )

        let coverURL =
            HTMLParsingSupport.firstMatch(in: html, pattern: "<meta\\s+name=[\"']og:image[\"']\\s+content=[\"']([^\"']+)") ??
            HTMLParsingSupport.firstMatch(in: html, pattern: "<img\\s+class=[\"']img_book[\"'][^>]*src=[\"']([^\"']+)")

        let status = extractDirect("狀態", in: html).ifEmpty(fallback.status)
        let region = extractDirect("地區", in: html).ifEmpty("--")
        let language = extractDirect("語言", in: html).ifEmpty("--")
        let lastPublish = extractDirect("最後出版", in: html).ifEmpty("--")
        let update = extractDirect("更新", in: html).ifEmpty("--")

        let version = extractDirect("版本", in: html).ifEmpty("--")
        let scanner = extractDirect("掃者", in: html).ifEmpty("--")
        let maintainer = extractDirect("維護者", in: html).ifEmpty("--")

        let subscribed = extractDirect("訂閱", in: html).ifEmpty("--")
        let favorited = extractDirect("收藏", in: html).ifEmpty("--")
        let readCount = extractDirect("讀過", in: html).ifEmpty("--")
        let heat = extractDirect("熱度", in: html).ifEmpty("--")
        let isColor = (HTMLParsingSupport.firstMatch(in: html, pattern: #"var\s+is_color\s*=\s*"([0-9]+)""#).flatMap(Int.init) ?? 0) > 0
        let reads = heat != "--" ? heat : (readCount != "--" ? readCount : "--")

        let tags = parseTags(from: html, fallback: fallback.status)

        let manga = Manga(
            id: fallback.id,
            title: title,
            author: author,
            coverName: fallback.coverName,
            coverURL: coverURL ?? fallback.coverURL,
            ratingText: fallback.ratingText,
            status: status,
            updateInfo: update.ifEmpty(fallback.updateInfo ?? ""),
            path: fallback.path
        )

        return MangaDetail(
            manga: manga,
            summary: summary,
            tags: tags,
            rating: rating,
            reads: reads,
            chapters: [],
            subtitle: subtitle,
            region: region,
            language: language,
            lastPublish: lastPublish,
            updateDate: update.ifEmpty("--"),
            version: version,
            scanner: scanner,
            maintainer: maintainer,
            subscribed: subscribed,
            favorited: favorited,
            readCount: readCount,
            heat: heat,
            isColor: isColor
        )
    }

    private func cleanTitle(raw: String) -> String {
        let text = HTMLParsingSupport.stripTags(raw)
        if let range = text.range(of: " : ") {
            return String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    private func normalizeSummary(raw: String) -> String {
        HTMLParsingSupport.stripTags(
            raw
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\n", with: "\n")
                .replacingOccurrences(of: "\\/", with: "/")
                .replacingOccurrences(of: "<br />", with: "\n")
                .replacingOccurrences(of: "<br>", with: "\n")
        )
    }

    private func parseTags(from html: String, fallback: String) -> [String] {
        guard let block = HTMLParsingSupport.firstMatch(in: html, pattern: "分類：\\s*([\\s\\S]*?)id=[\"']bt_voteya[\"']") else {
            return [fallback].filter { !$0.isEmpty }
        }
        let line = HTMLParsingSupport.decodeEntities(block.replacingOccurrences(of: "\n", with: " "))
        guard let regex = try? NSRegularExpression(
            pattern: #"(?:>|^)\s*([^<\s][^<]*?)\s*<font[^>]*class=['"]filesize['"][^>]*>\s*\((\d+)\)"#,
            options: [.caseInsensitive]
        ) else {
            return [fallback].filter { !$0.isEmpty }
        }
        let range = NSRange(line.startIndex..., in: line)
        let tags = regex.matches(in: line, options: [], range: range).compactMap { match -> String? in
            guard
                match.numberOfRanges > 2,
                let nameRange = Range(match.range(at: 1), in: line),
                let countRange = Range(match.range(at: 2), in: line)
            else {
                return nil
            }
            let name = HTMLParsingSupport.stripTags(String(line[nameRange]))
            let count = String(line[countRange])
            guard !name.isEmpty else { return nil }
            return "\(name) (\(count))"
        }
        if tags.isEmpty {
            return [fallback].filter { !$0.isEmpty }
        }
        return tags
    }

    private func extractDirect(_ key: String, in html: String) -> String {
        let source = HTMLParsingSupport.decodeEntities(html)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "　", with: " ")
            .replacingOccurrences(of: "\n", with: " ")

        let pattern = "\(NSRegularExpression.escapedPattern(for: key))：\\s*(?:<a[^>]*>)?\\s*([^<\\s　]*)"
        let value = HTMLParsingSupport.firstMatch(in: source, pattern: pattern, options: [.caseInsensitive]) ?? ""
        let cleaned = HTMLParsingSupport.stripTags(value).trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.contains("：") {
            return ""
        }
        return cleaned
    }

    func parseChapters(from bookDataHTML: String) -> [MangaChapter] {
        let rawRows = HTMLParsingSupport.allMatches(
            in: bookDataHTML,
            pattern: #"volinfo=([^\r\n<]+)"#
        )

        var chapters: [MangaChapter] = []
        chapters.reserveCapacity(rawRows.count)

        for raw in rawRows {
            let fields = raw.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 6 else { continue }

            let volID = Int(fields[0]) ?? (chapters.count + 1)
            let type = fields[3].trimmingCharacters(in: .whitespacesAndNewlines)
            let name = HTMLParsingSupport.decodeEntities(fields[5]).trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty { continue }

            let date = fields.count > 13 ? fields[13].trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
            
            // 解析下载相关字段
            // fields[6] = pageCount, fields[8] = zipSize, fields[9] = mobiSize, fields[10] = pushSize, fields[11] = epubSize
            let pageCount = fields.count > 6 ? (Int(fields[6]) ?? 0) : 0
            let mobiSize = fields.count > 9 ? (Double(fields[9]) ?? 0) : 0
            let epubSize = fields.count > 11 ? (Double(fields[11]) ?? 0) : 0
            let sizeMB = max(mobiSize, epubSize)
            
            // fields[1] = isNew (2=最近更新), fields[2] = isCompleted (1=已完成)
            let isNew = fields.count > 1 ? (Int(fields[1]) ?? 0) == 2 : false
            let isCompleted = fields.count > 2 ? (Int(fields[2]) ?? 0) == 1 : false
            
            let isFree = sizeMB > 0
            let title = type.isEmpty ? name : "\(type) \(name)"

            chapters.append(
                MangaChapter(
                    id: volID,
                    title: title,
                    date: date.isEmpty ? "Unknown" : date,
                    isFree: isFree,
                    volID: volID,
                    sizeMB: sizeMB,
                    pageCount: pageCount,
                    isCompleted: isCompleted,
                    isNew: isNew
                )
            )
        }

        return chapters.sorted { lhs, rhs in
            lhs.id > rhs.id
        }
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
