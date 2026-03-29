import XCTest
@testable import TradePilot

final class SentimentModelManagerTests: XCTestCase {
    private let manager = SentimentModelManager()

    func testBullishTextReturnsPositiveScore() {
        let score = manager.rawScore(text: "strong buy bullish breakout calls")
        XCTAssertGreaterThan(score, 0)
    }

    func testBearishTextReturnsNegativeScore() {
        let score = manager.rawScore(text: "strong sell bearish crash puts")
        XCTAssertLessThan(score, 0)
    }

    func testNeutralTextReturnsZero() {
        let score = manager.rawScore(text: "the company reported quarterly earnings today")
        XCTAssertEqual(score, 0, accuracy: 0.001)
    }

    func testScoreIsClampedToMinusOneToOne() {
        let extreme = manager.rawScore(text: "buy buy buy bull bullish calls moon rally upgrade beat")
        XCTAssertGreaterThanOrEqual(extreme, -1.0)
        XCTAssertLessThanOrEqual(extreme, 1.0)
    }

    func testIsUsingCoreMLIsFalse() {
        XCTAssertFalse(manager.isUsingCoreML)
    }

    func testSentimentScorerDelegatesToModelManager() {
        // SentimentScorer should produce the same result when using default SentimentModelManager.
        let scorer = SentimentScorer()
        let texts: [(text: String, source: String, publishedAt: Date)] = [
            ("strong buy bullish calls", "news", Date())
        ]
        let score = scorer.score(texts: texts)
        XCTAssertGreaterThan(score, 0)
    }

    func testSentimentScorerWithCustomManager() {
        let customManager = SentimentModelManager()
        let scorer = SentimentScorer(modelManager: customManager)
        let texts: [(text: String, source: String, publishedAt: Date)] = [
            ("crash bearish dump puts", "reddit", Date())
        ]
        XCTAssertLessThan(scorer.score(texts: texts), 0)
    }
}
