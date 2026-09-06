// MetacriticRatingService.swift
// Actor-isolated service for fetching and caching Metacritic and critic review scores and descriptions.
//

import Foundation

public struct MetacriticRating: Sendable, Equatable, Codable {
    public let score: Int
    public let reviewCount: Int?
    public let summaryDescription: String?
    public let sourceURL: URL?

    public init(
        score: Int,
        reviewCount: Int? = nil,
        summaryDescription: String? = nil,
        sourceURL: URL? = nil
    ) {
        self.score = score
        self.reviewCount = reviewCount
        self.summaryDescription = summaryDescription
        self.sourceURL = sourceURL
    }
}

public actor MetacriticRatingService {
    public static let shared = MetacriticRatingService()

    private var cache: [String: MetacriticRating?] = [:]
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 6.0
        config.timeoutIntervalForResource = 10.0
        self.session = URLSession(configuration: config)
    }

    public func fetchRating(for title: String) async -> MetacriticRating? {
        let key = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return nil }

        if let cached = cache[key] {
            return cached
        }

        // 1. Try Metacritic direct page
        if let rating = await fetchMetacriticPage(title: title) {
            cache[key] = rating
            return rating
        }

        // 2. Fallback to OpenCritic API (public critic aggregator)
        if let rating = await fetchOpenCriticScore(title: title) {
            cache[key] = rating
            return rating
        }

        cache[key] = nil
        return nil
    }

    private func fetchMetacriticPage(title: String) async -> MetacriticRating? {
        let slug = generateSlug(from: title)
        guard !slug.isEmpty else { return nil }

        let candidateURLs = [
            "https://www.metacritic.com/game/\(slug)/",
            "https://www.metacritic.com/game/xbox-series-x/\(slug)/",
            "https://www.metacritic.com/game/xbox-one/\(slug)/",
            "https://www.metacritic.com/game/pc/\(slug)/"
        ]

        for urlString in candidateURLs {
            guard let url = URL(string: urlString) else { continue }
            var request = URLRequest(url: url)
            request.setValue(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
                forHTTPHeaderField: "User-Agent"
            )
            request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    continue
                }
                guard let html = String(data: data, encoding: .utf8) else { continue }

                if let score = extractMetascore(from: html) {
                    let reviewCount = extractReviewCount(from: html)
                    let description = extractDescription(from: html)
                    return MetacriticRating(
                        score: score,
                        reviewCount: reviewCount,
                        summaryDescription: description,
                        sourceURL: url
                    )
                }
            } catch {
                continue
            }
        }
        return nil
    }

    private func extractMetascore(from html: String) -> Int? {
        // Pattern 1: JSON-LD schema "ratingValue":"92"
        if let range = html.range(of: #""ratingValue"\s*:\s*"?(\d{1,3})""#, options: .regularExpression) {
            let match = String(html[range])
            let digits = match.filter { $0.isNumber }
            if let val = Int(digits), (0...100).contains(val) {
                return val
            }
        }

        // Pattern 2: Meta tag twitter:data1
        if let range = html.range(of: #"name="twitter:data1"\s+content="(\d{1,3})""#, options: .regularExpression) {
            let match = String(html[range])
            let digits = match.filter { $0.isNumber }
            if let val = Int(digits), (0...100).contains(val) {
                return val
            }
        }

        // Pattern 3: score number class span
        if let range = html.range(of: #"c-productScoreInfo_scoreNumber[^>]*>.*?<span>(\d{1,3})</span>"#, options: .regularExpression) {
            let match = String(html[range])
            if let spanRange = match.range(of: #"<span>(\d{1,3})</span>"#, options: .regularExpression) {
                let digits = String(match[spanRange]).filter { $0.isNumber }
                if let val = Int(digits), (0...100).contains(val) {
                    return val
                }
            }
        }

        // Pattern 4: c-siteReviewScore
        if let range = html.range(of: #"c-siteReviewScore[^>]*>.*?<span>(\d{1,3})</span>"#, options: .regularExpression) {
            let match = String(html[range])
            if let spanRange = match.range(of: #"<span>(\d{1,3})</span>"#, options: .regularExpression) {
                let digits = String(match[spanRange]).filter { $0.isNumber }
                if let val = Int(digits), (0...100).contains(val) {
                    return val
                }
            }
        }

        return nil
    }

    private func extractReviewCount(from html: String) -> Int? {
        if let range = html.range(of: #""ratingCount"\s*:\s*"?(\d{1,5})""#, options: .regularExpression) {
            let match = String(html[range])
            let digits = match.filter { $0.isNumber }
            return Int(digits)
        }
        return nil
    }

    private func extractDescription(from html: String) -> String? {
        // 1. JSON-LD "description"
        if let range = html.range(of: #""description"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)""#, options: .regularExpression) {
            let matched = String(html[range])
            if let colonIndex = matched.firstIndex(of: ":") {
                var raw = String(matched[colonIndex...]).trimmingCharacters(in: CharacterSet(charactersIn: ": \t\r\n\""))
                raw = unescapeJSONString(raw)
                raw = sanitizeDescription(raw)
                if !raw.isEmpty, raw.count > 20 {
                    return raw
                }
            }
        }

        // 2. Meta description tag
        if let range = html.range(of: #"<meta\s+(?:name="description"|property="og:description")\s+content="([^"]+)""#, options: .regularExpression) {
            let matched = String(html[range])
            if let contentRange = matched.range(of: #"content="([^"]+)""#, options: .regularExpression) {
                let contentMatched = String(matched[contentRange])
                var raw = contentMatched
                    .replacingOccurrences(of: #"content=""#, with: "")
                    .replacingOccurrences(of: "\"", with: "")
                if let summaryRange = raw.range(of: "Summary: ", options: .caseInsensitive) {
                    raw = String(raw[summaryRange.upperBound...])
                }
                raw = sanitizeDescription(raw)
                if !raw.isEmpty, raw.count > 20 {
                    return raw
                }
            }
        }

        return nil
    }

    private func unescapeJSONString(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\r", with: "")
            .replacingOccurrences(of: "\\t", with: " ")
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\/", with: "/")
            .replacingOccurrences(of: "\\'", with: "'")
    }

    private func sanitizeDescription(_ text: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let firstParagraph = cleaned.components(separatedBy: "\n\n").first?.trimmingCharacters(in: .whitespacesAndNewlines),
           !firstParagraph.isEmpty, firstParagraph.count > 30 {
            return firstParagraph
        }
        return cleaned
    }

    private func fetchOpenCriticScore(title: String) async -> MetacriticRating? {
        let cleanTitle = cleanGameTitle(title)
        guard let encoded = cleanTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.opencritic.com/api/game/search?criteria=\(encoded)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

            struct OpenCriticSearchItem: Decodable {
                let id: Int
                let name: String
                let score: Double?
            }

            let items = try JSONDecoder().decode([OpenCriticSearchItem].self, from: data)
            guard let first = items.first else { return nil }

            guard let detailURL = URL(string: "https://api.opencritic.com/api/game/\(first.id)") else { return nil }
            let (detailData, detailResp) = try await session.data(from: detailURL)
            guard let detailHttp = detailResp as? HTTPURLResponse, detailHttp.statusCode == 200 else {
                if let score = first.score, score > 0 {
                    return MetacriticRating(score: Int(round(score)), reviewCount: nil, summaryDescription: nil, sourceURL: nil)
                }
                return nil
            }

            struct OpenCriticDetail: Decodable {
                let topCriticScore: Double?
                let numReviews: Int?
                let description: String?
            }

            let detail = try JSONDecoder().decode(OpenCriticDetail.self, from: detailData)
            let finalScore = detail.topCriticScore ?? first.score ?? 0
            if finalScore > 0 {
                return MetacriticRating(
                    score: Int(round(finalScore)),
                    reviewCount: detail.numReviews,
                    summaryDescription: detail.description.map { sanitizeDescription($0) },
                    sourceURL: URL(string: "https://opencritic.com/game/\(first.id)/\(first.name)")
                )
            }
        } catch {
            return nil
        }
        return nil
    }

    private func generateSlug(from title: String) -> String {
        let cleaned = cleanGameTitle(title)
        let slug = cleaned.lowercased()
            .replacingOccurrences(of: "&", with: "and")
            .replacingOccurrences(of: "’", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: ":", with: "")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return slug
    }

    private func cleanGameTitle(_ title: String) -> String {
        var cleaned = title
        if let parenIndex = cleaned.firstIndex(of: "(") {
            cleaned = String(cleaned[..<parenIndex])
        }
        if let bracketIndex = cleaned.firstIndex(of: "[") {
            cleaned = String(cleaned[..<bracketIndex])
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
