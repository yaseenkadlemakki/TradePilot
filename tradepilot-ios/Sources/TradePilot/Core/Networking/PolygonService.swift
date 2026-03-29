import Foundation

// MARK: - Response models

struct PolygonOHLCV: Codable {
    let ticker: String
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
    let vwap: Double?
    let timestamp: Int           // Unix ms

    enum CodingKeys: String, CodingKey {
        case ticker = "T"
        case open   = "o"
        case high   = "h"
        case low    = "l"
        case close  = "c"
        case volume = "v"
        case vwap   = "vw"
        case timestamp = "t"
    }
}

struct PolygonOptionsChain: Codable {
    let results: [PolygonOptionContract]
    let status: String
}

struct PolygonOptionContract: Codable {
    let ticker: String
    let strike: Double
    let expirationDate: String
    let contractType: String
    let openInterest: Int?
    let volume: Int?
    let bid: Double?
    let ask: Double?
    let impliedVolatility: Double?
    let delta: Double?
    let gamma: Double?
    let theta: Double?
    let vega: Double?

    enum CodingKeys: String, CodingKey {
        case ticker
        case strike              = "strike_price"
        case expirationDate      = "expiration_date"
        case contractType        = "contract_type"
        case openInterest        = "open_interest"
        case volume
        case bid, ask
        case impliedVolatility   = "implied_volatility"
        case delta, gamma, theta, vega
    }
}

private struct AggregatesResponse: Codable {
    let results: [PolygonOHLCV]?
    let status: String
}

private struct RSIValue: Codable { let value: Double }
private struct RSIResult: Codable { let values: [RSIValue] }
private struct RSIResponse: Codable { let results: RSIResult? }

// MARK: - Service

/// Fetches OHLCV, options chains, and technical indicators from Polygon.io.
actor PolygonService {
    private static let baseURL = "https://api.polygon.io"
    private let client: APIClient
    private let keychain: KeychainManager

    init(client: APIClient = APIClient(), keychain: KeychainManager = KeychainManager()) {
        self.client  = client
        self.keychain = keychain
    }

    /// Fetch the latest daily bar for `ticker`.
    func fetchOHLCV(ticker: String) async throws -> PolygonOHLCV {
        let apiKey = try requireKey()
        let encodedTicker = ticker.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ticker
        let urlString = "\(Self.baseURL)/v2/aggs/ticker/\(encodedTicker)/prev"
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        let headers = ["Authorization": "Bearer \(apiKey)"]

        struct PrevResponse: Codable {
            let results: [PolygonOHLCV]?
        }
        let response: PrevResponse = try await client.fetch(url: url, headers: headers)
        guard let bar = response.results?.first else {
            throw APIError.serverError(statusCode: 404)
        }
        return bar
    }

    /// Fetch options chain for `ticker` (nearest two expirations).
    func fetchOptionsChain(ticker: String) async throws -> [PolygonOptionContract] {
        let apiKey = try requireKey()
        let encodedTicker = ticker.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ticker
        let urlString = "\(Self.baseURL)/v3/reference/options/\(encodedTicker)?limit=250"
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        let headers = ["Authorization": "Bearer \(apiKey)"]
        let response: PolygonOptionsChain = try await client.fetch(url: url, headers: headers)
        return response.results
    }

    /// Fetch RSI(14) for `ticker`.
    func fetchRSI(ticker: String) async throws -> Double {
        let apiKey = try requireKey()
        let encodedTicker = ticker.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ticker
        let urlString = "\(Self.baseURL)/v1/indicators/rsi/\(encodedTicker)?timespan=day&window=14&series_type=close&limit=1"
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        let headers = ["Authorization": "Bearer \(apiKey)"]

        let response: RSIResponse = try await client.fetch(url: url, headers: headers)
        guard let value = response.results?.values.first?.value else {
            throw APIError.serverError(statusCode: 404)
        }
        return value
    }

    // MARK: Private

    private func requireKey() throws -> String {
        guard let key = keychain.load(service: KeychainManager.ServiceKey.polygonAPIKey), !key.isEmpty else {
            throw APIError.unauthorized
        }
        return key
    }
}
