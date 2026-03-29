import Foundation

/// Stub for the iOS 26+ Foundation Models framework.
///
/// When iOS 26 ships:
/// 1. Import `FoundationModels`
/// 2. Fill in `analyze(prompt:)` with the real session call.
/// 3. The rest of the provider chain requires no changes.
struct AppleFoundationProvider: LLMProvider {

    let name = "Apple Foundation Models (iOS 26+)"

    var isAvailable: Bool {
        if #available(iOS 26, *) {
            return true
        }
        return false
    }

    func analyze(prompt: String) async throws -> String {
        if #available(iOS 26, *) {
            // TODO: replace with real FoundationModels session call
            // let session = LanguageModelSession()
            // return try await session.respond(to: prompt).text
            throw LLMProviderError.inferenceFailure("Apple Foundation Models implementation pending iOS 26 SDK.")
        }
        throw LLMProviderError.modelNotLoaded
    }
}
