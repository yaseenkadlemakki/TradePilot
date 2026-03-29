import Foundation

// MARK: - Response models

struct RedditPost: Codable, Hashable {
    let subreddit: String
    let title: String
    let selftext: String
    let score: Int
    let numComments: Int
    let createdUtc: Double

    enum CodingKeys: String, CodingKey {
        case subreddit
        case title
        case selftext
        case score
        case numComments  = "num_comments"
        case createdUtc   = "created_utc"
    }
}

private struct RedditListing: Codable {
    struct Child: Codable {
        let data: RedditPost
    }
    struct ListingData: Codable {
        let children: [Child]
    }
    let data: ListingData
}

private struct OAuthResponse: Codable {
    let accessToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType   = "token_type"
    }
}

// MARK: - Service

/// Scrapes recent posts from r/wallstreetbets, r/options, and r/stocks.
actor RedditService {
    private static let oauthURL  = "https://www.reddit.com/api/v1/access_token"
    private static let apiBase   = "https://oauth.reddit.com"
    static let targetSubreddits  = ["wallstreetbets", "options", "stocks"]

    private let client: APIClient
    private let keychain: KeychainManager
    private let session: URLSession
    private var accessToken: String?
    private var tokenExpiresAt: Date?

    init(
        client: APIClient = APIClient(),
        keychain: KeychainManager = KeychainManager(),
        session: URLSession = .shared
    ) {
        self.client   = client
        self.keychain = keychain
        self.session  = session
    }

    /// Fetch hot posts from all target subreddits.
    func fetchPosts(limit: Int = 100) async throws -> [RedditPost] {
        let token = try await ensureToken()
        var posts: [RedditPost] = []
        for sub in Self.targetSubreddits {
            let urlString = "\(Self.apiBase)/r/\(sub)/hot?limit=\(limit)"
            guard let url = URL(string: urlString) else { continue }
            let headers = [
                "Authorization": "Bearer \(token)",
                "User-Agent": "TradePilot/1.0 by TradePilotApp"
            ]
            let listing: RedditListing = try await client.fetch(url: url, headers: headers)
            posts.append(contentsOf: listing.data.children.map(\.data))
        }
        return posts
    }

    // MARK: Private

    private func ensureToken() async throws -> String {
        if let existing = accessToken, let expiresAt = tokenExpiresAt, Date() < expiresAt {
            return existing
        }

        guard
            let clientID     = keychain.load(service: KeychainManager.ServiceKey.redditClientID),
            let clientSecret = keychain.load(service: KeychainManager.ServiceKey.redditClientSecret),
            !clientID.isEmpty, !clientSecret.isEmpty
        else { throw APIError.unauthorized }

        guard let url = URL(string: Self.oauthURL) else { throw APIError.invalidURL }

        // Build Basic-auth credential
        let credentials = "\(clientID):\(clientSecret)"
        guard let credData = credentials.data(using: .utf8) else { throw APIError.unauthorized }
        let encoded = credData.base64EncodedString()

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("TradePilot/1.0 by TradePilotApp", forHTTPHeaderField: "User-Agent")
        request.httpBody = Data("grant_type=client_credentials".utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.unauthorized
        }
        let oauthResp = try JSONDecoder().decode(OAuthResponse.self, from: data)
        accessToken    = oauthResp.accessToken
        tokenExpiresAt = Date().addingTimeInterval(3600)
        return oauthResp.accessToken
    }
}
