import Foundation
import Network

// MARK: - Errors

enum APIError: Error, LocalizedError {
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?)
    case networkError(underlying: Error)
    case decodingError(underlying: Error)
    case serverError(statusCode: Int)
    case invalidURL
    case offline

    var errorDescription: String? {
        switch self {
        case .unauthorized:             return "API key is missing or invalid. Check Settings to verify your keys."
        case .rateLimited(let retryAfter): return "Rate limited. Retry after \(retryAfter.map { "\(Int($0))s" } ?? "a moment")."
        case .networkError(let error):  return "Network error: \(error.localizedDescription)"
        case .decodingError(let error): return "Decoding error: \(error.localizedDescription)"
        case .serverError(let code):    return "Server error: HTTP \(code)"
        case .invalidURL:               return "Invalid URL."
        case .offline:                  return "No internet connection. Check your network settings and try again."
        }
    }

    /// Whether the error is recoverable by the user without developer action.
    var isUserRecoverable: Bool {
        switch self {
        case .offline, .rateLimited: return true
        case .unauthorized:          return true   // user can fix key in Settings
        default:                     return false
        }
    }
}

// MARK: - Client

/// Generic HTTP client backed by URLSession with retry, exponential back-off, and offline detection.
actor APIClient {
    private let session: URLSession
    private let maxRetries: Int
    private let decoder: JSONDecoder
    private let monitor: NWPathMonitor
    private var isConnected: Bool = true

    init(session: URLSession = .shared, maxRetries: Int = 3) {
        self.session    = session
        self.maxRetries = maxRetries

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        monitor = NWPathMonitor()
        // Attach handler before starting so no updates are missed.
        monitor.pathUpdateHandler = { [weak self] path in
            Task { await self?.setConnected(path.status == .satisfied) }
        }
        monitor.start(queue: DispatchQueue(label: "com.tradepilot.network-monitor"))
        // For custom sessions (e.g. unit tests), assume connected; only use NWPathMonitor for the shared session.
        isConnected = session === URLSession.shared
            ? monitor.currentPath.status == .satisfied
            : true
    }

    /// Retained for callers that need to trigger a manual connectivity refresh.
    func startMonitoring() {
        isConnected = monitor.currentPath.status == .satisfied
    }

    private func setConnected(_ value: Bool) {
        isConnected = value
    }

    /// Fetch and decode a `Decodable` value from `url`.
    func fetch<T: Decodable>(url: URL, headers: [String: String] = [:]) async throws -> T {
        guard isConnected else { throw APIError.offline }
        var lastError: Error = APIError.networkError(underlying: URLError(.unknown))

        for attempt in 0..<maxRetries {
            do {
                let data = try await performRequest(url: url, headers: headers)
                return try decoder.decode(T.self, from: data)
            } catch APIError.unauthorized {
                throw APIError.unauthorized           // never retry auth failures
            } catch APIError.decodingError(let error) {
                throw APIError.decodingError(underlying: error)
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
