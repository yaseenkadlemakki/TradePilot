import XCTest
@testable import TradePilot

final class ModelTests: XCTestCase {
    private var encoder: JSONEncoder!
    private var decoder: JSONDecoder!

    override func setUp() {
        super.setUp()
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - StrategyType

    func testStrategyTypeRoundTrip() throws {
        for strategy in StrategyType.allCases {
            let data    = try encoder.encode(strategy)
            let decoded = try decoder.decode(StrategyType.self, from: data)
            XCTAssertEqual(decoded, strategy)
        }
    }

    func testStrategyTypeRawValues() {
        XCTAssertEqual(StrategyType.longCall.rawValue, "LONG_CALL")
        XCTAssertEqual(StrategyType.longPut.rawValue, "LONG_PUT")
        XCTAssertEqual(StrategyType.shortCall.rawValue, "SHORT_CALL")
        XCTAssertEqual(StrategyType.sellPut.rawValue, "SELL_PUT")
    }

    func testStrategyTypeDebitFlag() {
        XCTAssertTrue(StrategyType.longCall.isDebit)
        XCTAssertTrue(StrategyType.longPut.isDebit)
        XCTAssertFalse(StrategyType.shortCall.isDebit)
        XCTAssertFalse(StrategyType.sellPut.isDebit)
    }

    // MARK: - CandidateFeatures

    func testCandidateFeaturesRoundTrip() throws {
        let features = makeSampleFeatures()
        let data     = try encoder.encode(features)
        let decoded  = try decoder.decode(CandidateFeatures.self, from: data)
        XCTAssertEqual(decoded.ticker, features.ticker)
        XCTAssertEqual(decoded.sentimentScore, features.sentimentScore, accuracy: 1e-9)
        XCTAssertEqual(decoded.openInterest, features.openInterest, accuracy: 1e-9)
    }

    func testCandidateFeaturesCodingKeys() throws {
        let features = makeSampleFeatures()
        let data     = try encoder.encode(features)
        let json     = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNotNil(json["sentiment_score"])
        XCTAssertNotNil(json["mention_volume"])
        XCTAssertNotNil(json["open_interest"])
        XCTAssertNotNil(json["bid_ask_spread_pct"])
    }

    // MARK: - RiskAnalysis

    func testRiskAnalysisRoundTrip() throws {
        let risk    = makeSampleRiskAnalysis()
        let data    = try encoder.encode(risk)
        let decoded = try decoder.decode(RiskAnalysis.self, from: data)
        XCTAssertEqual(decoded.delta, risk.delta, accuracy: 1e-9)
        XCTAssertNil(decoded.maxProfit)
    }

    func testRiskAnalysisNilMaxProfit() throws {
        let risk = makeSampleRiskAnalysis()   // maxProfit is nil for credit spreads
        XCTAssertNil(risk.maxProfit)
        let data    = try encoder.encode(risk)
        let decoded = try decoder.decode(RiskAnalysis.self, from: data)
        XCTAssertNil(decoded.maxProfit)
    }

    // MARK: - SentimentReport

    func testSentimentReportRoundTrip() throws {
        let report  = makeSentimentReport()
        let data    = try encoder.encode(report)
        let decoded = try decoder.decode(SentimentReport.self, from: data)
        XCTAssertEqual(decoded.ticker, report.ticker)
        XCTAssertEqual(decoded.overallScore, report.overallScore, accuracy: 1e-9)
    }

    func testSentimentReportEmptyKeywords() throws {
        let report = makeSentimentReport()
        // Rebuild with empty keywords array
        let empty = SentimentReport(
            ticker: report.ticker, overallScore: report.overallScore,
            mentionVolume: report.mentionVolume, mentionMomentum: report.mentionMomentum,
            redditScore: report.redditScore, newsScore: report.newsScore,
            sourceCounts: report.sourceCounts, topKeywords: [],
            computedAt: report.computedAt
        )
        let data    = try encoder.encode(empty)
        let decoded = try decoder.decode(SentimentReport.self, from: data)
        XCTAssertTrue(decoded.topKeywords.isEmpty)
    }

    // MARK: - TradeProposal

    func testTradeProposalRoundTrip() throws {
        let proposal = makeSampleProposal()
        let data     = try encoder.encode(proposal)
        let decoded  = try decoder.decode(TradeProposal.self, from: data)
        XCTAssertEqual(decoded.id, proposal.id)
        XCTAssertEqual(decoded.ticker, proposal.ticker)
    }

    // MARK: - Recommendation

    func testRecommendationRoundTrip() throws {
        let rec     = makeSampleRecommendation()
        let data    = try encoder.encode(rec)
        let decoded = try decoder.decode(Recommendation.self, from: data)
        XCTAssertEqual(decoded.id, rec.id)
        XCTAssertEqual(decoded.ticker, rec.ticker)
        XCTAssertEqual(decoded.strategyType, rec.strategyType)
    }

    func testRecommendationCodingKeys() throws {
        let rec  = makeSampleRecommendation()
        let data = try encoder.encode(rec)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNotNil(json["generated_at"])
        XCTAssertNotNil(json["company_name"])
        XCTAssertNotNil(json["strategy_type"])
        XCTAssertNotNil(json["confidence_score"])
        XCTAssertNotNil(json["signal_confirmations"])
        XCTAssertNotNil(json["source_citations"])
    }

    func testRecommendationEmptyCitations() throws {
        let rec = makeSampleRecommendation()
        let empty = Recommendation(
            id: rec.id, generatedAt: rec.generatedAt, ticker: rec.ticker,
            companyName: rec.companyName, strategyType: rec.strategyType,
            contract: rec.contract, rationale: rec.rationale,
            supportingSignals: [], riskAnalysis: rec.riskAnalysis,
            confidenceScore: rec.confidenceScore, signalConfirmations: 0,
            sourceCitations: [], disclaimer: rec.disclaimer
        )
        let data    = try encoder.encode(empty)
        let decoded = try decoder.decode(Recommendation.self, from: data)
        XCTAssertTrue(decoded.sourceCitations.isEmpty)
        XCTAssertTrue(decoded.supportingSignals.isEmpty)
        XCTAssertEqual(decoded.signalConfirmations, 0)
    }

    // MARK: - Helpers

    func makeSampleFeatures(
        ticker: String = "AAPL",
        sentimentScore: Double = 0.4,
        openInterest: Double = 2500,
        optionVolume: Double = 500,
        bidAskSpreadPct: Double = 0.05,
        rsiValue: Double = 55,
        mentionVolume: Double = 0.3,
        unusualFlowScore: Double = 0.6
    ) -> CandidateFeatures {
        CandidateFeatures(
            ticker: ticker,
            sentimentScore: sentimentScore,
            sentimentMomentum: 0.1,
            mentionVolume: mentionVolume,
            unusualFlowScore: unusualFlowScore,
            callPutRatio: 0.7,
            openInterestRank: 0.6,
            priceVsMA20: 0.02,
            priceVsMA50: 0.01,
            rsiValue: rsiValue,
            bollingerPosition: 0.6,
            impliedVolatilityRank: 0.4,
            daysToExpiration: 30,
            bidAskSpreadPct: bidAskSpreadPct,
            openInterest: openInterest,
            optionVolume: optionVolume
        )
    }

    func makeSampleRiskAnalysis() -> RiskAnalysis {
        RiskAnalysis(
            maxProfit: nil,
            maxLoss: 150,
            breakEvenPrice: 185,
            probabilityOfProfit: 0.55,
            riskRewardRatio: 2.5,
            delta: 0.45, gamma: 0.02, theta: -0.05, vega: 0.12,
            impliedVolatility: 0.35,
            scenarioBullish: 300, scenarioBase: 50, scenarioBearish: -150
        )
    }

    func makeSentimentReport() -> SentimentReport {
        SentimentReport(
            ticker: "AAPL",
            overallScore: 0.3,
            mentionVolume: 150,
            mentionMomentum: 0.2,
            redditScore: 0.25,
            newsScore: 0.4,
            sourceCounts: SourceCounts(reddit: 80, news: 20),
            topKeywords: ["bullish", "calls", "breakout"],
            computedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    func makeSampleContract() -> OptionContract {
        OptionContract(
            strike: 190, expiration: "2025-03-21",
            type: .call, action: .buy,
            bid: 2.50, ask: 2.70, lastPrice: 2.60,
            openInterest: 3000, volume: 800
        )
    }

    func makeSampleProposal() -> TradeProposal {
        TradeProposal(
            id: UUID().uuidString, ticker: "AAPL",
            strategyType: .longCall,
            contract: makeSampleContract(),
            signals: [Signal(source: "Reddit", description: "Bullish momentum", strength: 0.7, category: .sentiment)],
            riskAnalysis: makeSampleRiskAnalysis(),
            compositeScore: 0.72,
            features: makeSampleFeatures()
        )
    }

    func makeSampleRecommendation() -> Recommendation {
        Recommendation(
            id: UUID().uuidString,
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            ticker: "AAPL",
            companyName: "Apple Inc.",
            strategyType: .longCall,
            contract: makeSampleContract(),
            rationale: Rationale(summary: "Strong bullish signals.", detailed: "Multiple indicators align."),
            supportingSignals: [
                Signal(source: "Polygon", description: "RSI breakout", strength: 0.8, category: .technical)
            ],
            riskAnalysis: makeSampleRiskAnalysis(),
            confidenceScore: 0.78,
            signalConfirmations: 3,
            sourceCitations: [
                SourceCitation(source: "Reuters", title: "AAPL beats earnings", url: nil, publishedAt: nil)
            ],
            disclaimer: "Not financial advice."
        )
    }
}
