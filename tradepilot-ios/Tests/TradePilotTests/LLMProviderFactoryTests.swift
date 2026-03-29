import XCTest
@testable import TradePilot

final class LLMProviderFactoryTests: XCTestCase {

    private var keychain: KeychainManager!

    override func setUp() {
        super.setUp()
        keychain = KeychainManager()
        keychain.delete(service: KeychainManager.ServiceKey.claudeAPIKey)
    }

    override func tearDown() {
        keychain.delete(service: KeychainManager.ServiceKey.claudeAPIKey)
        super.tearDown()
    }

    // MARK: - Default provider

    func testDefaultProviderIsRuleBased() {
        // No Claude key, AppleFoundation not available on test host
        let provider = LLMProviderFactory.bestAvailable()
        XCTAssertEqual(provider.name, "RuleBasedAdvisor")
    }

    func testDefaultProviderIsAvailable() {
        let provider = LLMProviderFactory.bestAvailable()
        XCTAssertTrue(provider.isAvailable, "bestAvailable() must always return an available provider")
    }

    // MARK: - Priority: Claude API > AppleFoundation > RuleBased

    func testClaudeAPISelectedWhenKeyPresent() throws {
        try keychain.save(key: "sk-test-abc123", service: KeychainManager.ServiceKey.claudeAPIKey)
        let provider = LLMProviderFactory.bestAvailable()
        XCTAssertTrue(provider.name.contains("claude"), "Claude provider should be selected when key is present")
    }

    func testRuleBasedSelectedWhenClaudeKeyRemoved() throws {
        try keychain.save(key: "sk-test", service: KeychainManager.ServiceKey.claudeAPIKey)
        keychain.delete(service: KeychainManager.ServiceKey.claudeAPIKey)
        let provider = LLMProviderFactory.bestAvailable()
        XCTAssertEqual(provider.name, "RuleBasedAdvisor")
    }

    // MARK: - RuleBasedAdvisor protocol conformance

    func testRuleBasedAdvisorIsAlwaysAvailable() {
        let advisor = RuleBasedAdvisor()
        XCTAssertTrue(advisor.isAvailable)
    }

    func testRuleBasedAdvisorCanAnalyze() async throws {
        let advisor = RuleBasedAdvisor()
        let result = try await advisor.analyze(prompt: "AAPL: LongCall (score: 0.80)")
        XCTAssertFalse(result.isEmpty, "RuleBasedAdvisor should return non-empty analysis")
    }

    // MARK: - AppleFoundationProvider

    func testAppleFoundationUnavailableBeforeiOS26() {
        let provider = AppleFoundationProvider()
        // Test hosts run macOS or iOS < 26
        if #available(iOS 26, *) {
            // On future devices this may be true; skip assertion
        } else {
            XCTAssertFalse(provider.isAvailable)
        }
    }

    func testAppleFoundationFallsBackToRuleBased() async throws {
        let provider = AppleFoundationProvider()
        // Whether or not device supports iOS 26, analyze() should not throw
        // (either runs on-device or falls back to RuleBasedAdvisor)
        let result = try await provider.analyze(prompt: "AAPL: LongCall")
        XCTAssertFalse(result.isEmpty)
    }
}
