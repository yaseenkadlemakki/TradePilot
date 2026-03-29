import XCTest
@testable import TradePilot

final class PipelineTests: XCTestCase {

    // MARK: - SentimentScorer

    func testSentimentScorerBullishText() {
        let scorer = SentimentScorer()
        let texts: [(text: String, source: String, publishedAt: Date)] = [ // swiftlint:disable:this large_tuple
            ("Strong buy signal, calls are printing, bullish breakout", "news", Date()),
            ("Long AAPL, moon incoming, rally expected", "reddit", Date())
        ]
        let score = scorer.score(texts: texts)
        XCTAssertGreaterThan(score, 0)
    }

    func testSentimentScorerBearishText() {
        let scorer = SentimentScorer()
        let texts: [(text: String, source: String, publishedAt: Date)] = [ // swiftlint:disable:this large_tuple
            ("Bear market crash incoming, puts are printing", "news", Date()),
            ("Selling everything, bearish dump, strong sell", "reddit", Date())
        ]
        let score = scorer.score(texts: texts)
        XCTAssertLessThan(score, 0)
    }

    func testSentimentScorerNeutralText() {
        let scorer = SentimentScorer()
        let texts: [(text: String, source: String, publishedAt: Date)] = [ // swiftlint:disable:this large_tuple
            ("The company reported quarterly results today", "news", Date())
        ]
        let score = scorer.score(texts: texts)
        XCTAssertEqual(score, 0, accuracy: 0.01)
    }

    func testSentimentScorerEmptyInput() {
        let scorer = SentimentScorer()
        XCTAssertEqual(scorer.score(texts: []), 0)
    }

    func testSentimentScorerScoreRange() {
        let scorer = SentimentScorer()
        let texts: [(text: String, source: String, publishedAt: Date)] = [ // swiftlint:disable:this large_tuple
            ("buy buy buy buy buy buy calls moon bull bullish breakout rally positive growth upgrade beat record", "news", Date())
        ]
        let score = scorer.score(texts: texts)
        XCTAssertGreaterThanOrEqual(score, -1)
        XCTAssertLessThanOrEqual(score, 1)
    }

    func testSentimentScorerTimeDecayReducesOldPosts() {
        let scorer = SentimentScorer()
        let now    = Date()
        let old    = now.addingTimeInterval(-7 * 24 * 3600)  // 1 week ago

        // Anchor with a neutral post so the weighted average differs by decay
        let recentTexts: [(text: String, source: String, publishedAt: Date)] = [ // swiftlint:disable:this large_tuple
            ("Strong buy bullish calls moon", "reddit", now),
            ("quarterly results", "reddit", now)
        ]
        let oldTexts: [(text: String, source: String, publishedAt: Date)] = [ // swiftlint:disable:this large_tuple
            ("Strong buy bullish calls moon", "reddit", old),
            ("quarterly results", "reddit", now)
        ]

        let recentScore = scorer.score(texts: recentTexts, referenceDate: now)
        let oldScore    = scorer.score(texts: oldTexts,    referenceDate: now)
        XCTAssertGreaterThan(recentScore, oldScore)
    }

    func testSentimentScorerNewsTierOutweighsReddit() {
        let scorer = SentimentScorer()
        let now    = Date()

        // Same bullish text, news source vs reddit — anchor with neutral to reveal tier weighting
        let newsTexts: [(text: String, source: String, publishedAt: Date)] = [ // swiftlint:disable:this large_tuple
            ("Strong buy upgrade", "news", now),
            ("quarterly results", "reddit", now)
        ]
        let redditTexts: [(text: String, source: String, publishedAt: Date)] = [ // swiftlint:disable:this large_tuple
            ("Strong buy upgrade", "reddit", now),
            ("quarterly results", "news", now)
        ]

        let newsScore   = scorer.score(texts: newsTexts,   referenceDate: now)
        let redditScore = scorer.score(texts: redditTexts, referenceDate: now)
        XCTAssertGreaterThan(newsScore, redditScore)
    }

    // MARK: - ExpertAdvisor

    func testAdvisorPassesNonContradictoryPortfolio() {
        let advisor = ExpertAdvisor()
        let candidates = [
            ScoredCandidate(features: makeFeatures("AAPL"), strategyType: .longCall,  compositeScore: 0.8),
            ScoredCandidate(features: makeFeatures("TSLA"), strategyType: .longPut,   compositeScore: 0.7),
            ScoredCandidate(features: makeFeatures("NVDA"), strategyType: .shortCall, compositeScore: 0.6),
            ScoredCandidate(features: makeFeatures("JPM"),  strategyType: .sellPut,   compositeScore: 0.5)
        ]
        let review = advisor.review(candidates)
        XCTAssertEqual(review.finalCandidates.count, 4)
        XCTAssertTrue(review.warnings.isEmpty)
    }

