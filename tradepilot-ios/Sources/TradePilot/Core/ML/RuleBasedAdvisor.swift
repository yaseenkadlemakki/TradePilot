import Foundation

/// Always-available fallback advisor.
/// No model download, no API key — just string analysis of trade proposals.
struct RuleBasedAdvisor: LLMProvider {

    let name = "Rule-Based Advisor (no model)"
    let isAvailable = true

    func analyze(prompt: String) async throws -> String {
        var findings: [String] = []

        findings += detectContradictoryTrades(in: prompt)
        findings += detectSectorConcentration(in: prompt)
        findings += checkMarketRegimeAlignment(in: prompt)

        if findings.isEmpty {
            return "Rule-based analysis: No issues detected. Portfolio appears coherent."
        }
        return "Rule-based analysis findings:\n" + findings.map { "• \($0)" }.joined(separator: "\n")
    }

    // MARK: Private checks

    /// Detects patterns like "BUY AAPL … SELL AAPL" or "long TSLA … short TSLA".
    private func detectContradictoryTrades(in text: String) -> [String] {
        let lower = text.lowercased()
        var findings: [String] = []

        // Pairs that signal contradiction on the same line block
        let bullishMarkers = ["buy", "long", "call", "bullish"]
        let bearishMarkers = ["sell", "short", "put", "bearish"]

        // Extract tickers: uppercase 1–5 letter tokens
        let tickerPattern = try? NSRegularExpression(pattern: "\\b([A-Z]{1,5})\\b")
        let range = NSRange(text.startIndex..., in: text)
        let matches = tickerPattern?.matches(in: text, range: range) ?? []
        let tickers = Set(matches.compactMap { Range($0.range(at: 1), in: text).map { String(text[$0]) } })

        for ticker in tickers {
            let tickerLower = ticker.lowercased()
            // Find sentences/clauses mentioning this ticker
            let sentences = lower.components(separatedBy: CharacterSet(charactersIn: ".,;\n"))
                .filter { $0.contains(tickerLower) }
            var hasBullish = false
            var hasBearish = false
            for sentence in sentences {
                if bullishMarkers.contains(where: { sentence.contains($0) }) { hasBullish = true }
                if bearishMarkers.contains(where: { sentence.contains($0) }) { hasBearish = true }
            }
            if hasBullish && hasBearish {
                findings.append("Contradictory signals detected for \(ticker) (both bullish and bearish cues).")
            }
        }
        return findings
    }

    /// Warns if more than 2 mentions of the same sector keyword appear.
    private func detectSectorConcentration(in text: String) -> [String] {
        let lower = text.lowercased()
        var findings: [String] = []

        let sectors: [String: [String]] = [
            "tech":       ["aapl", "msft", "nvda", "goog", "meta", "tech", "semiconductor"],
            "finance":    ["jpm", "bac", "gs", "bank", "finance", "financial"],
            "energy":     ["xom", "cvx", "oil", "energy", "crude"],
            "healthcare": ["jnj", "pfe", "healthcare", "pharma", "biotech"],
            "consumer":   ["amzn", "tsla", "wmt", "retail", "consumer"]
        ]

        for (sector, keywords) in sectors {
            let count = keywords.filter { lower.contains($0) }.count
            if count > 2 {
                findings.append("Sector concentration: '\(sector)' has \(count) signals — consider trimming exposure.")
            }
        }
        return findings
    }

    /// Flags portfolios that are uniformly directional.
    private func checkMarketRegimeAlignment(in text: String) -> [String] {
        let lower = text.lowercased()
        let bullishCount = ["buy", "long", "call", "bullish", "upside"].filter { lower.contains($0) }.count
        let bearishCount = ["sell", "short", "put", "bearish", "downside"].filter { lower.contains($0) }.count
        var findings: [String] = []

        if bullishCount > 0 && bearishCount == 0 {
            findings.append("All signals are bullish — portfolio has no downside hedge.")
        } else if bearishCount > 0 && bullishCount == 0 {
            findings.append("All signals are bearish — verify macro regime supports fully-short book.")
        }
        return findings
    }
}
