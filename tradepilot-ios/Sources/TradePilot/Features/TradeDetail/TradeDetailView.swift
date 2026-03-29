import SwiftUI

struct TradeDetailView: View {
    let recommendation: Recommendation
    @State private var viewModel: TradeDetailViewModel

    init(recommendation: Recommendation) {
        self.recommendation = recommendation
        _viewModel = State(initialValue: TradeDetailViewModel(recommendation: recommendation))
    }

    var body: some View {
        List {
            headerSection
            rationaleSection
            signalsSection
            riskSection
            greeksSection
            if !recommendation.sourceCitations.isEmpty {
                citationsSection
            }
            disclaimerSection
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .navigationTitle(recommendation.ticker)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            HStack {
                StrategyBadge(strategy: recommendation.strategyType)
                Spacer()
                ConfidenceIndicator(score: recommendation.confidenceScore)
            }
            contractRow
        }
    }

    private var contractRow: some View {
        let contract = recommendation.contract
        return VStack(alignment: .leading, spacing: 4) {
            Text("\(contract.action.rawValue) \(contract.type.rawValue.uppercased()) — Strike $\(contract.strike, specifier: "%.2f")")
                .font(.subheadline.weight(.medium))
            Text("Exp: \(contract.expiration)  •  Bid: $\(contract.bid, specifier: "%.2f")  Ask: $\(contract.ask, specifier: "%.2f")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("OI: \(contract.openInterest)  •  Vol: \(contract.volume)  •  Spread: \(contract.spreadPct * 100, specifier: "%.1f")%%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var rationaleSection: some View {
        Section(isExpanded: $viewModel.rationaleExpanded) {
            Text(recommendation.rationale.detailed)
                .font(.subheadline)
        } header: {
            sectionHeader("Rationale", systemImage: "text.alignleft")
        }
    }

    private var signalsSection: some View {
        Section(isExpanded: $viewModel.signalsExpanded) {
            ForEach(Array(recommendation.supportingSignals.enumerated()), id: \.offset) { _, signal in
                SignalRow(signal: signal)
            }
        } header: {
            sectionHeader("Signals (\(recommendation.supportingSignals.count))", systemImage: "antenna.radiowaves.left.and.right")
        }
    }

    private var riskSection: some View {
        let risk = recommendation.riskAnalysis
        return Section(isExpanded: $viewModel.riskExpanded) {
            metricRow("Max Loss", value: String(format: "$%.2f", risk.maxLoss))
            metricRow("Max Profit", value: risk.maxProfit.map { String(format: "$%.2f", $0) } ?? "Unlimited")
            metricRow("Break-even", value: String(format: "$%.2f", risk.breakEvenPrice))
            metricRow("Prob. of Profit", value: String(format: "%.1f%%", risk.probabilityOfProfit * 100))
            metricRow("Risk/Reward", value: String(format: "%.2fx", risk.riskRewardRatio))
            ScenarioBars(risk: risk)
        } header: {
            sectionHeader("Risk", systemImage: "shield")
        }
    }

    private var greeksSection: some View {
        let risk = recommendation.riskAnalysis
        return Section(isExpanded: $viewModel.greeksExpanded) {
            metricRow("Delta", value: String(format: "%.4f", risk.delta))
            metricRow("Gamma", value: String(format: "%.4f", risk.gamma))
            metricRow("Theta", value: String(format: "%.4f", risk.theta))
            metricRow("Vega", value: String(format: "%.4f", risk.vega))
            metricRow("IV", value: String(format: "%.1f%%", risk.impliedVolatility * 100))
        } header: {
            sectionHeader("Greeks", systemImage: "function")
        }
    }

    private var citationsSection: some View {
        Section(isExpanded: $viewModel.citationsExpanded) {
            ForEach(Array(recommendation.sourceCitations.enumerated()), id: \.offset) { _, cite in
                CitationRow(citation: cite)
            }
        } header: {
            sectionHeader("Sources (\(recommendation.sourceCitations.count))", systemImage: "link")
        }
    }

    private var disclaimerSection: some View {
        Section {
            Text(recommendation.disclaimer)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
    }

    private func metricRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(.subheadline)
    }
}

// MARK: - Supporting sub-views

private struct SignalRow: View {
    let signal: Signal

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(signal.source).font(.subheadline.weight(.medium))
                Spacer()
                Text(signal.category.rawValue.capitalized)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.15))
                    .clipShape(Capsule())
                Text("\(signal.strength * 100, specifier: "%.0f")%%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(signal.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct CitationRow: View {
    let citation: SourceCitation

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(citation.title).font(.subheadline)
            HStack {
                Text(citation.source).font(.caption).foregroundStyle(.secondary)
                if let published = citation.publishedAt {
                    Text("•").foregroundStyle(.secondary)
                    Text(published, style: .date).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct ScenarioBars: View {
    let risk: RiskAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("P&L Scenarios").font(.caption).foregroundStyle(.secondary)
            scenarioBar("Bullish", value: risk.scenarioBullish, color: .green)
            scenarioBar("Base", value: risk.scenarioBase, color: .blue)
            scenarioBar("Bearish", value: risk.scenarioBearish, color: .red)
        }
    }

    private func scenarioBar(_ label: String, value: Double, color: Color) -> some View {
        HStack {
            Text(label).font(.caption).frame(width: 52, alignment: .leading)
            Text("\(value >= 0 ? "+" : "")\(value, specifier: "%.0f")%%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(color)
        }
    }
}
