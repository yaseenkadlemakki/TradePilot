import Foundation

// MARK: - Apple Foundation Models Provider

/// On-device LLM provider using the Apple Foundation Models framework (iOS 26+).
/// Stubs the availability check and delegates to RuleBasedAdvisor on unsupported devices.
struct AppleFoundationProvider: LLMProvider {

    private let fallback: RuleBasedAdvisor

    init(fallback: RuleBasedAdvisor = RuleBasedAdvisor()) {
        self.fallback = fallback
    }

    // MARK: LLMProvider

    var isAvailable: Bool {
        // Apple Foundation Models require iOS 26+.
        // FoundationModels.LanguageModelSession is checked via availability guard.
        if #available(iOS 26, *) {
            return _deviceSupportsOnDeviceLLM()
        }
        return false
    }

    var name: String { "AppleFoundationModels" }

    func analyze(prompt: String) async throws -> String {
        if #available(iOS 26, *), _deviceSupportsOnDeviceLLM() {
            return try await _runOnDeviceSession(prompt: prompt)
        }
        // Transparent fallback — caller can check isAvailable before calling
        return try await fallback.analyze(prompt: prompt)
    }

    // MARK: - iOS 26+ stubs

    /// Returns true when the device hardware supports Apple Intelligence.
    /// Replace with `LanguageModelSession.isSupported` once Foundation Models SDK lands.
    private func _deviceSupportsOnDeviceLLM() -> Bool {
        // TODO: Replace with FoundationModels.LanguageModelSession.isSupported
        // when iOS 26 SDK is available in Xcode.
        return false
    }

    /// Runs an on-device Foundation Models session.
    /// Replace body with real LanguageModelSession calls when SDK is available.
    @available(iOS 26, *)
    private func _runOnDeviceSession(prompt: String) async throws -> String {
        // TODO: Swap in FoundationModels implementation:
        //
        //   let session = LanguageModelSession()
        //   let response = try await session.respond(to: Prompt(prompt))
        //   return response.content
        //
        // One-line swap — the protocol boundary is already in place.
        throw LLMProviderError.unavailable(provider: name)
    }
}
