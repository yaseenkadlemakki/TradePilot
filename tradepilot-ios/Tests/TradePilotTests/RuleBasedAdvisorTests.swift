import XCTest
@testable import TradePilot

final class RuleBasedAdvisorTests: XCTestCase {
    private let advisor = RuleBasedAdvisor()

    func testNameAndAvailability() {
        XCTAssertEqual(advisor.name, "RuleBased")
        XCTAssertTrue(advisor.isAvailable)
    }

    func testContradictionPromptReturnsWarning() async throws {
        let result = try await advisor.analyze(prompt: "Contradictory trades detected on AAPL")
        XCTAssertTrue(result.lowercased().contains("contradiction") || result.contains("⚠️"))
    }

    func testSectorConcentrationPromptReturnsWarning() async throws {
        let result = try await advisor.analyze(prompt: "Sector 'tech' already has 2 trades — concentration risk")
        XCTAssertTrue(result.lowercased().contains("sector") || result.contains("⚠️"))
    }

    func testAllBullishPromptReturnsWarning() async throws {
        let result = try await advisor.analyze(prompt: "All trades are bullish — no hedge exposure")
        XCTAssertTrue(result.lowercased().contains("bullish") || result.contains("⚠️"))
    }

    func testAllBearishPromptReturnsWarning() async throws {
        let result = try await advisor.analyze(prompt: "All trades are bearish — macro regime uncertain")
        XCTAssertTrue(result.lowercased().contains("bearish") || result.contains("⚠️"))
    }

    func testCleanPromptReturnsNoViolation() async throws {
        let result = try await advisor.analyze(prompt: "Portfolio is balanced with mixed directional exposure.")
        XCTAssertTrue(result.contains("✅") || result.lowercased().contains("no rule"))
    }
}
