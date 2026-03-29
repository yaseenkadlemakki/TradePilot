import XCTest
@testable import TradePilot

final class LLMProviderFactoryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clear any persisted Claude API key so tests are deterministic.
        UserDefaults.standard.removeObject(forKey: ClaudeAPIProvider.userDefaultsKey)
    }

    func testReturnsRuleBasedWhenNoKeyAndNoAppleFoundation() {
        let provider = LLMProviderFactory.makeProvider(claudeAPIKey: nil)
        // On test target (pre-iOS 26, no key) we should fall back to RuleBased.
        // Accept either RuleBased or AppleFoundation depending on simulator OS.
        let acceptableNames = ["RuleBased", "AppleFoundation"]
        XCTAssertTrue(acceptableNames.contains(provider.name),
                      "Unexpected provider: \(provider.name)")
    }

    func testReturnsClaudeWhenKeyProvided() {
        let provider = LLMProviderFactory.makeProvider(claudeAPIKey: "sk-test-key")
        XCTAssertEqual(provider.name, "Claude")
    }

    func testSelectedProviderIsAvailable() {
        let provider = LLMProviderFactory.makeProvider(claudeAPIKey: nil)
        XCTAssertTrue(provider.isAvailable)
    }

    func testClaudeProviderPrioritisedOverRuleBased() {
        let provider = LLMProviderFactory.makeProvider(claudeAPIKey: "any-key")
        // Claude should win over all others when a key is supplied.
        XCTAssertEqual(provider.name, "Claude")
    }

    func testRuleBasedIsFallbackProvider() {
        let provider = RuleBasedAdvisor()
        XCTAssertTrue(provider.isAvailable)
        XCTAssertEqual(provider.name, "RuleBased")
    }
}
