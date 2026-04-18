import Foundation

/// One hit from a web-search fallback. Fed to Gemini as context so the model
/// doesn't have to rely on stale training-data facts.
struct SearchResult: Equatable, Sendable {
    let title: String
    let snippet: String
    let url: String

    /// Formatted block for prompt injection: `[idx] title` / url / snippet.
    func promptBlock(index: Int) -> String {
        var block = "[\(index)] \(title)\n    \(url)"
        if !snippet.isEmpty {
            block += "\n    \(snippet.replacingOccurrences(of: "\n", with: " "))"
        }
        return block
    }
}

/// Parallel multi-source live lookup. α.10 onward queries DuckDuckGo Instant
/// Answer, English Wikipedia AND Danish Wikipedia in parallel. Results are
/// deduped by URL and capped at `limit`. All sources are key-free.
actor WebSearchService {
    static let shared = WebSearchService()

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 6
        config.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: config)
    }

    func search(query: String, limit: Int = 5) async -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        let isDanish = Self.looksDanish(trimmed)

        // Run all lookups in parallel. If the user's query is Danish we prioritise
        // Danish Wikipedia and only fall back to EN for coverage.
        async let ddgResults = fetchDDGInstantAnswer(query: trimmed)
        async let enWiki = fetchWikipediaSummaries(query: trimmed, lang: "en", limit: 3)
        async let daWiki = fetchWikipediaSummaries(query: trimmed, lang: "da", limit: 3)

        let (ddg, en, da) = await (ddgResults, enWiki, daWiki)

        // Prefer da results first when user is Danish, otherwise EN first.
        var combined = isDanish
            ? da + ddg + en
            : en + ddg + da

        // Deduplicate by URL
        var seen = Set<String>()
        combined = combined.filter { result in
            guard !result.url.isEmpty else { return true }
            let host = URL(string: result.url)?.absoluteString ?? result.url
            if seen.contains(host) { return false }
            seen.insert(host)
            return true
        }

        if combined.count > limit {
            combined = Array(combined.prefix(limit))
        }

        if combined.isEmpty {
            LoggingService.shared.log("WebSearch: no results for '\(trimmed)'", level: .warning)
        } else {
            LoggingService.shared.log("WebSearch: \(combined.count) results (\(ddg.count) DDG + \(en.count) enWiki + \(da.count) daWiki, isDanish=\(isDanish)) for '\(trimmed.prefix(60))'")
        }
        return combined
    }

    // MARK: - DuckDuckGo Instant Answer

    private func fetchDDGInstantAnswer(query: String) async -> [SearchResult] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.duckduckgo.com/?q=\(encoded)&format=json&no_html=1&skip_disambig=1") else {
            return []
        }
        guard let (data, _) = try? await session.data(from: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        var results: [SearchResult] = []

        if let abstract = root["AbstractText"] as? String, !abstract.isEmpty {
            let source = (root["AbstractSource"] as? String) ?? "DuckDuckGo"
            let sourceURL = (root["AbstractURL"] as? String) ?? "https://duckduckgo.com/?q=\(encoded)"
            results.append(SearchResult(title: source, snippet: abstract, url: sourceURL))
        }

        if let answer = root["Answer"] as? String, !answer.isEmpty {
            results.append(SearchResult(
                title: "DuckDuckGo direct answer",
                snippet: answer,
                url: "https://duckduckgo.com/?q=\(encoded)"
            ))
        }

        if let related = root["RelatedTopics"] as? [[String: Any]] {
            for topic in related.prefix(2) {
                guard let text = topic["Text"] as? String, !text.isEmpty else { continue }
                let firstURL = topic["FirstURL"] as? String ?? ""
                let title = text.components(separatedBy: " - ").first ?? text
                let snippet = text.count > title.count
                    ? String(text.dropFirst(title.count)).trimmingCharacters(in: CharacterSet(charactersIn: " -"))
                    : text
                results.append(SearchResult(
                    title: title,
                    snippet: snippet.isEmpty ? text : snippet,
                    url: firstURL
                ))
            }
        }
        return results
    }

    // MARK: - Wikipedia (language-specific)

    private func fetchWikipediaSummaries(query: String, lang: String, limit: Int) async -> [SearchResult] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let openURL = URL(string: "https://\(lang).wikipedia.org/w/api.php?action=opensearch&search=\(encoded)&limit=\(limit)&format=json") else {
            return []
        }
        guard let (data, _) = try? await session.data(from: openURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [Any],
              root.count >= 4,
              let titles = root[1] as? [String],
              let urls = root[3] as? [String] else {
            return []
        }

        var results: [SearchResult] = []
        await withTaskGroup(of: SearchResult?.self) { group in
            for (index, title) in titles.enumerated() where index < limit {
                let pageURL = (index < urls.count) ? urls[index] : ""
                group.addTask { [weak self] in
                    await self?.fetchWikiSummary(title: title, pageURL: pageURL, lang: lang)
                }
            }
            for await result in group {
                if let result { results.append(result) }
            }
        }
        return results
    }

    private func fetchWikiSummary(title: String, pageURL: String, lang: String) async -> SearchResult? {
        let normalised = title.replacingOccurrences(of: " ", with: "_")
        guard let encoded = normalised.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://\(lang).wikipedia.org/api/rest_v1/page/summary/\(encoded)") else {
            return nil
        }
        guard let (data, _) = try? await session.data(from: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let extract = root["extract"] as? String, !extract.isEmpty else {
            return nil
        }
        return SearchResult(
            title: (root["title"] as? String) ?? title,
            snippet: extract,
            url: pageURL.isEmpty ? "https://\(lang).wikipedia.org/wiki/\(normalised)" : pageURL
        )
    }

    // MARK: - Language detection

    /// Fast heuristic for "is this Danish" — looks for unique Danish letters
    /// (æ/ø/å) OR a common Danish stop-word. Good enough for prioritising
    /// Danish Wikipedia results; false positives don't hurt since EN is still
    /// queried in parallel.
    static func looksDanish(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.contains("æ") || lower.contains("ø") || lower.contains("å") {
            return true
        }
        let stopWords = [
            " hvem ", " hvad ", " hvor ", " hvorfor ", " hvornår ",
            " og ", " eller ", " ikke ", " dansk ", " denmark ", " danmark ",
            " kongen ", " regering ", " folketinget "
        ]
        let padded = " \(lower) "
        return stopWords.contains { padded.contains($0) }
    }
}
