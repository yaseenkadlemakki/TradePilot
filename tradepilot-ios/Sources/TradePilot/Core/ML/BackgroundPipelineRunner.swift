import Foundation
#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

/// Schedules and runs the TradePilot pipeline in the background.
///
/// Registration: call `BackgroundPipelineRunner.registerTask()` from
/// `application(_:didFinishLaunchingWithOptions:)` / the App's `init`.
///
/// Info.plist must contain:
/// ```xml
/// <key>BGTaskSchedulerPermittedIdentifiers</key>
/// <array>
///     <string>com.tradepilot.dailypipeline</string>
/// </array>
/// ```
final class BackgroundPipelineRunner: Sendable {

    static let taskIdentifier = "com.tradepilot.dailypipeline"

    // MARK: Registration

    /// Register the background task handler. Call once at app launch.
    static func registerTask() {
        #if canImport(BackgroundTasks)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            guard let bgTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handle(task: bgTask)
        }
        #endif
    }

    // MARK: Scheduling

    /// Schedule the next pipeline run for 6:00 AM ET on the next trading day.
    static func scheduleNext() {
        #if canImport(BackgroundTasks)
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false

        if let nextRun = nextTradingDay6AMET() {
            request.earliestBeginDate = nextRun
        }

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Non-fatal — scheduling may fail in simulators or sandboxed environments.
        }
        #endif
    }

    // MARK: Execution

    #if canImport(BackgroundTasks)
    private static func handle(task: BGProcessingTask) {
        // Re-schedule immediately so the chain continues tomorrow.
        scheduleNext()

        // Guard against setTaskCompleted() being called more than once (fix #28).
        let completionLock = NSLock()
        var taskCompleted = false
        func completeTask(success: Bool) {
            completionLock.lock()
            defer { completionLock.unlock() }
            guard !taskCompleted else { return }
            taskCompleted = true
            task.setTaskCompleted(success: success)
        }

        let pipelineTask = Task {
            do {
                let orchestrator = PipelineOrchestrator()
                let proposals = try await orchestrator.run()
                try LocalCache.shared.saveProposals(proposals)
                postCompletionNotification(count: proposals.count)
            } catch {
                // Log error for debugging (fix #29).
                print("[BackgroundPipeline] Error: \(error)")
                UserDefaults.standard.set(
                    error.localizedDescription,
                    forKey: "BackgroundPipelineLastError"
                )
            }
        }

        task.expirationHandler = {
            pipelineTask.cancel()
            completeTask(success: false)
        }

        Task {
            await pipelineTask.value
            completeTask(success: true)
        }
    }
    #endif

    // MARK: Notifications

    private static func postCompletionNotification(count: Int) {
        let content = UNMutableNotificationContent()
        content.title = "TradePilot"
        content.body = count > 0
            ? "\(count) new trade proposal\(count == 1 ? "" : "s") ready for review."
            : "Daily scan complete — no new proposals today."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "dailypipeline-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    // MARK: Trading day calendar

    /// Returns the next weekday (Mon–Fri) that is not a major US market holiday,
    /// with the time component set to 06:00 ET.
    static func nextTradingDay6AMET(from now: Date = Date()) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        // ET = UTC-5 (EST) / UTC-4 (EDT) — use America/New_York
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .current

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour   = 6
        components.minute = 0
        components.second = 0

        guard var candidate = calendar.date(from: components) else { return nil }

        // If it's already past 6 AM ET today, start from tomorrow.
        if candidate <= now {
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }

        // Advance until we land on a trading day.
        for _ in 0..<14 { // Safety limit
            if isTradingDay(candidate, calendar: calendar) { return candidate }
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return nil
    }

    /// Returns `true` if `date` is a weekday and not a major US market holiday.
    static func isTradingDay(_ date: Date, calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        // 1 = Sunday, 7 = Saturday
        guard weekday >= 2 && weekday <= 6 else { return false }
        return !isMarketHoliday(date, calendar: calendar)
    }

    /// Hardcoded major US market holidays (fixed-date and computed).
    /// Covers: New Year's Day, MLK Day, Presidents Day, Good Friday,
    /// Memorial Day, Juneteenth, Independence Day, Labor Day,
    /// Thanksgiving, Christmas.
    static func isMarketHoliday(_ date: Date, calendar: Calendar) -> Bool {
        let year  = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day   = calendar.component(.day, from: date)

        // Fixed holidays (observed Monday if Sunday, Friday if Saturday handled by isTradingDay)
        let fixed: [(Int, Int)] = [
            (1,  1),  // New Year's Day
            (6,  19), // Juneteenth
            (7,  4),  // Independence Day
            (12, 25)  // Christmas
        ]
        if fixed.contains(where: { $0 == month && $1 == day }) { return true }

        // MLK Day — 3rd Monday of January
        if month == 1, let mlk = nthWeekday(2, nth: 3, of: 1, year: year, calendar: calendar) {
            if calendar.isDate(date, inSameDayAs: mlk) { return true }
        }
        // Presidents Day — 3rd Monday of February
        if month == 2, let pres = nthWeekday(2, nth: 3, of: 2, year: year, calendar: calendar) {
            if calendar.isDate(date, inSameDayAs: pres) { return true }
        }
        // Good Friday — 2 days before Easter
        if let goodFriday = goodFriday(year: year, calendar: calendar),
           calendar.isDate(date, inSameDayAs: goodFriday) { return true }
        // Memorial Day — last Monday of May
        if month == 5, let mem = lastWeekday(2, of: 5, year: year, calendar: calendar) {
            if calendar.isDate(date, inSameDayAs: mem) { return true }
        }
        // Labor Day — 1st Monday of September
        if month == 9, let labor = nthWeekday(2, nth: 1, of: 9, year: year, calendar: calendar) {
            if calendar.isDate(date, inSameDayAs: labor) { return true }
        }
        // Thanksgiving — 4th Thursday of November
        if month == 11, let turkey = nthWeekday(5, nth: 4, of: 11, year: year, calendar: calendar) {
            if calendar.isDate(date, inSameDayAs: turkey) { return true }
        }
        return false
    }

    // MARK: Date helpers

    private static func nthWeekday(
        _ weekday: Int, nth: Int, of month: Int, year: Int, calendar: Calendar
    ) -> Date? {
        var components = DateComponents(year: year, month: month, day: 1)
        guard let firstDay = calendar.date(from: components) else { return nil }
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        var offset = weekday - firstWeekday
        if offset < 0 { offset += 7 }
        offset += (nth - 1) * 7
        components.day = 1 + offset
        return calendar.date(from: components)
    }

    private static func lastWeekday(_ weekday: Int, of month: Int, year: Int, calendar: Calendar) -> Date? {
        // Start from last day of month and walk backwards
        var components = DateComponents(year: year, month: month + 1, day: 0) // day 0 = last day of month
        guard let lastDay = calendar.date(from: components) else { return nil }
        let lastWeekdayVal = calendar.component(.weekday, from: lastDay)
        var offset = lastWeekdayVal - weekday
        if offset < 0 { offset += 7 }
        return calendar.date(byAdding: .day, value: -offset, to: lastDay)
    }

    /// Anonymous Gregorian Easter algorithm (Butcher's algorithm).
    private static func easterDate(year: Int, calendar: Calendar) -> Date? {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day   = ((h + l - 7 * m + 114) % 31) + 1
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    private static func goodFriday(year: Int, calendar: Calendar) -> Date? {
        guard let easter = easterDate(year: year, calendar: calendar) else { return nil }
        return calendar.date(byAdding: .day, value: -2, to: easter)
    }
}

// MARK: - UserNotifications import

import UserNotifications
