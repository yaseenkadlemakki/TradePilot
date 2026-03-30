import SwiftUI
import SwiftData
import Observation

struct HistoryMetrics {
    let totalTrades: Int
    let avgConfidence: Double
    let strategyBreakdown: [StrategyType: Int]
}

@Observable
final class HistoryViewModel {
    var groupedHistory: [(date: String, items: [Recommendation])] = []
    var metrics: HistoryMetrics = HistoryMetrics(totalTrades: 0, avgConfidence: 0, strategyBreakdown: [:])
    var isLoading = false

    private let cache = LocalCache()
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    @MainActor
    func load(context: ModelContext) async {
        isLoading = true
        defer { isLoading = false }

        let end   = Date()
        let start = calendar.date(byAdding: .day, value: -30, to: end) ?? end
        let items = cache.fetchHistory(from: start, to: end, in: context)

        // Group by day
        let grouped = Dictionary(grouping: items) { rec in
            calendar.startOfDay(for: rec.generatedAt)
        }
        groupedHistory = grouped
            .sorted { $0.key > $1.key }
            .map { (date: dateFormatter.string(from: $0.key), items: $0.value) }

        // Compute metrics
        let total = items.count
        let avg   = total > 0 ? items.map(\.confidenceScore).reduce(0, +) / Double(total) : 0
        var breakdown: [StrategyType: Int] = [:]
        items.forEach { breakdown[$0.strategyType, default: 0] += 1 }
        metrics = HistoryMetrics(totalTrades: total, avgConfidence: avg, strategyBreakdown: breakdown)
    }
}
