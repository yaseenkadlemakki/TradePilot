import Foundation

/// Selects the best available `LLMProvider` at runtime.
/// Priority: Claude API > Apple Foundation Models > Rule-Based.
enum LLMProviderFactory {

    /// Return the highest-priority provider that reports itself as available.
    /// - Parameter claudeAPIKey: Optional override for the Claude API key
    ///   (falls back to `UserDefaults` if `nil`).
    static func makeProvider(claudeAPIKey: String? = nil) -> any LLMProvider {
        let claude = ClaudeAPIProvider(apiKey: claudeAPIKey)
        if claude.isAvailable { return claude }

        let apple = AppleFoundationProvider()
        if apple.isAvailable { return apple }

        return RuleBasedAdvisor()
    }
}
