import Foundation

protocol BookshelfParsing {
    func parseBooks(from html: String) -> [Manga]
}

struct BookshelfParser: BookshelfParsing {
    func parseBooks(from html: String) -> [Manga] {
        guard html.contains("<html") else { return [] }

        // Treat only disp_divinfo(...) calls as valid book entries.
        return parseDispDivInfoScripts(from: html)
    }

    private func parseDispDivInfoScripts(from html: String) -> [Manga] {
        let regexResults = parseDispDivInfoByRegex(from: html)
        if !regexResults.isEmpty {
            return regexResults
        }

        let calls = extractDispDivInfoCallBodies(from: html)
        guard !calls.isEmpty else { return [] }

        var results: [Manga] = []
        var seen = Set<String>()

        for (index, body) in calls.enumerated() {
            let args = splitTopLevelArguments(body)
            // Expected args:
            // 0 div_id, 1 book_url, 2 cover_url, 3 border_color, 4-7 tags, 8 score, 9 name, 10 author, 11 status, 12 update
            guard args.count >= 13 else { continue }

            let divID = decodeJSConcatString(args[0])
            guard divID.contains("div_info_") else { continue }

            let bookURL = decodeJSConcatString(args[1])
            let coverURL = decodeJSConcatString(args[2])
            let score = decodeJSConcatString(args[8])
            let name = decodeJSConcatString(args[9])
            let author = decodeJSConcatString(args[10])
            let wordStatus = decodeJSConcatString(args[11])
            let wordUpdate = decodeJSConcatString(args[12])

            guard !bookURL.isEmpty else { continue }
            guard isBookDetailURL(bookURL) else { continue }

            let cleanName = HTMLParsingSupport.stripTags(name)
            guard !cleanName.isEmpty else { continue }
            guard !seen.contains(cleanName) else { continue }
            seen.insert(cleanName)

            let info = "\(wordStatus) \(wordUpdate)"
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let status: String
            if wordStatus.contains("卷") {
                status = "VOLUME"
            } else if wordStatus.contains("話") {
                status = "CHAPTER"
            } else if wordUpdate.contains("昨天") || wordUpdate.contains("前天") {
                status = "HOT"
            } else {
                status = "READING"
            }

            results.append(
                Manga(
                    id: (bookURL.hashValue & Int.max) + index,
                    title: cleanName,
                    author: HTMLParsingSupport.stripTags(author),
                    coverName: "book.closed.fill",
                    coverURL: coverURL.isEmpty ? nil : coverURL,
                    ratingText: score.isEmpty ? nil : score,
                    status: status,
                    updateInfo: info.isEmpty ? nil : info,
                    path: bookURL
                )
            )
        }

        return results
    }

    private func parseDispDivInfoByRegex(from html: String) -> [Manga] {
        let pattern = #"disp_divinfo\s*\(\s*(?:"div_info_"\s*\+\s*"\d+"|'div_info_'\s*\+\s*'\d+')\s*,\s*"([^"]+)"\s*,\s*"([^"]*)"\s*,\s*"[^"]*"\s*,\s*"[^"]*"\s*,\s*"[^"]*"\s*,\s*"[^"]*"\s*,\s*"[^"]*"\s*,\s*"([^"]*)"\s*,\s*"([^"]*)"\s*,\s*"([^"]*)"\s*,\s*"([^"]*)"\s*,\s*"([^"]*)"\s*\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }

        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, options: [], range: range)
        guard !matches.isEmpty else { return [] }

        var results: [Manga] = []
        var seen = Set<String>()

        for (index, match) in matches.enumerated() {
            guard
                let bookURL = capture(match, in: html, at: 1),
                let coverURL = capture(match, in: html, at: 2),
                let score = capture(match, in: html, at: 3),
                let name = capture(match, in: html, at: 4),
                let author = capture(match, in: html, at: 5),
                let wordStatus = capture(match, in: html, at: 6),
                let wordUpdate = capture(match, in: html, at: 7)
            else { continue }
            guard isBookDetailURL(bookURL) else { continue }

            let cleanName = HTMLParsingSupport.stripTags(name)
            guard !cleanName.isEmpty else { continue }
            guard !seen.contains(cleanName) else { continue }
            seen.insert(cleanName)

            let info = "\(wordStatus) \(wordUpdate)"
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let status: String
            if wordStatus.contains("卷") {
                status = "VOLUME"
            } else if wordStatus.contains("話") {
                status = "CHAPTER"
            } else if wordUpdate.contains("昨天") || wordUpdate.contains("前天") {
                status = "HOT"
            } else {
                status = "READING"
            }

            results.append(
                Manga(
                    id: (bookURL.hashValue & Int.max) + index,
                    title: cleanName,
                    author: HTMLParsingSupport.stripTags(author),
                    coverName: "book.closed.fill",
                    coverURL: coverURL.isEmpty ? nil : coverURL,
                    ratingText: score.isEmpty ? nil : score,
                    status: status,
                    updateInfo: info.isEmpty ? nil : info,
                    path: bookURL
                )
            )
        }

