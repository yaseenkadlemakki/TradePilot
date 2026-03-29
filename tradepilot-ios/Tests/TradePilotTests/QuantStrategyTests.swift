import XCTest
@testable import TradePilot

final class QuantStrategyTests: XCTestCase {
    private var strategy: QuantStrategy!

    override func setUp() {
        super.setUp()
        strategy = QuantStrategy()
    }

    // MARK: - Strategy assignment

    func testBullishSignalsYieldLongCall() {
        let f = makeFeatures(sentiment: 0.6, callPutRatio: 0.7, rsi: 55, bollingerPos: 0.5)
        XCTAssertEqual(strategy.assignStrategy(to: f), .longCall)
    }

    func testBearishSignalsYieldLongPut() {
        let f = makeFeatures(sentiment: -0.6, callPutRatio: 0.3, rsi: 50, bollingerPos: 0.4)
        XCTAssertEqual(strategy.assignStrategy(to: f), .longPut)
    }

    func testOverboughtRSIYieldsShortCall() {
        let f = makeFeatures(sentiment: 0.1, callPutRatio: 0.5, rsi: 75, bollingerPos: 0.5)
        XCTAssertEqual(strategy.assignStrategy(to: f), .shortCall)
    }

    func testHighBollingerYieldsShortCall() {
        let f = makeFeatures(sentiment: 0.1, callPutRatio: 0.5, rsi: 55, bollingerPos: 0.85)
        XCTAssertEqual(strategy.assignStrategy(to: f), .shortCall)
    }

    func testOversoldLowIVYieldsSellPut() {
        let f = makeFeatures(sentiment: 0.0, callPutRatio: 0.5, rsi: 35, bollingerPos: 0.3, ivRank: 0.3)
        XCTAssertEqual(strategy.assignStrategy(to: f), .sellPut)
    }

    func testNeutralDefaultsToLongCall() {
        // neutral sentiment ≥ 0 → default is longCall
        let f = makeFeatures(sentiment: 0.05, callPutRatio: 0.5, rsi: 52, bollingerPos: 0.5)
        XCTAssertEqual(strategy.assignStrategy(to: f), .longCall)
    }

    func testNeutralSlightlyBearishDefaultsToLongPut() {
        let f = makeFeatures(sentiment: -0.05, callPutRatio: 0.5, rsi: 52, bollingerPos: 0.5)
        XCTAssertEqual(strategy.assignStrategy(to: f), .longPut)
    }

    // MARK: - Composite score

    func testCompositeScoreRange() {
        let f = makeFeatures(sentiment: 0.5, callPutRatio: 0.65, rsi: 58, bollingerPos: 0.55)
        let score = strategy.compositeScore(for: f)
        XCTAssertGreaterThanOrEqual(score, 0)
        XCTAssertLessThanOrEqual(score, 1)
    }

    func testHigherQualityCandidateScoresHigher() {
        let good = makeFeatures(
            sentiment: 0.7, callPutRatio: 0.75, rsi: 60, bollingerPos: 0.55,
            openInterest: 5000, optionVolume: 800, spreadPct: 0.03
        )
        let poor = makeFeatures(
            sentiment: 0.1, callPutRatio: 0.52, rsi: 51, bollingerPos: 0.5,
            openInterest: 600, optionVolume: 110, spreadPct: 0.14
        )
        XCTAssertGreaterThan(strategy.compositeScore(for: good), strategy.compositeScore(for: poor))
    }

    // MARK: - Select candidates (one per slot)

    func testSelectCandidatesReturnsFourSlots() {
        let pool = makeFeaturePool()
        let selected = strategy.selectCandidates(from: pool)
        let strategies = Set(selected.map(\.strategyType))
        // Should have one candidate per unique strategy type in pool
        XCTAssertGreaterThanOrEqual(selected.count, 1)
        XCTAssertLessThanOrEqual(selected.count, 4)
        XCTAssertEqual(selected.count, strategies.count)
    }

    func testSelectCandidatesPicksHighestScoredPerSlot() {
        // Two LONG_CALL candidates — only the higher scored one should win the slot
        let stronger = makeFeatures(
            ticker: "AAPL", sentiment: 0.8, callPutRatio: 0.8,
            rsi: 58, bollingerPos: 0.55, openInterest: 8000, optionVolume: 1200
        )
        let weaker = makeFeatures(
            ticker: "MSFT", sentiment: 0.3, callPutRatio: 0.6,
            rsi: 55, bollingerPos: 0.5, openInterest: 1000, optionVolume: 200
        )
        let selected = strategy.selectCandidates(from: [stronger, weaker])
        // Only one LONG_CALL slot should be filled
        let callSlot = selected.filter { $0.strategyType == .longCall }
        XCTAssertEqual(callSlot.count, 1)
        XCTAssertEqual(callSlot.first?.features.ticker, "AAPL")
    }

    // MARK: - Helpers

    private func makeFeatures(
        ticker: String = "TEST",
        sentiment: Double = 0,
        callPutRatio: Double = 0.5,
        rsi: Double = 50,
        bollingerPos: Double = 0.5,
        ivRank: Double = 0.4,
        openInterest: Double = 2000,
        optionVolume: Double = 400,
        spreadPct: Double = 0.05,
        mentionVolume: Double = 0.3,
        unusualFlowScore: Double = 0.5,
        sentimentMomentum: Double = 0.1
    ) -> CandidateFeatures {
        CandidateFeatures(
            ticker: ticker,
            sentimentScore: sentiment,
            sentimentMomentum: sentimentMomentum,
            mentionVolume: mentionVolume,
            unusualFlowScore: unusualFlowScore,
            callPutRatio: callPutRatio,
            openInterestRank: min(openInterest / 10_000, 1),
            priceVsMA20: 0.01,
            priceVsMA50: 0.005,
            rsiValue: rsi,
            bollingerPosition: bollingerPos,
            impliedVolatilityRank: ivRank,
            daysToExpiration: 30,
            bidAskSpreadPct: spreadPct,
            openInterest: openInterest,
            optionVolume: optionVolume
        )
    }

    private func makeFeaturePool() -> [CandidateFeatures] {
        [
            makeFeatures(ticker: "AAPL", sentiment: 0.5, callPutRatio: 0.7,  rsi: 57, bollingerPos: 0.55),
            makeFeatures(ticker: "TSLA", sentiment: -0.5, callPutRatio: 0.3, rsi: 48, bollingerPos: 0.4),
            makeFeatures(ticker: "NVDA", sentiment: 0.2, callPutRatio: 0.5,  rsi: 72, bollingerPos: 0.5),
            makeFeatures(ticker: "META", sentiment: 0.0, callPutRatio: 0.5,  rsi: 38, bollingerPos: 0.3, ivRank: 0.3)
        ]
    }
}
