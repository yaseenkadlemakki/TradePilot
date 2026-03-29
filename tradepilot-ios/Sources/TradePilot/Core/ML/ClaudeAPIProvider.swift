import Foundation

/// `LLMProvider` backed by the Anthropic Claude API.
/// Requires a valid API key stored in `UserDefaults` under `claudeAPIKey`.
final class ClaudeAPIProvider: LLMProvider, @unchecked Sendable {
    static let userDefaultsKey = "com.tradepilot.claude.apiKey"
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let model    = "claude-opus-4-6"
    private static let timeoutSeconds: Double = 30

    var name: String { "Claude" }
    var isAvailable: Bool { apiKey != nil }

    private let apiKey: String?

    /// - Parameter apiKey: Override the key stored in `UserDefaults`.
    init(apiKey: String? = nil) {
        self.apiKey = apiKey ?? UserDefaults.standard.string(forKey: Self.userDefaultsKey)
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

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LLMProviderError.requestFailed(statusCode: http.statusCode, body: body)
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
}
