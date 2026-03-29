import Foundation

// MARK: - Claude API Provider

/// Cloud LLM provider using the Anthropic Claude API with a BYO key stored in Keychain.
struct ClaudeAPIProvider: LLMProvider {

    private static let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let model = "claude-sonnet-4-6"
    private static let timeoutSeconds: Double = 30
    private static let systemPrompt = """
        You are an expert financial advisor reviewing a portfolio of 4 options trades. \
        Analyze the trades for coherence, risk concentration, and market regime alignment. \
        Identify contradictory positions, sector overweighting, and one-sided directional bets. \
        Respond with a concise structured analysis: findings first, then a recommendation.
        """

    private let keychain: KeychainManager

    init(keychain: KeychainManager = KeychainManager()) {
        self.keychain = keychain
    }

    // MARK: LLMProvider

    var isAvailable: Bool {
        keychain.load(service: KeychainManager.ServiceKey.claudeAPIKey) != nil
    }

    var name: String { "ClaudeAPI(\(Self.model))" }

    func analyze(prompt: String) async throws -> String {
        guard let apiKey = keychain.load(service: KeychainManager.ServiceKey.claudeAPIKey) else {
            throw LLMProviderError.unavailable(provider: name)
        }

        var request = URLRequest(url: Self.apiURL, timeoutInterval: Self.timeoutSeconds)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body = ClaudeRequestBody(
            model: Self.model,
            maxTokens: 512,
            system: Self.systemPrompt,
            messages: [ClaudeMessage(role: "user", content: prompt)]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw LLMProviderError.timeout
        } catch {
            throw LLMProviderError.networkError(underlying: error)
        }

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw LLMProviderError.invalidResponse
        }

        let parsed = try JSONDecoder().decode(ClaudeResponseBody.self, from: data)
        guard let text = parsed.content.first?.text else {
            throw LLMProviderError.invalidResponse
        }
        return text
    }
}

// MARK: - Codable request/response shapes

private struct ClaudeRequestBody: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [ClaudeMessage]

    enum CodingKeys: String, CodingKey {
        case model, system, messages
        case maxTokens = "max_tokens"
    }
}

private struct ClaudeMessage: Encodable {
    let role: String
    let content: String
}

struct ClaudeResponseBody: Decodable {
    let content: [ClaudeContentBlock]

    struct ClaudeContentBlock: Decodable {
        let type: String
        let text: String
    }
}
