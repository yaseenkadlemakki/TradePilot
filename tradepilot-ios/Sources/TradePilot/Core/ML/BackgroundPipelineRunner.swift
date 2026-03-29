import Foundation
import BackgroundTasks
#if canImport(UserNotifications)
import UserNotifications
#endif

// MARK: - Background Pipeline Runner

/// Registers and handles BGProcessingTask for daily pre-market pipeline runs.
///
/// Schedule: 6:00 AM Eastern Time on trading days (Mon–Fri, non-holiday).
/// On completion, saves results to LocalCache and posts a local notification.
final class BackgroundPipelineRunner {

    static let taskIdentifier = "com.tradepilot.dailypipeline"

    // MARK: - US Market Holidays (static list, update annually)

    /// Federal/NYSE holidays for 2025–2026 where markets are closed.
    private static let marketHolidays: Set<String> = [
        // 2025
        "2025-01-01", "2025-01-20", "2025-02-17", "2025-04-18",
        "2025-05-26", "2025-06-19", "2025-07-04", "2025-09-01",
        "2025-11-27", "2025-12-25",
        // 2026
        "2026-01-01", "2026-01-19", "2026-02-16", "2026-04-03",
        "2026-05-25", "2026-06-19", "2026-07-03", "2026-09-07",
        "2026-11-26", "2026-12-25"
    ]

    private static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "America/New_York")!
        return formatter
    }()

    // MARK: - Registration

    /// Call from `AppDelegate.application(_:didFinishLaunchingWithOptions:)`.
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let processingTask = task as? BGProcessingTask else { return }
            self?.handleBackgroundTask(processingTask)
        }
    }

    // MARK: - Scheduling

    /// Schedule the next pipeline run for 6:00 AM ET on the next trading day.
    func scheduleNextRun() {
        let request = BGProcessingTaskRequest(identifier: Self.taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = nextTradingDayAt6AM()

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Non-fatal: app will still run pipeline on foreground launch
            print("[BackgroundPipelineRunner] Failed to schedule: \(error)")
        }
    }

    // MARK: - Task handling

    func handleBackgroundTask(_ task: BGProcessingTask) {
        // Schedule next run immediately so the chain continues
        scheduleNextRun()

        let pipelineTask = Task {
            do {
                let orchestrator = PipelineOrchestrator()
                let review = try await orchestrator.run()
                postPipelineCompleteNotification(candidateCount: review.finalCandidates.count)
            } catch {
                print("[BackgroundPipelineRunner] Pipeline error: \(error)")
            }
        }

        task.expirationHandler = {
            pipelineTask.cancel()
            task.setTaskCompleted(success: false)
        }

        Task {
            await pipelineTask.value
            task.setTaskCompleted(success: true)
        }
    }

    // MARK: - Next trading day calculation

    /// Returns the next trading day's 6:00 AM ET as a Date in the user's local timezone.
    func nextTradingDayAt6AM() -> Date {
        let etZone = TimeZone(identifier: "America/New_York")!
        var etCalendar = Calendar(identifier: .gregorian)
        etCalendar.timeZone = etZone

        var candidate = Date()
        // Advance at least one day
        candidate = etCalendar.date(byAdding: .day, value: 1, to: candidate)!

        for _ in 0..<14 {
            if isTradingDay(candidate, calendar: etCalendar) {
                var components = etCalendar.dateComponents([.year, .month, .day], from: candidate)
                components.hour = 6
                components.minute = 0
                components.second = 0
                components.timeZone = etZone
                if let target = etCalendar.date(from: components) {
                    return target
                }
            }
            candidate = etCalendar.date(byAdding: .day, value: 1, to: candidate)!
        }

        // Fallback: 24 hours from now
        return Date(timeIntervalSinceNow: 86400)
    }

    /// Returns true if the date is a weekday and not a NYSE holiday.
    func isTradingDay(_ date: Date, calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        // Sunday = 1, Saturday = 7
        guard weekday >= 2 && weekday <= 6 else { return false }
        let dateString = Self.isoDateFormatter.string(from: date)
        return !Self.marketHolidays.contains(dateString)
    }

    // MARK: - Local notification

    private func postPipelineCompleteNotification(candidateCount: Int) {
#if canImport(UserNotifications)
        let content = UNMutableNotificationContent()
        content.title = "TradePilot"
        content.body = "Your \(candidateCount) daily TradePilot picks are ready."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "com.tradepilot.pipeline.complete",
            content: content,
            trigger: nil  // deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[BackgroundPipelineRunner] Notification error: \(error)")
            }
        }
#endif
    }
}
