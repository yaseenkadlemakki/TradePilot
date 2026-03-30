import XCTest
@testable import TradePilot

final class BackgroundPipelineTests: XCTestCase {

    private var etCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        return cal
    }()

    // MARK: - Trading day logic

    func testWeekdaysAreTradingDays() {
        // March 3–7 2025 is a full trading week (no holidays)
        let dates = makeDates([(2025, 3, 3), (2025, 3, 4), (2025, 3, 5), (2025, 3, 6), (2025, 3, 7)])
        for date in dates {
            XCTAssertTrue(
                BackgroundPipelineRunner.isTradingDay(date, calendar: etCalendar),
                "Expected \(date) to be a trading day"
            )
        }
    }

    func testWeekendsAreNotTradingDays() {
        let dates = makeDates([(2025, 3, 8), (2025, 3, 9)]) // Sat, Sun
        for date in dates {
            XCTAssertFalse(
                BackgroundPipelineRunner.isTradingDay(date, calendar: etCalendar),
                "Expected \(date) to be a non-trading day"
            )
        }
    }

    // MARK: - Holiday detection

    func testNewYearsDayIsHoliday() {
        let date = makeDate(2025, 1, 1)
        XCTAssertTrue(BackgroundPipelineRunner.isMarketHoliday(date, calendar: etCalendar))
    }

    func testChristmasIsHoliday() {
        let date = makeDate(2025, 12, 25)
        XCTAssertTrue(BackgroundPipelineRunner.isMarketHoliday(date, calendar: etCalendar))
    }

    func testJuneteenthIsHoliday() {
        let date = makeDate(2025, 6, 19)
        XCTAssertTrue(BackgroundPipelineRunner.isMarketHoliday(date, calendar: etCalendar))
    }

    func testIndependenceDayIsHoliday() {
        let date = makeDate(2025, 7, 4)
        XCTAssertTrue(BackgroundPipelineRunner.isMarketHoliday(date, calendar: etCalendar))
    }

    func testMLKDayIsHoliday() {
        // MLK Day 2025 = January 20
        let date = makeDate(2025, 1, 20)
        XCTAssertTrue(BackgroundPipelineRunner.isMarketHoliday(date, calendar: etCalendar))
    }

    func testPresidentsDayIsHoliday() {
        // Presidents Day 2025 = February 17
        let date = makeDate(2025, 2, 17)
        XCTAssertTrue(BackgroundPipelineRunner.isMarketHoliday(date, calendar: etCalendar))
    }

    func testMemorialDayIsHoliday() {
        // Memorial Day 2025 = May 26
        let date = makeDate(2025, 5, 26)
        XCTAssertTrue(BackgroundPipelineRunner.isMarketHoliday(date, calendar: etCalendar))
    }

    func testLaborDayIsHoliday() {
        // Labor Day 2025 = September 1
        let date = makeDate(2025, 9, 1)
        XCTAssertTrue(BackgroundPipelineRunner.isMarketHoliday(date, calendar: etCalendar))
    }

    func testThanksgivingIsHoliday() {
        // Thanksgiving 2025 = November 27
        let date = makeDate(2025, 11, 27)
        XCTAssertTrue(BackgroundPipelineRunner.isMarketHoliday(date, calendar: etCalendar))
    }

    func testGoodFridayIsHoliday() {
        // Good Friday 2025 = April 18
        let date = makeDate(2025, 4, 18)
        XCTAssertTrue(BackgroundPipelineRunner.isMarketHoliday(date, calendar: etCalendar))
    }

    func testRegularWednesdayIsNotHoliday() {
        let date = makeDate(2025, 3, 5)
        XCTAssertFalse(BackgroundPipelineRunner.isMarketHoliday(date, calendar: etCalendar))
    }

    // MARK: - Schedule calculation

    func testNextTradingDayIsInFuture() {
        let nextRun = BackgroundPipelineRunner.nextTradingDay6AMET()
        XCTAssertNotNil(nextRun)
        XCTAssertGreaterThan(nextRun!, Date())
    }

    func testNextTradingDayIsWeekday() {
        guard let nextRun = BackgroundPipelineRunner.nextTradingDay6AMET() else {
            XCTFail("nextTradingDay6AMET returned nil")
            return
        }
        let weekday = etCalendar.component(.weekday, from: nextRun)
        XCTAssertGreaterThanOrEqual(weekday, 2) // Mon
        XCTAssertLessThanOrEqual(weekday, 6)    // Fri
    }

    func testNextTradingDayIsAt6AMET() {
        guard let nextRun = BackgroundPipelineRunner.nextTradingDay6AMET() else { return }
        let hour = etCalendar.component(.hour, from: nextRun)
        XCTAssertEqual(hour, 6)
        let minute = etCalendar.component(.minute, from: nextRun)
        XCTAssertEqual(minute, 0)
    }

    func testSkipsHolidayToNextTradingDay() {
        // The day before Christmas (Dec 24, 2025 is a Wednesday but trading)
        // Set "now" to Dec 24, 2025 at 7 AM ET — next run should skip Dec 25 (Christmas)
        let dec24At7AM = makeDateTime(2025, 12, 24, hour: 7, minute: 0)
        let nextRun = BackgroundPipelineRunner.nextTradingDay6AMET(from: dec24At7AM)
        XCTAssertNotNil(nextRun)
        // Christmas is Dec 25 (holiday), so next trading day is Dec 26
        if let nextRun {
            let day = etCalendar.component(.day, from: nextRun)
            let month = etCalendar.component(.month, from: nextRun)
            XCTAssertEqual(month, 12)
            XCTAssertEqual(day, 26)
        }
    }

    // MARK: - Task identifier

    func testTaskIdentifierIsSet() {
        XCTAssertFalse(BackgroundPipelineRunner.taskIdentifier.isEmpty)
        XCTAssertTrue(BackgroundPipelineRunner.taskIdentifier.contains("tradepilot"))
    }

    // MARK: - Helpers

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = 12 // Noon to avoid timezone edge cases
        return etCalendar.date(from: comps)!
    }

    private func makeDateTime(_ year: Int, _ month: Int, _ day: Int, hour: Int, minute: Int) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = hour; comps.minute = minute
        return etCalendar.date(from: comps)!
    }

    private func makeDates(_ tuples: [(Int, Int, Int)]) -> [Date] {
        tuples.map { makeDate($0.0, $0.1, $0.2) }
    }
}
