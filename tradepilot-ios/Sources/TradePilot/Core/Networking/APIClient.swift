import Foundation

// MARK: - Errors

enum APIError: Error, LocalizedError {
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?)
    case networkError(underlying: Error)
    case decodingError(underlying: Error)
    case serverError(statusCode: Int)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .unauthorized:             return "API key is missing or invalid."
        case .rateLimited(let t):       return "Rate limited. Retry after \(t.map { "\($0)s" } ?? "unknown")."
        case .networkError(let e):      return "Network error: \(e.localizedDescription)"
        case .decodingError(let e):     return "Decoding error: \(e.localizedDescription)"
        case .serverError(let code):    return "Server error: HTTP \(code)"
        case .invalidURL:               return "Invalid URL."
        }
    }
}

// MARK: - Client

/// Generic HTTP client backed by URLSession with retry and exponential back-off.
actor APIClient {
    private let session: URLSession
    private let maxRetries: Int
    private let decoder: JSONDecoder

    init(session: URLSession = .shared, maxRetries: Int = 3) {
        self.session   = session
        self.maxRetries = maxRetries

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    /// Fetch and decode a `Decodable` value from `url`.
    func fetch<T: Decodable>(url: URL, headers: [String: String] = [:]) async throws -> T {
        var lastError: Error = APIError.networkError(underlying: URLError(.unknown))

        for attempt in 0..<maxRetries {
            do {
                let data = try await performRequest(url: url, headers: headers)
                return try decoder.decode(T.self, from: data)
            } catch APIError.unauthorized {
                throw APIError.unauthorized           // never retry auth failures
            } catch APIError.decodingError(let e) {
                throw APIError.decodingError(underlying: e)
            } catch {
                lastError = error
                if attempt < maxRetries - 1 {
                    let delay = pow(2.0, Double(attempt)) // 1s, 2s, 4s
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        throw lastError
    }

    // MARK: Private

    private func performRequest(url: URL, headers: [String: String]) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 30)
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(underlying: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(underlying: URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 200..<300:
            return data
        case 401, 403:
            throw APIError.unauthorized
        case 429:
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw APIError.rateLimited(retryAfter: retryAfter)
        default:
            throw APIError.serverError(statusCode: http.statusCode)
        }
    }
}
