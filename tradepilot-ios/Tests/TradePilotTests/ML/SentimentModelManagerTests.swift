import XCTest
@testable import TradePilot

final class SentimentModelManagerTests: XCTestCase {

    let manager = SentimentModelManager()

    // MARK: - Score range

    func testScoreIsWithinRange() {
        let texts = [
            "strong buy, massive breakout, bullish momentum",
            "strong sell, crash incoming, bearish reversal",
            "neutral news, no major catalysts",
            ""
        ]
        for text in texts {
            let score = manager.scoreSentiment(text: text)
            XCTAssertGreaterThanOrEqual(score, -1.0, "Score below -1 for: \(text)")
            XCTAssertLessThanOrEqual(score,   1.0, "Score above +1 for: \(text)")
        }
    }

    // MARK: - Keyword scoring direction

    func testBullishTextScoresPositive() {
        let score = manager.scoreSentiment(text: "strong buy signal, breakout, bullish upgrade")
        XCTAssertGreaterThan(score, 0, "Expected positive score for bullish text")
    }

    func testBearishTextScoresNegative() {
        let score = manager.scoreSentiment(text: "strong sell, crash, bearish breakdown")
        XCTAssertLessThan(score, 0, "Expected negative score for bearish text")
    }

    func testNeutralTextScoresNearZero() {
        let score = manager.scoreSentiment(text: "company announced a new office lease")
        XCTAssertEqual(score, 0, accuracy: 0.5, "Expected near-zero score for neutral text")
    }

    func testEmptyTextScoresZero() {
        let score = manager.scoreSentiment(text: "")
        XCTAssertEqual(score, 0.0)
    }

    // MARK: - Batch scoring

    func testBatchScoresReturnCorrectCount() {
        let texts = ["buy buy buy", "sell sell sell", "neutral"]
        let scores = manager.scoreSentiments(texts: texts)
        XCTAssertEqual(scores.count, texts.count)
    }

    func testBatchScoresMatchIndividualScores() {
        let texts = ["bullish breakout", "bearish crash", ""]
        let batch = manager.scoreSentiments(texts: texts)
        let individual = texts.map { manager.scoreSentiment(text: $0) }
        for (b, i) in zip(batch, individual) {
            XCTAssertEqual(b, i, accuracy: 0.0001)
        }
    }

    // MARK: - Core ML flag

    func testUsesCoreMLIsFalseByDefault() {
        XCTAssertFalse(manager.usesCoreML)
    }
}
