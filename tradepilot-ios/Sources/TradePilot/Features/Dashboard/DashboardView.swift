import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    skeletonList
                case .loaded(let items):
                    loadedList(items)
                case .empty:
                    emptyState
                case .error(let message):
                    errorState(message)
                }
            }
            .navigationTitle("Today's Trades")
            .task { await viewModel.load(context: context) }
        }
    }

    // MARK: - Sub-views

    private var skeletonList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    TradeCardSkeleton()
                }
            }
            .padding()
        }
    }

    private func loadedList(_ items: [Recommendation]) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(items) { rec in
                    NavigationLink(value: rec) {
                        TradeCardView(recommendation: rec)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .refreshable { await viewModel.refresh(context: context) }
        .navigationDestination(for: Recommendation.self) { rec in
            TradeDetailView(recommendation: rec)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Trades Today",
            systemImage: "chart.xyaxis.line",
            description: Text("Pull down to refresh or run the pipeline.")
        )
        .refreshable { await viewModel.refresh(context: context) }
    }

    private func errorState(_ message: String) -> some View {
        ContentUnavailableView(
            "Something went wrong",
            systemImage: "exclamationmark.triangle",
            description: Text(message)
        )
    }
}
