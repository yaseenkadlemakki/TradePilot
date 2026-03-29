import XCTest
@testable import TradePilot

final class BackgroundPipelineTests: XCTestCase {

    private let runner = BackgroundPipelineRunner()
    private var etCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        return cal
    }()

    // MARK: - isTradingDay

    func testMondayIsTradingDay() {
        // 2026-03-30 is a Monday
        let monday = makeETDate(year: 2026, month: 3, day: 30)!
        XCTAssertTrue(runner.isTradingDay(monday, calendar: etCalendar))
    }

    func testFridayIsTradingDay() {
        // 2026-04-10 is a Friday (not a holiday)
        let friday = makeETDate(year: 2026, month: 4, day: 10)!
        XCTAssertTrue(runner.isTradingDay(friday, calendar: etCalendar))
    }

    func testSaturdayIsNotTradingDay() {
        // 2026-04-04 is a Saturday
        let saturday = makeETDate(year: 2026, month: 4, day: 4)!
        XCTAssertFalse(runner.isTradingDay(saturday, calendar: etCalendar))
    }

    func testSundayIsNotTradingDay() {
        // 2026-04-05 is a Sunday
        let sunday = makeETDate(year: 2026, month: 4, day: 5)!
        XCTAssertFalse(runner.isTradingDay(sunday, calendar: etCalendar))
    }

    func testChristmasIsNotTradingDay() {
        // 2025-12-25 — NYSE holiday
        let christmas = makeETDate(year: 2025, month: 12, day: 25)!
        XCTAssertFalse(runner.isTradingDay(christmas, calendar: etCalendar))
    }

    func testNewYearsIsNotTradingDay() {
        // 2026-01-01 — NYSE holiday
        let newYears = makeETDate(year: 2026, month: 1, day: 1)!
        XCTAssertFalse(runner.isTradingDay(newYears, calendar: etCalendar))
    }

    func testIndependenceDayIsNotTradingDay() {
        // 2025-07-04 — NYSE holiday
        let july4 = makeETDate(year: 2025, month: 7, day: 4)!
        XCTAssertFalse(runner.isTradingDay(july4, calendar: etCalendar))
    }

    // MARK: - nextTradingDayAt6AM

    func testNextTradingDayIsInFuture() {
        let next = runner.nextTradingDayAt6AM()
        XCTAssertGreaterThan(next, Date(), "Next trading day should be in the future")
    }

    func testNextTradingDayIsATradingDay() {
        let next = runner.nextTradingDayAt6AM()
        XCTAssertTrue(runner.isTradingDay(next, calendar: etCalendar), "Scheduled date should be a trading day")
    }

    func testNextTradingDaySkipsWeekend() {
        // If today were Friday 2026-04-03, next run should skip to Monday 2026-04-06
        let friday = makeETDate(year: 2026, month: 4, day: 3, hour: 15, minute: 0)!

        // nextTradingDayAt6AM() advances at least 1 day from now, so simulate by checking
        // that days after a Friday that are valid trading days are Mon–Fri
        var candidate = etCalendar.date(byAdding: .day, value: 1, to: friday)!
        for _ in 0..<10 {
            if runner.isTradingDay(candidate, calendar: etCalendar) {
                let weekday = etCalendar.component(.weekday, from: candidate)
                XCTAssertGreaterThanOrEqual(weekday, 2)
                XCTAssertLessThanOrEqual(weekday, 6)
                break
            }
            candidate = etCalendar.date(byAdding: .day, value: 1, to: candidate)!
        }
    }

    // MARK: - Task identifier

    func testTaskIdentifier() {
        XCTAssertEqual(BackgroundPipelineRunner.taskIdentifier, "com.tradepilot.dailypipeline")
    }

    // MARK: - Helpers

    private func makeETDate(year: Int, month: Int, day: Int, hour: Int = 12, minute: Int = 0) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = TimeZone(identifier: "America/New_York")
        return etCalendar.date(from: components)
    }
}
