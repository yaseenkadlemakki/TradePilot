import Foundation

// MARK: - LLM Provider Factory

/// Selects the best available LLMProvider at runtime.
///
/// Priority order:
/// 1. ClaudeAPIProvider — if a Claude API key is stored in Keychain
/// 2. AppleFoundationProvider — if device supports Apple Intelligence (iOS 26+)
/// 3. RuleBasedAdvisor — always available, no key or network required
final class LLMProviderFactory {

    /// Returns the highest-priority available provider.
    static func bestAvailable() -> LLMProvider {
        let claude = ClaudeAPIProvider()
        if claude.isAvailable { return claude }

        let apple = AppleFoundationProvider()
        if apple.isAvailable { return apple }

        return RuleBasedAdvisor()
    }
}