    func testAdvisorRemovesContradictoryTrades() {
        let advisor = ExpertAdvisor()
        // Both AAPL — longCall (bullish) and longPut (bearish) = contradictory
        let candidates = [
            ScoredCandidate(features: makeFeatures("AAPL"), strategyType: .longCall, compositeScore: 0.9),
            ScoredCandidate(features: makeFeatures("AAPL"), strategyType: .longPut,  compositeScore: 0.5)
        ]
        let review = advisor.review(candidates)
        XCTAssertFalse(review.warnings.isEmpty)
        let aaplTrades = review.finalCandidates.filter { $0.features.ticker == "AAPL" }
        XCTAssertEqual(aaplTrades.count, 1)
    }

    func testAdvisorEnforcesMaxSameSector() {
        let advisor = ExpertAdvisor()
        // 3 tech stocks — only 2 should pass
        let candidates = [
            ScoredCandidate(features: makeFeatures("AAPL"), strategyType: .longCall,  compositeScore: 0.9),
            ScoredCandidate(features: makeFeatures("MSFT"), strategyType: .longPut,   compositeScore: 0.7),
            ScoredCandidate(features: makeFeatures("NVDA"), strategyType: .shortCall, compositeScore: 0.5)
        ]
        let review = advisor.review(candidates)
        let techTrades = review.finalCandidates.filter {
            ["AAPL", "MSFT", "NVDA", "GOOG", "META"].contains($0.features.ticker)
        }
        XCTAssertLessThanOrEqual(techTrades.count, 2)
    }

    func testAdvisorWarnsAllBullish() {
        let advisor = ExpertAdvisor()
        let candidates = [
            ScoredCandidate(features: makeFeatures("AAPL"), strategyType: .longCall, compositeScore: 0.8),
            ScoredCandidate(features: makeFeatures("JPM"),  strategyType: .sellPut,  compositeScore: 0.7)
        ]
        let review = advisor.review(candidates)
        XCTAssertFalse(review.warnings.isEmpty)
        XCTAssertTrue(review.warnings.joined().lowercased().contains("bullish"))
    }

    // MARK: - RiskCompliance + QuantStrategy integration

    func testPipelineFiltersAndSelectsCandidates() {
        let compliance = RiskCompliance()
        let strategy   = QuantStrategy()

        let pool: [CandidateFeatures] = [
            // Good bullish candidate
            makeFeatures("AAPL", oi: 3000, vol: 600, spread: 0.05, sentiment: 0.6, cpr: 0.7, rsi: 55),
            // Low OI — should be rejected
            makeFeatures("JUNK", oi: 100, vol: 200, spread: 0.05, sentiment: 0.5, cpr: 0.6, rsi: 55),
            // Good bearish candidate
            makeFeatures("TSLA", oi: 2500, vol: 400, spread: 0.06, sentiment: -0.5, cpr: 0.3, rsi: 48),
            // Good overbought candidate
            makeFeatures("NVDA", oi: 4000, vol: 700, spread: 0.04, sentiment: 0.2, cpr: 0.5, rsi: 75)
        ]

        let filtered  = compliance.filter(pool)
        XCTAssertEqual(filtered.count, 3)   // JUNK rejected

        let selected  = strategy.selectCandidates(from: filtered)
        XCTAssertGreaterThan(selected.count, 0)
        XCTAssertLessThanOrEqual(selected.count, 4)
    }

    // MARK: - Helpers

    private func makeFeatures(
        _ ticker: String,
        oi: Double = 2000, vol: Double = 400, spread: Double = 0.05,
        sentiment: Double = 0.3, cpr: Double = 0.6, rsi: Double = 55
    ) -> CandidateFeatures {
        CandidateFeatures(
            ticker: ticker,
            sentimentScore: sentiment,
            sentimentMomentum: 0.1,
            mentionVolume: 0.4,
            unusualFlowScore: 0.5,
            callPutRatio: cpr,
            openInterestRank: min(oi / 10_000, 1),
            priceVsMA20: 0.01,
            priceVsMA50: 0.005,
            rsiValue: rsi,
            bollingerPosition: 0.5,
            impliedVolatilityRank: 0.4,
            daysToExpiration: 30,
            bidAskSpreadPct: spread,
            openInterest: oi,
            optionVolume: vol
        )
    }
}
