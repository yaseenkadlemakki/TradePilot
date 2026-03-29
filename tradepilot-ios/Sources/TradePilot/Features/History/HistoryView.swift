import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel = HistoryViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading history…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.groupedHistory.isEmpty {
                    ContentUnavailableView(
                        "No History",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Recommendations from the last 30 days appear here.")
                    )
                } else {
                    List {
                        metricsHeader
                        ForEach(viewModel.groupedHistory, id: \.date) { group in
                            Section(group.date) {
                                ForEach(group.items) { rec in
                                    NavigationLink(value: rec) {
                                        HistoryRowView(recommendation: rec)
                                    }
                                }
                            }
                        }
                    }
                    #if os(iOS)
                    .listStyle(.insetGrouped)
                    #else
                    .listStyle(.inset)
                    #endif
                    .navigationDestination(for: Recommendation.self) { rec in
                        TradeDetailView(recommendation: rec)
                    }
                }
            }
            .navigationTitle("History")
            .task { await viewModel.load(context: context) }
            .refreshable { await viewModel.load(context: context) }
        }
    }

    // MARK: - Metrics header

    private var metricsHeader: some View {
        Section {
            HStack(spacing: 0) {
                metricCell(
                    title: "Trades",
                    value: "\(viewModel.metrics.totalTrades)"
                )
                Divider()
                metricCell(
                    title: "Avg Confidence",
                    value: String(format: "%.0f%%", viewModel.metrics.avgConfidence * 100)
                )
                Divider()
                metricCell(
                    title: "Top Strategy",
                    value: topStrategy
                )
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var topStrategy: String {
        viewModel.metrics.strategyBreakdown
            .max(by: { $0.value < $1.value })?
            .key.displayName ?? "—"
    }

    private func metricCell(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Row

private struct HistoryRowView: View {
    let recommendation: Recommendation

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(recommendation.ticker).font(.headline)
                Text(recommendation.rationale.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                StrategyBadge(strategy: recommendation.strategyType)
                ConfidenceIndicator(score: recommendation.confidenceScore)
            }
        }
    }
}
