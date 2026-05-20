import Foundation

/// CryptoCompare 公開新聞 API
enum CryptoNewsService {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 12
        return URLSession(configuration: config)
    }()

    static func fetchRecentNews(limit: Int = 3) async -> [CryptoHotNewsItem] {
        guard let url = URL(string: "https://min-api.cryptocompare.com/data/v2/news/?lang=EN") else {
            return MockCryptoNewsService.topHotNews(limit: limit)
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return MockCryptoNewsService.topHotNews(limit: limit)
            }
            return try parse(data, limit: limit)
        } catch {
            return MockCryptoNewsService.topHotNews(limit: limit)
        }
    }

    private static func parse(_ data: Data, limit: Int) throws -> [CryptoHotNewsItem] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = json["Data"] as? [[String: Any]] else {
            return MockCryptoNewsService.topHotNews(limit: limit)
        }

        return rows.prefix(limit).compactMap { row in
            guard let title = row["title"] as? String else { return nil }
            let body = (row["body"] as? String) ?? ""
            let summary = trimmedSummary(from: body, fallback: title)
            let published = (row["published_on"] as? TimeInterval).map {
                Date(timeIntervalSince1970: $0)
            } ?? Date()
            let source = (row["source_info"] as? [String: Any])?["name"] as? String
                ?? (row["source"] as? String)
                ?? "CryptoCompare"
            let id: String = {
                if let s = row["id"] as? String { return s }
                if let n = row["id"] as? Int { return String(n) }
                return title
            }()
            let upvotes = row["upvotes"] as? Int ?? 0
            let downvotes = row["downvotes"] as? Int ?? 0
            let score = max(1, upvotes * 3 + downvotes + 10)

            return CryptoHotNewsItem(
                id: id,
                title: title,
                summary: summary,
                body: body.isEmpty ? summary : body,
                publishedAt: published,
                discussionScore: score,
                source: source,
                articleURL: row["url"] as? String
            )
        }
    }

    private static func trimmedSummary(from body: String, fallback: String) -> String {
        let text = body
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return fallback }
        if text.count <= 120 { return text }
        return String(text.prefix(117)) + "…"
    }
}
