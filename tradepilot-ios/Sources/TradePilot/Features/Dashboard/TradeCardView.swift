import SwiftUI

/// Card showing ticker, strategy badge, confidence, and one-line summary.
struct TradeCardView: View {
    let recommendation: Recommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(recommendation.ticker)
                        .font(.headline)
                    Text(recommendation.companyName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StrategyBadge(strategy: recommendation.strategyType)
            }

            Text(recommendation.rationale.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                contractLabel
                Spacer()
                ConfidenceIndicator(score: recommendation.confidenceScore)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var contractLabel: some View {
        let c = recommendation.contract
        return Text("\(c.action.rawValue) \(c.type.rawValue.uppercased()) $\(c.strike, specifier: "%.0f") • \(c.expiration)")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
    }
}
