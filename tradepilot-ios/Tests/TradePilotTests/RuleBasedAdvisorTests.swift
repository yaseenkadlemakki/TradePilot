import XCTest
@testable import TradePilot

final class RuleBasedAdvisorTests: XCTestCase {

    private let advisor = RuleBasedAdvisor()

    // MARK: - isAvailable

    func testIsAlwaysAvailable() {
        XCTAssertTrue(advisor.isAvailable)
    }

    func testName() {
        XCTAssertEqual(advisor.name, "RuleBasedAdvisor")
    }

    // MARK: - Contradiction detection

    func testDetectsContradiction() async throws {
        // AAPL LongCall (bullish) + AAPL LongPut (bearish) = contradiction
        let prompt = """
        AAPL: LongCall (score: 0.80)
        AAPL: LongPut (score: 0.75)
        MSFT: LongCall (score: 0.70)
        """
        let result = try await advisor.analyze(prompt: prompt)
        XCTAssertTrue(result.contains("AAPL"), "Should mention contradicted ticker")
        XCTAssertTrue(
            result.lowercased().contains("contradict") || result.lowercased().contains("opposing"),
            "Should flag contradiction"
        )
    }

    func testNoContradictionCleanPortfolio() async throws {
        let prompt = """
        AAPL: LongCall (score: 0.80)
        MSFT: LongCall (score: 0.78)
        JPM: LongPut (score: 0.72)
        XOM: SellPut (score: 0.65)
        """
        let result = try await advisor.analyze(prompt: prompt)
        // Should not flag contradictions
        XCTAssertFalse(result.lowercased().contains("contradict"))
    }

    // MARK: - Sector concentration

    func testFlagsSectorConcentration() async throws {
        // Three tech stocks — exceeds max 2
        let prompt = """
        AAPL: LongCall (score: 0.90)
        MSFT: LongCall (score: 0.85)
        NVDA: LongCall (score: 0.80)
        XOM: LongPut (score: 0.70)
        """
        let result = try await advisor.analyze(prompt: prompt)
        XCTAssertTrue(
            result.lowercased().contains("tech") || result.lowercased().contains("sector"),
            "Should warn about tech concentration"
        )
    }

    func testAllowsTwoInSector() async throws {
        let prompt = """
        AAPL: LongCall (score: 0.90)
        MSFT: LongCall (score: 0.85)
        JPM: LongPut (score: 0.75)
        XOM: SellPut (score: 0.65)
        """
        let result = try await advisor.analyze(prompt: prompt)
        // Two tech, one finance, one energy — all within limits
        XCTAssertFalse(result.lowercased().contains("concentration") || result.lowercased().contains("exceeds"))
    }

    // MARK: - Regime alignment

    func testFlagsAllBullish() async throws {
        let prompt = """
        AAPL: LongCall (score: 0.90)
        MSFT: LongCall (score: 0.85)
        JPM: SellPut (score: 0.75)
        XOM: SellPut (score: 0.65)
        """
        let result = try await advisor.analyze(prompt: prompt)
        XCTAssertTrue(
            result.lowercased().contains("bullish") || result.lowercased().contains("hedge"),
            "Should warn about all-bullish portfolio"
        )
    }

    func testFlagsAllBearish() async throws {
        let prompt = """
        AAPL: LongPut (score: 0.90)
        MSFT: LongPut (score: 0.85)
        JPM: ShortCall (score: 0.75)
        XOM: LongPut (score: 0.65)
        """
        let result = try await advisor.analyze(prompt: prompt)
        XCTAssertTrue(
            result.lowercased().contains("bearish") || result.lowercased().contains("short"),
            "Should warn about all-bearish portfolio"
        )
    }

    // MARK: - Clean portfolio

    func testCleanPortfolioPassesAllChecks() async throws {
        let prompt = """
        AAPL: LongCall (score: 0.80)
        JPM: LongPut (score: 0.78)
        XOM: SellPut (score: 0.72)
        JNJ: LongCall (score: 0.65)
        """
        let result = try await advisor.analyze(prompt: prompt)
        XCTAssertTrue(result.contains("✓") || result.lowercased().contains("coherent") || result.lowercased().contains("proceed"))
    }
}
