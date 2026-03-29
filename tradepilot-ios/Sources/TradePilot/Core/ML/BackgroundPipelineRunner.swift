import Foundation
import BackgroundTasks
import UserNotifications

/// Schedules and handles daily 6 AM ET pipeline runs via `BGTaskScheduler`.
/// Register early in `AppDelegate.application(_:didFinishLaunchingWithOptions:)`.
final class BackgroundPipelineRunner: @unchecked Sendable {
    static let shared = BackgroundPipelineRunner()
    static let taskIdentifier = "com.tradepilot.pipeline.daily"

    private init() {}

    // MARK: - Registration

    /// Register the background task handler. Must be called before the app finishes launching.
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handlePipelineTask(task as! BGProcessingTask)
        }
    }

    // MARK: - Scheduling

    /// Schedule (or reschedule) the next daily run at 6 AM Eastern Time.
    func scheduleNextRun() {
        let request = BGProcessingTaskRequest(identifier: Self.taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower       = false
        request.earliestBeginDate           = nextSixAMEastern()

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Silently skip if background tasks are not supported (simulator, etc.)
        }
    }

    // MARK: - Task handler

    private func handlePipelineTask(_ task: BGProcessingTask) {
        // Reschedule before starting so the next run is always queued.
        scheduleNextRun()

        let orchestrator = PipelineOrchestrator()
        let work = Task {
            do {
                let review = try await orchestrator.run()
                await deliverNotification(for: review)
            } catch {
                await deliverErrorNotification(error: error)
            }
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            work.cancel()
            task.setTaskCompleted(success: false)
        }
    }

    // MARK: - Local notifications

    @MainActor
    private func deliverNotification(for review: AdvisorReview) async {
        let content = UNMutableNotificationContent()
        content.title = "TradePilot — Daily Report Ready"
        let count = review.finalCandidates.count
        let warningNote = review.warnings.isEmpty ? "" : " (\(review.warnings.count) warning\(review.warnings.count == 1 ? "" : "s"))"
        content.body  = "\(count) candidate\(count == 1 ? "" : "s") selected\(warningNote)."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content:    content,
            trigger:    nil   // deliver immediately
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    @MainActor
    private func deliverErrorNotification(error: Error) async {
        let content = UNMutableNotificationContent()
        content.title = "TradePilot — Pipeline Error"
        content.body  = error.localizedDescription
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content:    content,
            trigger:    nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Helpers

    /// Returns the next occurrence of 06:00 America/New_York.
    private func nextSixAMEastern() -> Date {
        var calendar  = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!

        var components        = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour       = 6
        components.minute     = 0
        components.second     = 0

        guard var next = calendar.date(from: components) else { return Date() }
        if next <= Date() {
            next = calendar.date(byAdding: .day, value: 1, to: next) ?? next
        }
        return next
    }
}
