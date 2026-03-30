import XCTest
@testable import TradePilot

final class LLMProviderFactoryTests: XCTestCase {

    // MARK: - bestAvailable always returns something

    func testBestAvailableAlwaysReturnsProvider() {
        let provider = LLMProviderFactory.bestAvailable()
        XCTAssertTrue(provider.isAvailable)
        XCTAssertFalse(provider.name.isEmpty)
    }

    // MARK: - allAvailable has at least one entry (RuleBasedAdvisor)

    func testAllAvailableContainsAtLeastRuleBased() {
        let all = LLMProviderFactory.allAvailable()
        XCTAssertGreaterThanOrEqual(all.count, 1)
        let hasRuleBased = all.contains { $0 is RuleBasedAdvisor }
        XCTAssertTrue(hasRuleBased, "RuleBasedAdvisor should always be available")
    }

    // MARK: - RuleBased is last in priority (fallback)

    func testRuleBasedIsLowestPriority() {
        let all = LLMProviderFactory.allAvailable()
        guard all.count > 1 else { return } // Only rule-based available — trivially passes
        let last = all.last
        XCTAssertTrue(
            last is RuleBasedAdvisor,
            "RuleBasedAdvisor should be the last (lowest-priority) provider. Got: \(last?.name ?? "nil")"
        )
    }

    // MARK: - Llama is not available if model file is absent

    func testLlamaNotAvailableWithoutModelFile() {
        let llama = LlamaProvider()
        // In test environment, model file should not be present
        let modelExists = FileManager.default.fileExists(atPath: llama.modelPath.path)
        if !modelExists {
            let all = LLMProviderFactory.allAvailable()
            let hasLlama = all.contains { $0 is LlamaProvider }
            XCTAssertFalse(hasLlama, "Llama should not be in allAvailable() when model file is missing")
        }
    }

    // MARK: - Apple Foundation not available before iOS 26

    func testAppleFoundationNotAvailableBeforeiOS26() {
        let provider = AppleFoundationProvider()
        if #available(iOS 26, *) {
            XCTAssertTrue(provider.isAvailable)
        } else {
            XCTAssertFalse(provider.isAvailable)
        }
    }

    // MARK: - Factory returns RuleBased when no model/key

    func testBestAvailableIsFallbackWhenNothingElseConfigured() {
        // Clear Claude key
        _ = KeychainManager().delete(service: "claude_api_key")
        // Remove model file if present (shouldn't be in CI)
        let llama = LlamaProvider()
        if !FileManager.default.fileExists(atPath: llama.modelPath.path) {
            if #unavailable(iOS 26) {
                let best = LLMProviderFactory.bestAvailable()
                XCTAssertTrue(best is RuleBasedAdvisor,
                              "Expected RuleBasedAdvisor as fallback. Got: \(best.name)")
            }
        }
    }
}
