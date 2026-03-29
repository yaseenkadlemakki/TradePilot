import Foundation

/// Stub `LLMProvider` for Apple's on-device Foundation Models framework.
/// Available on iOS 26+ only; `analyze` throws `notImplemented` until the
/// Foundation Models API is GA and integrated.
struct AppleFoundationProvider: LLMProvider {
    var name: String { "AppleFoundation" }

    var isAvailable: Bool {
        if #available(iOS 26, *) { return true }
        return false
    }

    func analyze(prompt: String) async throws -> String {
        guard isAvailable else { throw LLMProviderError.notAvailable }
        // TODO: replace with FoundationModels.LanguageModelSession when iOS 26 SDK ships.
        throw LLMProviderError.notImplemented
    }
}
