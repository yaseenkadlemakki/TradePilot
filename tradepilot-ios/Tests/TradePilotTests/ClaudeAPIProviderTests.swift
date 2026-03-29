import XCTest
@testable import TradePilot

final class ClaudeAPIProviderTests: XCTestCase {

    func testNotAvailableWithoutKey() {
        let provider = ClaudeAPIProvider(apiKey: nil)
        // Ensure UserDefaults does not contain a stale key from a prior test run.
        UserDefaults.standard.removeObject(forKey: ClaudeAPIProvider.userDefaultsKey)
        // Reinitialise after clearing defaults.
        let fresh = ClaudeAPIProvider(apiKey: nil)
        XCTAssertFalse(fresh.isAvailable)
    }

    func testAvailableWithKey() {
        let provider = ClaudeAPIProvider(apiKey: "test-key-123")
        XCTAssertTrue(provider.isAvailable)
    }

    func testNameIsCorrect() {
        let provider = ClaudeAPIProvider(apiKey: "k")
        XCTAssertEqual(provider.name, "Claude")
    }

    func testAnalyzeThrowsWhenNoKey() async {
        UserDefaults.standard.removeObject(forKey: ClaudeAPIProvider.userDefaultsKey)
        let provider = ClaudeAPIProvider(apiKey: nil)
        do {
            _ = try await provider.analyze(prompt: "hello")
            XCTFail("Expected LLMProviderError.notAvailable")
        } catch LLMProviderError.notAvailable {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testUserDefaultsKeyConstant() {
        XCTAssertEqual(ClaudeAPIProvider.userDefaultsKey, "com.tradepilot.claude.apiKey")
    }
}
