import Foundation

/// Default `LLMProvider` — always available, no network required.
/// Inspects the prompt for contradiction, concentration, and regime signals
/// and returns a structured plain-text analysis.
struct RuleBasedAdvisor: LLMProvider {
    var name: String    { "RuleBased" }
    var isAvailable: Bool { true }

    func analyze(prompt: String) async throws -> String {
        let lower = prompt.lowercased()
        var findings: [String] = []

        // Contradiction check
        if lower.contains("contradictory") || lower.contains("contradiction") {
            findings.append("⚠️ Contradiction detected: opposing directional trades on the same ticker increase gamma risk and should be resolved.")
        }

        // Concentration check
        if lower.contains("sector") && (lower.contains("already has") || lower.contains("concentration")) {
            findings.append("⚠️ Sector concentration: more than two positions in the same sector reduces diversification and amplifies sector-specific tail risk.")
        }

        // Regime alignment check
        if lower.contains("all trades are bullish") {
            findings.append("⚠️ Regime alignment: fully bullish book has no hedge exposure — consider adding a protective put or bearish spread if macro conditions are uncertain.")
        } else if lower.contains("all trades are bearish") {
            findings.append("⚠️ Regime alignment: fully bearish book may underperform in a risk-on rally — ensure the macro thesis supports a unidirectional short bias.")
        }

        if findings.isEmpty {
            findings.append("✅ No rule violations detected. Portfolio appears coherent.")
        }

        return findings.joined(separator: "\n")
    }
}
