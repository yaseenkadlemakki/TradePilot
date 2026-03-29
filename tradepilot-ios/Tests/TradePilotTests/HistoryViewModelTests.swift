import XCTest
import SwiftData
@testable import TradePilot

@MainActor
final class HistoryViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private let cache = LocalCache()

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: CachedRecommendation.self, UserPreference.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context   = nil
    }

    // MARK: - Tests

    func testLoadWithEmptyStoreProducesEmptyGroups() async {
        let vm = HistoryViewModel()
        await vm.load(context: context)
        XCTAssertTrue(vm.groupedHistory.isEmpty)
        XCTAssertEqual(vm.metrics.totalTrades, 0)
        XCTAssertEqual(vm.metrics.avgConfidence, 0)
    }

    func testLoadGroupsItemsByDay() async throws {
        let today     = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        try cache.save(makeRecommendation(date: today, ticker: "AAPL"), in: context)
        try cache.save(makeRecommendation(date: today, ticker: "TSLA"), in: context)
        try cache.save(makeRecommendation(date: yesterday, ticker: "NVDA"), in: context)

        let vm = HistoryViewModel()
        await vm.load(context: context)

        XCTAssertEqual(vm.groupedHistory.count, 2, "Should have 2 day groups")
        XCTAssertEqual(vm.metrics.totalTrades, 3)
    }

    func testMetricsAverageConfidence() async throws {
        try cache.save(makeRecommendation(confidence: 0.6), in: context)
        try cache.save(makeRecommendation(confidence: 0.8), in: context)

        let vm = HistoryViewModel()
        await vm.load(context: context)

        XCTAssertEqual(vm.metrics.avgConfidence, 0.7, accuracy: 0.001)
    }

    func testStrategyBreakdown() async throws {
        try cache.save(makeRecommendation(strategy: .longCall), in: context)
        try cache.save(makeRecommendation(strategy: .longCall), in: context)
        try cache.save(makeRecommendation(strategy: .longPut), in: context)

        let vm = HistoryViewModel()
        await vm.load(context: context)

        XCTAssertEqual(vm.metrics.strategyBreakdown[.longCall], 2)
        XCTAssertEqual(vm.metrics.strategyBreakdown[.longPut], 1)
    }

    // MARK: - Helpers

    private func makeRecommendation(
        date: Date = Date(),
        ticker: String = "AAPL",
        confidence: Double = 0.75,
        strategy: StrategyType = .longCall
    ) -> Recommendation {
        Recommendation(
            id: UUID().uuidString,
            generatedAt: date,
            ticker: ticker,
            companyName: "\(ticker) Corp",
            strategyType: strategy,
            contract: OptionContract(
                strike: 150, expiration: "2025-06-20", type: .call, action: .buy,
                bid: 2.0, ask: 2.5, lastPrice: 2.2, openInterest: 3000, volume: 500
            ),
            rationale: Rationale(summary: "Test", detailed: "Test rationale."),
            supportingSignals: [],
            riskAnalysis: RiskAnalysis(
                maxProfit: 500, maxLoss: 200, breakEvenPrice: 152,
                probabilityOfProfit: 0.55, riskRewardRatio: 2.5,
                delta: 0.45, gamma: 0.02, theta: -0.08, vega: 0.15,
                impliedVolatility: 0.28,
                scenarioBullish: 150, scenarioBase: 10, scenarioBearish: -100
            ),
            confidenceScore: confidence,
            signalConfirmations: 3,
            sourceCitations: [],
            disclaimer: "Not financial advice."
        )
    }
}
