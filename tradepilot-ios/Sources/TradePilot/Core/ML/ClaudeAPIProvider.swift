import Foundation

/// BYO-key Claude API provider.
/// Reads the API key from the Keychain (service: "claude_api_key"),
/// calls the Anthropic Messages API, and retries on rate-limit errors.
struct ClaudeAPIProvider: LLMProvider {

    let name = "Claude API (claude-sonnet-4-6)"

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let model = "claude-sonnet-4-6"
    private static let timeoutSeconds: TimeInterval = 30
    private static let maxRetries = 3

    private static let systemPrompt = """
    You are a professional financial advisor reviewing options trade proposals.
    Analyze the portfolio for coherence, risk exposure, and market regime alignment.
    Be concise and actionable. Flag contradictions and over-concentration.
    """

    var isAvailable: Bool {
        KeychainManager().read(service: "claude_api_key") != nil
    }

    func analyze(prompt: String) async throws -> String {
        guard let apiKey = KeychainManager().read(service: "claude_api_key") else {
            throw LLMProviderError.apiKeyMissing
        }
        return try await sendWithRetry(prompt: prompt, apiKey: apiKey, attempt: 0)
    }

    // MARK: Private

    private func sendWithRetry(prompt: String, apiKey: String, attempt: Int) async throws -> String {
        do {
            return try await send(prompt: prompt, apiKey: apiKey)
        } catch LLMProviderError.networkError(let underlying) {
            let nsErr = underlying as NSError
            // Retry on HTTP 429 or 529
            if (nsErr.code == 429 || nsErr.code == 529) && attempt < Self.maxRetries {
                let delay = pow(2.0, Double(attempt)) // 1s, 2s, 4s
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await sendWithRetry(prompt: prompt, apiKey: apiKey, attempt: attempt + 1)
            }
            throw LLMProviderError.networkError(underlying)
        }
    }

    private func send(prompt: String, apiKey: String) async throws -> String {
        var request = URLRequest(
            url: Self.endpoint,
            timeoutInterval: Self.timeoutSeconds
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": 1024,
            "system": Self.systemPrompt,
            "messages": [["role": "user", "content": prompt]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResp = response as? HTTPURLResponse, httpResp.statusCode != 200 {
            let code = httpResp.statusCode
            throw LLMProviderError.networkError(
                NSError(domain: "ClaudeAPI", code: code,
                        userInfo: [NSLocalizedDescriptionKey: "HTTP \(code)"])
            )
        }

        struct MessagesResponse: Decodable {
            struct Content: Decodable { let text: String }
            let content: [Content]
        }
        let parsed = try JSONDecoder().decode(MessagesResponse.self, from: data)
        guard let text = parsed.content.first?.text else {
            throw LLMProviderError.inferenceFailure("Empty response from Claude API")
        }
        return text
    }
}
