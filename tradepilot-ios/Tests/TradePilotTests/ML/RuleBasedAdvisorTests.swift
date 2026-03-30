import XCTest
@testable import TradePilot

final class RuleBasedAdvisorTests: XCTestCase {

    let advisor = RuleBasedAdvisor()

    // MARK: - Availability

    func testIsAlwaysAvailable() {
        XCTAssertTrue(advisor.isAvailable)
    }

    func testNameIsSet() {
        XCTAssertFalse(advisor.name.isEmpty)
    }

    // MARK: - Contradiction detection

    func testDetectsContradictorySignalsForSameTicker() async throws {
        let prompt = "BUY AAPL calls, bullish on tech. Also SELL AAPL puts, bearish reversal expected."
        let result = try await advisor.analyze(prompt: prompt)
        XCTAssertTrue(
            result.lowercased().contains("contradict") || result.lowercased().contains("aapl"),
            "Expected contradiction warning for AAPL. Got: \(result)"
        )
    }

    func testNoContradictionForUnambiguousTrade() async throws {
        let prompt = "BUY MSFT calls. Strong earnings beat, upgrade to buy."
        let result = try await advisor.analyze(prompt: prompt)
        // Should report no contradictions (or no issues at all)
        XCTAssertFalse(
            result.lowercased().contains("contradict"),
            "Unexpected contradiction warning. Got: \(result)"
        )
    }

    // MARK: - Sector concentration

    func testFlagsSectorConcentration() async throws {
        let prompt = """
        Buy AAPL calls (tech). Buy MSFT calls (tech). Buy NVDA calls (tech).
        Buy GOOG calls (tech). Strong buy on semiconductor tech upgrade.
        """
        let result = try await advisor.analyze(prompt: prompt)
        XCTAssertTrue(
            result.lowercased().contains("tech") || result.lowercased().contains("sector"),
            "Expected sector concentration warning. Got: \(result)"
        )
    }

    func testNoSectorWarningForDiversifiedPortfolio() async throws {
        let prompt = "Buy AAPL calls (tech). Buy JPM puts (finance). Buy XOM calls (energy)."
        let result = try await advisor.analyze(prompt: prompt)
        // Should not warn about sector concentration (each sector appears once)
        XCTAssertFalse(
            result.lowercased().contains("concentration"),
            "Unexpected sector concentration warning. Got: \(result)"
        )
    }

    // MARK: - Market regime alignment

    func testFlagsAllBullishPortfolio() async throws {
        let prompt = "Buy AAPL call. Buy MSFT call. Long NVDA. Bullish on QQQ upside."
        let result = try await advisor.analyze(prompt: prompt)
        XCTAssertTrue(
            result.lowercased().contains("bullish") || result.lowercased().contains("hedge"),
            "Expected bullish-regime warning. Got: \(result)"
        )
    }

    func testFlagsAllBearishPortfolio() async throws {
        let prompt = "Sell AAPL. Short MSFT. Buy SPY put. Bearish downside on QQQ."
        let result = try await advisor.analyze(prompt: prompt)
        XCTAssertTrue(
            result.lowercased().contains("bearish") || result.lowercased().contains("short"),
            "Expected bearish-regime warning. Got: \(result)"
        )
    }

    func testCleanPortfolioReturnsNoIssues() async throws {
        let prompt = "No trades today — monitoring only."
        let result = try await advisor.analyze(prompt: prompt)
        XCTAssertTrue(
            result.contains("No issues") || result.contains("coherent"),
            "Expected no-issues response. Got: \(result)"
        )
    }
}
