import XCTest
import SwiftData
@testable import TradePilot

@MainActor
final class SettingsViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

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

    func testDefaultRiskToleranceIsMedium() {
        let vm = SettingsViewModel()
        XCTAssertEqual(vm.riskTolerance, .medium)
    }

    func testSaveAndLoadRiskTolerance() async throws {
        let vm = SettingsViewModel()
        vm.riskTolerance = .high
        await vm.save(context: context)

        let vm2 = SettingsViewModel()
        vm2.loadPreferences(context: context)
        XCTAssertEqual(vm2.riskTolerance, .high)
    }

    func testValidationMessageSetAfterSave() async {
        let vm = SettingsViewModel()
        await vm.save(context: context)
        XCTAssertNotNil(vm.validationMessage)
        XCTAssertEqual(vm.validationMessage, "Settings saved.")
    }

    func testIsSavingResetsToFalseAfterSave() async {
        let vm = SettingsViewModel()
        await vm.save(context: context)
        XCTAssertFalse(vm.isSaving)
    }

    func testRiskToleranceDisplayNames() {
        XCTAssertEqual(RiskTolerance.low.displayName,    "Low")
        XCTAssertEqual(RiskTolerance.medium.displayName, "Medium")
        XCTAssertEqual(RiskTolerance.high.displayName,   "High")
    }

    func testRiskToleranceRawValues() {
        XCTAssertEqual(RiskTolerance.low.rawValue,    "low")
        XCTAssertEqual(RiskTolerance.medium.rawValue, "medium")
        XCTAssertEqual(RiskTolerance.high.rawValue,   "high")
    }
}
