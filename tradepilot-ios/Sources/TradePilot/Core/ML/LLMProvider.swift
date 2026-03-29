import Foundation

// MARK: - Errors

/// Errors that can occur during LLM operations
enum LLMProviderError: Error, LocalizedError {
    case modelNotLoaded
    case inferenceFailure(String)
    case networkError(Error)
    case apiKeyMissing
    case timeout

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: return "LLM model is not loaded"
        case .inferenceFailure(let msg): return "Inference failed: \(msg)"
        case .networkError(let err): return "Network error: \(err.localizedDescription)"
        case .apiKeyMissing: return "API key is missing"
        case .timeout: return "LLM request timed out"
        }
    }
}

// MARK: - Protocol

/// Protocol for all LLM providers (local and cloud)
protocol LLMProvider: Sendable {
    var name: String { get }
    var isAvailable: Bool { get }
    func analyze(prompt: String) async throws -> String
}
