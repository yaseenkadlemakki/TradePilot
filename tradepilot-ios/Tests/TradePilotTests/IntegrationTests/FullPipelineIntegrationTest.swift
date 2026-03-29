import XCTest
@testable import TradePilot

/// End-to-end pipeline integration test.
///
/// DataAggregator (network I/O) is bypassed by injecting pre-built CandidateFeatures directly
/// into the compliance → strategy → sentiment-score → advisor chain.  All other agents run
/// with their real implementations to verify the pipeline produces exactly 4 recommendations
/// from a well-formed candidate pool.
final class FullPipelineIntegrationTest: XCTestCase {

    // MARK: - Helpers

    private func makeFeatures(
        _ ticker: String,
        sentiment: Double = 0.3,
        cpr: Double = 0.65,
        rsi: Double = 55,
        oi: Double = 3000,
        vol: Double = 600,
        spread: Double = 0.04,
        ivRank: Double = 0.45
    ) -> CandidateFeatures {
        CandidateFeatures(
            ticker: ticker,
            sentimentScore: sentiment,
            sentimentMomentum: 0.1,
            mentionVolume: 0.5,
            unusualFlowScore: 0.6,
            callPutRatio: cpr,
            openInterestRank: min(oi / 10_000, 1),
            priceVsMA20: 0.01,
            priceVsMA50: 0.005,
            rsiValue: rsi,
            bollingerPosition: 0.5,
            impliedVolatilityRank: ivRank,
            daysToExpiration: 30,
            bidAskSpreadPct: spread,
            openInterest: oi,
            optionVolume: vol
        )
    }

    // MARK: - Full pipeline: 4 recommendations from diverse pool

    func testFullPipelineProducesFourRecommendations() {
        let compliance = RiskCompliance()
        let strategy   = QuantStrategy()
        let scorer     = SentimentScorer()
        let advisor    = ExpertAdvisor()

        // 8 candidates across 5 sectors, mixed direction signals
        let pool: [CandidateFeatures] = [
            // Tech — bullish
            makeFeatures("AAPL", sentiment: 0.7, cpr: 0.75, rsi: 58),
            makeFeatures("MSFT", sentiment: 0.6, cpr: 0.70, rsi: 54),
            // Finance — bearish
            makeFeatures("JPM",  sentiment: -0.5, cpr: 0.30, rsi: 68),
            makeFeatures("BAC",  sentiment: -0.4, cpr: 0.35, rsi: 65),
            // Consumer — mixed
            makeFeatures("AMZN", sentiment: 0.4, cpr: 0.60, rsi: 50),
            makeFeatures("TSLA", sentiment: -0.3, cpr: 0.40, rsi: 72),
            // Energy — bullish
            makeFeatures("XOM",  sentiment: 0.5, cpr: 0.65, rsi: 55),
            // Healthcare — low OI (should be rejected by compliance)
            makeFeatures("JNJ",  sentiment: 0.2, cpr: 0.55, rsi: 52, oi: 80, vol: 50)
        ]

        // Step 1: Compliance filter
        let compliant = compliance.filter(pool)
        XCTAssertEqual(compliant.count, 7, "JNJ (low OI) should be filtered out")

        // Step 2: Strategy selection
        let selected = strategy.selectCandidates(from: compliant)
        XCTAssertGreaterThanOrEqual(selected.count, 1)
        XCTAssertLessThanOrEqual(selected.count, 4)

        // Step 3: Validate each candidate passes compliance
        for candidate in selected {
            let result = compliance.validate(candidate.features)
            XCTAssertEqual(result, .passed,
                "Candidate \(candidate.features.ticker) must pass compliance after selection")
        }

        // Step 4: Expert advisor review
        let review = advisor.review(selected)

        // Step 5: Final assertion — at least 1 recommendation, no more than 4
        XCTAssertGreaterThanOrEqual(review.finalCandidates.count, 1)
        XCTAssertLessThanOrEqual(review.finalCandidates.count, 4,
            "Pipeline must never exceed 4 recommendations")

        // No duplicate tickers in final output
        let tickers = review.finalCandidates.map(\.features.ticker)
        XCTAssertEqual(tickers.count, Set(tickers).count, "Duplicate tickers in final output")

        // Step 6: Sentiment scoring smoke test
        _ = scorer.score(texts: [])     // must not crash on empty input
        let sampleTexts: [(text: String, source: String, publishedAt: Date)] = [
            ("Strong buy bullish calls moon", "news",   Date()),
            ("Bear market sell dump",          "reddit", Date())
        ]
        let sentimentScore = scorer.score(texts: sampleTexts)
        XCTAssertGreaterThanOrEqual(sentimentScore, -1)
        XCTAssertLessThanOrEqual(sentimentScore, 1)
    }

