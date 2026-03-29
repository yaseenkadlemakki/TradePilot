import Foundation

// MARK: - Response models

struct UnusualWhalesFlow: Codable, Hashable {
    let ticker: String
    let contractType: String
    let strike: Double
    let expiration: String
    let premium: Double
    let volume: Int
    let openInterest: Int
    let sentiment: String           // "bullish" | "bearish"
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case ticker
        case contractType  = "put_call"
        case strike        = "strike_price"
        case expiration    = "expiry_date"
        case premium
        case volume
        case openInterest  = "open_interest"
        case sentiment
        case timestamp     = "date"
    }
}

private struct FlowResponse: Codable {
    let data: [UnusualWhalesFlow]
}

// MARK: - Service

/// Fetches unusual options flow data from Unusual Whales.
actor UnusualWhalesService {
    private static let baseURL = "https://api.unusualwhales.com/api"
    private let client: APIClient
    private let keychain: KeychainManager

    init(client: APIClient = APIClient(), keychain: KeychainManager = KeychainManager()) {
        self.client   = client
        self.keychain = keychain
    }

    /// Fetch the most recent unusual options flow, optionally filtered by ticker.
    func fetchFlow(ticker: String? = nil) async throws -> [UnusualWhalesFlow] {
        let apiKey = try requireKey()
        var urlString = "\(Self.baseURL)/option-trades/flow-alerts?limit=100"
        if let ticker { urlString += "&ticker=\(ticker)" }
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        let headers = ["Authorization": "Bearer \(apiKey)"]
        let response: FlowResponse = try await client.fetch(url: url, headers: headers)
        return response.data
    }

    // MARK: Private

    private func requireKey() throws -> String {
        guard let key = keychain.load(service: KeychainManager.ServiceKey.unusualWhalesAPIKey), !key.isEmpty else {
            throw APIError.unauthorized
        }
        return key
    }
}
