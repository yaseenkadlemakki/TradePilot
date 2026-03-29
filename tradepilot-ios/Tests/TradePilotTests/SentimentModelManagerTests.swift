import XCTest
@testable import TradePilot

final class SentimentModelManagerTests: XCTestCase {

    private let manager = SentimentModelManager()

    // MARK: - Score range

    func testScoreIsWithinRange() {
        let texts = [
            "strong bullish breakout rally buy calls upside",
            "strong bearish crash dump puts downside sell",
            "neutral unrelated text about nothing financial"
        ]
        for text in texts {
            let score = manager.scoreSentiment(text: text)
            XCTAssertGreaterThanOrEqual(score, -1.0, "Score below -1.0 for: \(text)")
            XCTAssertLessThanOrEqual(score, 1.0, "Score above +1.0 for: \(text)")
        }
    }

    func testNeutralTextScoresZero() {
        let score = manager.scoreSentiment(text: "the company announced quarterly results")
        XCTAssertEqual(score, 0.0)
    }

    // MARK: - Keyword scoring accuracy

    func testBullishTextScoresPositive() {
        let score = manager.scoreSentiment(text: "strong buy upgrade beat record bullish breakout")
        XCTAssertGreaterThan(score, 0.0, "Bullish text should score > 0")
    }

    func testBearishTextScoresNegative() {
        let score = manager.scoreSentiment(text: "strong sell downgrade miss warning bearish breakdown crash")
        XCTAssertLessThan(score, 0.0, "Bearish text should score < 0")
    }

    func testMixedTextScoresNearZero() {
        // Roughly equal bull and bear signals
        let score = manager.scoreSentiment(text: "buy sell long short bull bear")
        XCTAssertLessThanOrEqual(abs(score), 0.5, "Mixed text should score near 0")
    }

    func testStrongBullishApproachesOne() {
        // Many high-weight bullish keywords
        let score = manager.scoreSentiment(text: "strong buy bullish upgrade beat breakout upside rally")
        XCTAssertGreaterThan(score, 0.5, "Strong bullish text should score well above 0")
    }

    func testStrongBearishApproachesNegativeOne() {
        let score = manager.scoreSentiment(text: "strong sell bearish downgrade miss breakdown downside crash dump")
        XCTAssertLessThan(score, -0.5, "Strong bearish text should score well below 0")
    }

    // MARK: - usesCoreML flag

    func testDefaultsToKeywordScoring() {
        XCTAssertFalse(manager.usesCoreML, "Should default to keyword scoring until Core ML model is bundled")
    }

    // MARK: - Case insensitivity

    func testCaseInsensitiveScoring() {
        let lower = manager.scoreSentiment(text: "bullish breakout buy")
        let upper = manager.scoreSentiment(text: "BULLISH BREAKOUT BUY")
        let mixed = manager.scoreSentiment(text: "Bullish Breakout Buy")
        XCTAssertEqual(lower, upper, accuracy: 0.001)
        XCTAssertEqual(lower, mixed, accuracy: 0.001)
    }

    // MARK: - Empty input

    func testEmptyTextScoresZero() {
        let score = manager.scoreSentiment(text: "")
        XCTAssertEqual(score, 0.0)
    }
}
