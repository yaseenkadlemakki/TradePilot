import Foundation

// MARK: - Errors

enum LLMProviderError: Error, LocalizedError {
    case notAvailable
    case notImplemented
    case requestFailed(statusCode: Int, body: String)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .notAvailable:                    return "LLM provider is not available."
        case .notImplemented:                  return "LLM provider is not yet implemented."
        case .requestFailed(let code, let b):  return "Request failed (\(code)): \(b)"
        case .decodingFailed:                  return "Failed to decode LLM response."
        }
    }
}

// MARK: - Protocol

/// Contract for any text-inference backend used by the pipeline.
protocol LLMProvider: Sendable {
    /// Human-readable provider name.
    var name: String { get }

    /// Whether the provider can be used in the current environment.
    var isAvailable: Bool { get }

    /// Send a free-form prompt and return the model's text reply.
    func analyze(prompt: String) async throws -> String
}
