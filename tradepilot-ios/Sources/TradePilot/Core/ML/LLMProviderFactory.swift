import Foundation

/// Selects the best available LLM provider at runtime.
///
/// Priority order:
/// 1. Llama 3.2 3B (on-device, Metal) — if model file is downloaded
/// 2. Apple Foundation Models (iOS 26+) — if running on iOS 26 or later
/// 3. Claude API — if user has stored a key in the Keychain
/// 4. Rule-Based Advisor — always available, no model needed
enum LLMProviderFactory {

    /// Returns the highest-priority available provider.
    static func bestAvailable() -> LLMProvider {
        for provider in orderedProviders() where provider.isAvailable {
            return provider
        }
        // RuleBasedAdvisor.isAvailable is always true, so this is unreachable.
        return RuleBasedAdvisor()
    }

    /// Returns all providers that are currently available, in priority order.
    /// Useful for the Settings UI to show what is active vs inactive.
    static func allAvailable() -> [LLMProvider] {
        orderedProviders().filter(\.isAvailable)
    }

    // MARK: Private

    private static func orderedProviders() -> [LLMProvider] {
        [
            LlamaProvider(),
            AppleFoundationProvider(),
            ClaudeAPIProvider(),
            RuleBasedAdvisor()
        ]
    }
}
