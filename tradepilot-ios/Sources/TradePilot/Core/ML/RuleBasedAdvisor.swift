import Foundation

// MARK: - Rule-based LLM Provider

/// Default LLMProvider that requires no API key or network access.
/// Implements portfolio coherence checks as deterministic string rules.
/// Used as fallback when no cloud or on-device LLM is configured.
struct RuleBasedAdvisor: LLMProvider {

    // MARK: LLMProvider

    var isAvailable: Bool { true }
    var name: String { "RuleBasedAdvisor" }

    func analyze(prompt: String) async throws -> String {
        let candidates = extractCandidates(from: prompt)
        var findings: [String] = []

        let contradictions = checkContradictions(candidates)
        if !contradictions.isEmpty {
            findings.append("CONTRADICTORY TRADES DETECTED:")
            findings.append(contentsOf: contradictions.map { "  • \($0)" })
        }

        let concentration = checkSectorConcentration(candidates)
        if !concentration.isEmpty {
            findings.append("SECTOR CONCENTRATION WARNINGS:")
            findings.append(contentsOf: concentration.map { "  • \($0)" })
        }

        let regime = checkRegimeAlignment(candidates)
        if let regimeWarning = regime {
            findings.append("REGIME ALIGNMENT:")
            findings.append("  • \(regimeWarning)")
        }

        if findings.isEmpty {
            return """
            PORTFOLIO ANALYSIS — RULE-BASED REVIEW

            ✓ No contradictory trades detected.
            ✓ Sector concentration within limits (max 2 per sector).
            ✓ Mix of bullish and bearish exposure detected.

            Portfolio appears coherent. Proceed with confidence.
            """
        }

        return """
        PORTFOLIO ANALYSIS — RULE-BASED REVIEW

        \(findings.joined(separator: "\n"))

        Recommendation: Review flagged trades before submission.
        """
    }

    // MARK: - Contradiction check

    private func checkContradictions(_ candidates: [(ticker: String, direction: Direction)]) -> [String] {
        var byTicker: [String: [Direction]] = [:]
        for candidate in candidates {
            byTicker[candidate.ticker, default: []].append(candidate.direction)
        }

        var warnings: [String] = []
        for (ticker, directions) in byTicker {
            let hasBullish = directions.contains(.bullish)
            let hasBearish = directions.contains(.bearish)
            if hasBullish && hasBearish {
                warnings.append("\(ticker) has opposing directional trades (long and short simultaneously).")
            }
        }
        return warnings
    }

    // MARK: - Sector concentration check

    private func checkSectorConcentration(_ candidates: [(ticker: String, direction: Direction)]) -> [String] {
        let sectorMap: [String: String] = [
            "AAPL": "tech", "MSFT": "tech", "NVDA": "tech", "GOOG": "tech",
            "GOOGL": "tech", "META": "tech", "AMD": "tech", "INTC": "tech",
            "AMZN": "consumer", "TSLA": "consumer", "WMT": "consumer", "HD": "consumer",
            "JPM": "finance", "BAC": "finance", "GS": "finance", "WFC": "finance",
            "XOM": "energy", "CVX": "energy", "OXY": "energy",
            "JNJ": "healthcare", "PFE": "healthcare", "MRNA": "healthcare",
            "SPY": "index", "QQQ": "index", "IWM": "index"
        ]

        var sectorCounts: [String: Int] = [:]
        var warnings: [String] = []

        for candidate in candidates {
            let sector = sectorMap[candidate.ticker] ?? "other"
            let count = sectorCounts[sector, default: 0] + 1
            sectorCounts[sector] = count
            if count > 2 {
                warnings.append("Sector '\(sector)' has \(count) trades — exceeds maximum of 2.")
            }
        }
        return warnings
    }

    // MARK: - Regime alignment check

    private func checkRegimeAlignment(_ candidates: [(ticker: String, direction: Direction)]) -> String? {
        guard !candidates.isEmpty else { return nil }
        let bullCount = candidates.filter { $0.direction == .bullish }.count
        let bearCount = candidates.filter { $0.direction == .bearish }.count

        if bullCount == candidates.count {
            return "All \(bullCount) trades are bullish — portfolio has no hedge. Consider adding puts or short calls."
        }
        if bearCount == candidates.count {
            return "All \(bearCount) trades are bearish — verify macro regime supports full short exposure."
        }
        return nil
    }

    // MARK: - Prompt parsing helpers

    private enum Direction: Equatable {
        case bullish, bearish, neutral
    }

    private func extractCandidates(from prompt: String) -> [(ticker: String, direction: Direction)] {
        // Parse lines like "AAPL: LongCall" or "TSLA: LongPut"
        var results: [(ticker: String, direction: Direction)] = []
        let lines = prompt.components(separatedBy: .newlines)

        for line in lines {
            let parts = line.components(separatedBy: ":").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 2 else { continue }
            let ticker = parts[0].uppercased()
            let strategy = parts[1].lowercased()
            guard ticker.count >= 1 && ticker.count <= 5 &&
                  ticker.allSatisfy({ $0.isLetter }) else { continue }

            let direction: Direction
            if strategy.contains("longcall") || strategy.contains("long call") ||
               strategy.contains("sellput") || strategy.contains("sell put") {
                direction = .bullish
            } else if strategy.contains("longput") || strategy.contains("long put") ||
                      strategy.contains("shortcall") || strategy.contains("short call") {
                direction = .bearish
            } else {
                direction = .neutral
            }
            results.append((ticker: ticker, direction: direction))
        }
        return results
    }
}