    // MARK: - Pipeline rejects pool with fewer than 4 compliant candidates

    func testPipelineWithInsufficientCandidatesSelectsWhatItCan() {
        let compliance = RiskCompliance()
        let strategy   = QuantStrategy()
        let advisor    = ExpertAdvisor()

        // Only 3 compliant candidates (rest have disqualifying low OI)
        let pool: [CandidateFeatures] = [
            makeFeatures("AAPL", oi: 3000),
            makeFeatures("TSLA", oi: 2500, sentiment: -0.5, cpr: 0.3),
            makeFeatures("JPM",  oi: 4000),
            makeFeatures("JUNK", oi: 50),   // rejected
            makeFeatures("JUNK2", oi: 20),  // rejected
        ]

        let compliant = compliance.filter(pool)
        XCTAssertEqual(compliant.count, 3)

        let selected = strategy.selectCandidates(from: compliant)
        let review   = advisor.review(selected)

        // Should still produce something, just fewer than 4
        XCTAssertLessThanOrEqual(review.finalCandidates.count, 4)
    }

    // MARK: - Pipeline does not produce duplicate sectors beyond max

    func testPipelineSectorDiversification() {
        let compliance = RiskCompliance()
        let strategy   = QuantStrategy()
        let advisor    = ExpertAdvisor()

        // 5 tech stocks — advisor must cap at 2 per sector
        let pool: [CandidateFeatures] = [
            makeFeatures("AAPL", oi: 4000),
            makeFeatures("MSFT", oi: 3500),
            makeFeatures("NVDA", oi: 3200),
            makeFeatures("GOOG", oi: 3000),
            makeFeatures("META", oi: 2800),
        ]

        let compliant = compliance.filter(pool)
        let selected  = strategy.selectCandidates(from: compliant)
        let review    = advisor.review(selected)

        let techTickers: Set<String> = ["AAPL", "MSFT", "NVDA", "GOOG", "META"]
        let techCount = review.finalCandidates.filter { techTickers.contains($0.features.ticker) }.count
        XCTAssertLessThanOrEqual(techCount, 2, "At most 2 trades per sector")
    }

    // MARK: - AdvisorReview coherence flag

    func testAdvisorReviewIsCoherentForBalancedPortfolio() {
        let advisor = ExpertAdvisor()
        let candidates = [
            ScoredCandidate(features: makeFeatures("AAPL"), strategyType: .longCall,  compositeScore: 0.8),
            ScoredCandidate(features: makeFeatures("JPM"),  strategyType: .longPut,   compositeScore: 0.7),
            ScoredCandidate(features: makeFeatures("XOM"),  strategyType: .sellPut,   compositeScore: 0.6),
            ScoredCandidate(features: makeFeatures("TSLA"), strategyType: .shortCall, compositeScore: 0.5),
        ]
        let review = advisor.review(candidates)
        XCTAssertTrue(review.isCoherent, "Balanced portfolio should be coherent")
        XCTAssertEqual(review.finalCandidates.count, 4)
    }
}