        return results
    }

    private func extractDispDivInfoCallBodies(from text: String) -> [String] {
        let marker = "disp_divinfo"
        var bodies: [String] = []
        var searchStart = text.startIndex

        while let markerRange = text.range(of: marker, range: searchStart..<text.endIndex) {
            guard let openParen = text[markerRange.upperBound...].firstIndex(of: "(") else {
                searchStart = markerRange.upperBound
                continue
            }

            var index = text.index(after: openParen)
            var depth = 1
            var inSingleQuote = false
            var inDoubleQuote = false
            var escaping = false
            var closeParen: String.Index?

            while index < text.endIndex {
                let ch = text[index]

                if escaping {
                    escaping = false
                } else if ch == "\\" {
                    escaping = true
                } else if ch == "'" && !inDoubleQuote {
                    inSingleQuote.toggle()
                } else if ch == "\"" && !inSingleQuote {
                    inDoubleQuote.toggle()
                } else if !inSingleQuote && !inDoubleQuote {
                    if ch == "(" {
                        depth += 1
                    } else if ch == ")" {
                        depth -= 1
                        if depth == 0 {
                            closeParen = index
                            break
                        }
                    }
                }

                index = text.index(after: index)
            }

            if let closeParen {
                let body = text[text.index(after: openParen)..<closeParen]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                bodies.append(String(body))
                searchStart = text.index(after: closeParen)
            } else {
                searchStart = markerRange.upperBound
            }
        }

        return bodies
    }

    private func splitTopLevelArguments(_ text: String) -> [String] {
        var args: [String] = []
        var current = ""
        var depth = 0
        var inSingleQuote = false
        var inDoubleQuote = false
        var escaping = false

        for ch in text {
            if escaping {
                current.append(ch)
                escaping = false
                continue
            }

            if ch == "\\" {
                current.append(ch)
                escaping = true
                continue
            }

            if ch == "'" && !inDoubleQuote {
                inSingleQuote.toggle()
                current.append(ch)
                continue
            }

            if ch == "\"" && !inSingleQuote {
                inDoubleQuote.toggle()
                current.append(ch)
                continue
            }

            if !inSingleQuote && !inDoubleQuote {
                if ch == "(" {
                    depth += 1
                } else if ch == ")" {
                    depth = max(0, depth - 1)
                } else if ch == "," && depth == 0 {
                    args.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                    current = ""
                    continue
                }
            }

            current.append(ch)
        }

        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty {
            args.append(tail)
        }
        return args
    }

    private func capture(_ match: NSTextCheckingResult, in source: String, at index: Int) -> String? {
        guard match.numberOfRanges > index else { return nil }
        guard let range = Range(match.range(at: index), in: source) else { return nil }
        return String(source[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func decodeJSConcatString(_ raw: String) -> String {
        let parts = splitTopLevelConcats(raw)
        guard !parts.isEmpty else { return "" }

        return parts.compactMap { part in
            guard part.count >= 2 else { return nil }
            if (part.hasPrefix("\"") && part.hasSuffix("\"")) || (part.hasPrefix("'") && part.hasSuffix("'")) {
                let start = part.index(after: part.startIndex)
                let end = part.index(before: part.endIndex)
                let core = String(part[start..<end])
                return core
                    .replacingOccurrences(of: "\\\"", with: "\"")
                    .replacingOccurrences(of: "\\'", with: "'")
                    .replacingOccurrences(of: "\\\\", with: "\\")
            }
            return nil
        }
        .joined()
    }

    private func splitTopLevelConcats(_ text: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var inSingleQuote = false
        var inDoubleQuote = false
        var escaping = false

        for ch in text {
            if escaping {
                current.append(ch)
                escaping = false
                continue
            }

            if ch == "\\" {
                current.append(ch)
                escaping = true
                continue
            }

            if ch == "'" && !inDoubleQuote {
                inSingleQuote.toggle()
                current.append(ch)
                continue
            }

            if ch == "\"" && !inSingleQuote {
                inDoubleQuote.toggle()
                current.append(ch)
                continue
            }

            if ch == "+" && !inSingleQuote && !inDoubleQuote {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    parts.append(trimmed)
                }
                current = ""
                continue
            }

            current.append(ch)
        }

        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty {
            parts.append(tail)
        }
        return parts
    }

    private func isBookDetailURL(_ raw: String) -> Bool {
        let lowered = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if lowered.isEmpty || lowered == "#" || lowered.hasPrefix("javascript:") {
            return false
        }
        if lowered.range(of: #"/c/[^/?#]+"#, options: .regularExpression) != nil {
            return true
        }
        if lowered.range(of: #"/(?:comic|manga|book)/\d+"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }
}
