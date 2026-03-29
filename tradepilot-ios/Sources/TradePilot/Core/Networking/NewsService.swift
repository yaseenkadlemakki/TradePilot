import Foundation

// MARK: - Response models

struct NewsArticle: Codable, Hashable {
    let source: NewsSource
    let title: String
    let description: String?
    let url: String
    let publishedAt: Date

    enum CodingKeys: String, CodingKey {
        case source, title, description, url
        case publishedAt = "publishedAt"
    }
}

struct NewsSource: Codable, Hashable {
    let id: String?
    let name: String
}

private struct NewsAPIResponse: Codable {
    let status: String
    let totalResults: Int
    let articles: [NewsArticle]
}

// MARK: - Service

/// Fetches financial news articles from NewsAPI.
actor NewsService {
    private static let baseURL = "https://newsapi.org/v2"
    private let client: APIClient
    private let keychain: KeychainManager

    init(client: APIClient = APIClient(), keychain: KeychainManager = KeychainManager()) {
        self.client   = client
        self.keychain = keychain
    }

    /// Fetch top financial headlines, optionally filtered by `query`.
    func fetchArticles(query: String? = nil, pageSize: Int = 50) async throws -> [NewsArticle] {
        let apiKey = try requireKey()

        var components = URLComponents(string: "\(Self.baseURL)/top-headlines")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "category", value: "business"),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "pageSize", value: "\(pageSize)")
        ]
        if let q = query { queryItems.append(URLQueryItem(name: "q", value: q)) }
        components.queryItems = queryItems
        guard let url = components.url else { throw APIError.invalidURL }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response: NewsAPIResponse = try await client.fetch(url: url, headers: ["X-Api-Key": apiKey])
        return response.articles
    }

    /// Fetch articles mentioning a specific `ticker`.
    func fetchTickerNews(ticker: String, pageSize: Int = 20) async throws -> [NewsArticle] {
        try await fetchArticles(query: ticker, pageSize: pageSize)
    }

    // MARK: Private

    private func requireKey() throws -> String {
        guard let key = keychain.load(service: KeychainManager.ServiceKey.newsAPIKey), !key.isEmpty else {
            throw APIError.unauthorized
        }
        return key
    }
}
