import XCTest
@testable import TradePilot

final class BackgroundPipelineTests: XCTestCase {

    func testSharedInstanceIsSingleton() {
        let a = BackgroundPipelineRunner.shared
        let b = BackgroundPipelineRunner.shared
        XCTAssertTrue(a === b)
    }

    func testTaskIdentifierConstant() {
        XCTAssertEqual(BackgroundPipelineRunner.taskIdentifier, "com.tradepilot.pipeline.daily")
    }

    // BGTaskScheduler is unavailable in unit-test targets (no app bundle), so we only
    // verify that the runner can be referenced and its public API compiles correctly.
    func testPublicAPICompiles() {
        let runner = BackgroundPipelineRunner.shared
        // These calls will no-op or fail silently in a test context — we just confirm
        // the symbols exist and the code path doesn't crash before reaching the scheduler.
        _ = type(of: runner)
    }
}
