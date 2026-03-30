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
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .voiceOverLabel("\(recommendation.ticker), \(recommendation.strategyType.displayName), confidence \(Int(recommendation.confidenceScore * 100)) percent", hint: "Double-tap to view trade details")
    }

    private var contractLabel: some View {
        let contract = recommendation.contract
        let strike = String(format: "%.0f", contract.strike)
        return Text("\(contract.action.rawValue) \(contract.type.rawValue.uppercased()) $\(strike) • \(contract.expiration)")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
    }
}
