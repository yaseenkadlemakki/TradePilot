import XCTest
import SwiftData
@testable import TradePilot

@MainActor
final class DashboardViewModelTests: XCTestCase {
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

    func testInitialStateIsLoading() {
        let vm = DashboardViewModel()
        guard case .loading = vm.state else {
            XCTFail("Expected .loading, got \(vm.state)")
            return
        }
    }

    func testLoadSetsEmptyWhenNoData() async throws {
        let vm = DashboardViewModel()
        await vm.load(context: context)
        guard case .empty = vm.state else {
            XCTFail("Expected .empty, got \(vm.state)")
            return
        }
    }

    func testLoadSetsLoadedWhenDataExists() async throws {
        let rec = makeRecommendation()
        try cache.save(rec, in: context)

        let vm = DashboardViewModel()
        await vm.load(context: context)

        guard case .loaded(let items) = vm.state else {
            XCTFail("Expected .loaded, got \(vm.state)")
            return
        }
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.id, rec.id)
    }

    func testRefreshUpdatesItems() async throws {
        let vm = DashboardViewModel()
        await vm.load(context: context)
        guard case .empty = vm.state else {
            XCTFail("Expected .empty before insert")
            return
        }

        try cache.save(makeRecommendation(), in: context)
        await vm.refresh(context: context)

        guard case .loaded(let items) = vm.state else {
            XCTFail("Expected .loaded after refresh")
            return
        }
        XCTAssertFalse(items.isEmpty)
    }

    // MARK: - Helpers

    private func makeRecommendation(id: String = UUID().uuidString) -> Recommendation {
        Recommendation(
            id: id,
            generatedAt: Date(),
            ticker: "AAPL",
            companyName: "Apple Inc.",
            strategyType: .longCall,
            contract: OptionContract(
                strike: 200, expiration: "2025-06-20", type: .call, action: .buy,
                bid: 3.0, ask: 3.5, lastPrice: 3.2, openInterest: 5000, volume: 800
            ),
            rationale: Rationale(summary: "Bullish setup", detailed: "Strong upside momentum."),
            supportingSignals: [],
            riskAnalysis: RiskAnalysis(
                maxProfit: 1000, maxLoss: 350, breakEvenPrice: 203.5,
                probabilityOfProfit: 0.55, riskRewardRatio: 2.8,
                delta: 0.42, gamma: 0.03, theta: -0.12, vega: 0.18,
                impliedVolatility: 0.32,
                scenarioBullish: 185, scenarioBase: 20, scenarioBearish: -100
            ),
            confidenceScore: 0.78,
            signalConfirmations: 4,
            sourceCitations: [],
            disclaimer: "Not financial advice."
        )
    }
}
