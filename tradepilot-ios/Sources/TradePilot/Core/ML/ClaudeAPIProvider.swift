import Foundation

/// `LLMProvider` backed by the Anthropic Claude API.
/// Requires a valid API key stored in the system Keychain under the Claude API key service.
///
/// Thread-safety note: `@unchecked Sendable` is used because `apiKey` is immutable after
/// initialization and `URLSession` is safe to use from multiple threads.
final class ClaudeAPIProvider: LLMProvider, @unchecked Sendable {
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let model    = "claude-opus-4-6"
    private static let timeoutSeconds: Double = 30
    private static let maxRetries = 3

    var name: String { "Claude" }
    var isAvailable: Bool { apiKey != nil }

    private let apiKey: String?
    private let session: URLSession

    /// - Parameters:
    ///   - apiKey: Override the key stored in the Keychain.
    ///   - session: URLSession to use for requests (injectable for testing).
    init(apiKey: String? = nil, session: URLSession = .shared) {
        let keychain = KeychainManager()
        self.apiKey  = apiKey ?? keychain.load(service: KeychainManager.ServiceKey.claudeAPIKey)
        self.session = session
    }

    func analyze(prompt: String) async throws -> String {
        guard let key = apiKey else { throw LLMProviderError.notAvailable }

        let body: [String: Any] = [
            "model":      Self.model,
            "max_tokens": 1024,
            "messages":   [["role": "user", "content": prompt]]
        ]

        var request = URLRequest(url: Self.endpoint, timeoutInterval: Self.timeoutSeconds)
        request.httpMethod = "POST"
        request.setValue(key,              forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01",     forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        var lastError: Error = LLMProviderError.notAvailable
        for attempt in 0..<Self.maxRetries {
            let (data, response) = try await session.data(for: request)

            if let http = response as? HTTPURLResponse {
                switch http.statusCode {
                case 200:
                    break
                case 429, 529:
                    // Rate-limited or overloaded — exponential back-off
                    lastError = LLMProviderError.requestFailed(statusCode: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
                    if attempt < Self.maxRetries - 1 {
                        let delay = pow(2.0, Double(attempt))
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    } else {
                        throw lastError
                    }
                default:
                    let body = String(data: data, encoding: .utf8) ?? ""
                    throw LLMProviderError.requestFailed(statusCode: http.statusCode, body: body)
                }
            }

            guard
                let json    = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let content = (json["content"] as? [[String: Any]])?.first,
                let text    = content["text"] as? String
            else {
                throw LLMProviderError.decodingFailed
            }

            return text
        }
        throw lastError
    }
}
