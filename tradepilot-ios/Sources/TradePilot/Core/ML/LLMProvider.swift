import Foundation

// MARK: - LLM Provider Protocol

/// Abstraction over any LLM backend (cloud, on-device, rule-based).
protocol LLMProvider {
    /// Analyze a portfolio prompt and return structured text.
    func analyze(prompt: String) async throws -> String

    /// Whether this provider can be used (key present, device capable, etc.).
    var isAvailable: Bool { get }

    /// Human-readable name for debugging and logging.
    var name: String { get }
}

// MARK: - Provider errors

enum LLMProviderError: Error, LocalizedError {
    case unavailable(provider: String)
    case networkError(underlying: Error)
    case invalidResponse
    case timeout

    var errorDescription: String? {
        switch self {
        case .unavailable(let provider): return "\(provider) provider is not available."
        case .networkError(let underlying): return "Network error: \(underlying.localizedDescription)"
        case .invalidResponse:          return "LLM returned an unexpected response format."
        case .timeout:                  return "LLM request timed out."
        }
    }
}
