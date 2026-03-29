import Foundation

// MARK: - Review result

struct AdvisorReview {
    let isCoherent: Bool
    let warnings: [String]
    let finalCandidates: [ScoredCandidate]
}

// MARK: - Sector mapping (simplified)

private let sectorMap: [String: String] = [
    "AAPL": "tech", "MSFT": "tech", "NVDA": "tech", "GOOG": "tech", "META": "tech",
    "AMZN": "consumer", "TSLA": "consumer", "WMT": "consumer",
    "JPM": "finance", "BAC": "finance", "GS": "finance",
    "XOM": "energy", "CVX": "energy",
    "JNJ": "healthcare", "PFE": "healthcare",
    "SPY": "index", "QQQ": "index"
]

// MARK: - Advisor

/// Step 5 — Rule-based portfolio coherence review.
struct ExpertAdvisor {
    private static let maxSameSector = 2

    /// Review a set of selected candidates for portfolio-level coherence.
    func review(_ candidates: [ScoredCandidate]) -> AdvisorReview {
        var warnings: [String] = []
        var filtered = candidates

        // Rule 1: No contradictory directional trades on the same ticker
        filtered = removeContradictions(filtered, warnings: &warnings)

        // Rule 2: Max 2 trades in the same sector
        filtered = enforceMaxSameSector(filtered, warnings: &warnings)

        // Rule 3: Flag if all 4 slots have the same direction
        checkRegimeAlignment(filtered, warnings: &warnings)

        return AdvisorReview(
            isCoherent: warnings.isEmpty,
            warnings: warnings,
            finalCandidates: filtered
        )
    }

    // MARK: Private

    private func removeContradictions(
        _ candidates: [ScoredCandidate],
        warnings: inout [String]
    ) -> [ScoredCandidate] {
        var seen: [String: StrategyType] = [:]
        var result: [ScoredCandidate] = []

        for candidate in candidates {
            let ticker = candidate.features.ticker
            if let existing = seen[ticker] {
                // Contradictory = one bullish, one bearish on same ticker
                if isContradictory(existing, candidate.strategyType) {
                    let msg = "Contradictory trades on \(ticker): \(existing.displayName) vs \(candidate.strategyType.displayName). Keeping higher-scored."
                    warnings.append(msg)
                    // Keep whichever scored higher (already sorted descending)
                    continue
                }
            } else {
                seen[ticker] = candidate.strategyType
            }
            result.append(candidate)
        }
        return result
    }

    private func enforceMaxSameSector(
        _ candidates: [ScoredCandidate],
        warnings: inout [String]
    ) -> [ScoredCandidate] {
        var sectorCounts: [String: Int] = [:]
        var result: [ScoredCandidate] = []

        for candidate in candidates {
            let sector = sectorMap[candidate.features.ticker] ?? "other"
            let count  = sectorCounts[sector, default: 0]
            if count >= Self.maxSameSector {
                warnings.append("Dropping \(candidate.features.ticker): sector '\(sector)' already has \(count) trades.")
                continue
            }
            sectorCounts[sector] = count + 1
            result.append(candidate)
        }
        return result
    }

    private func checkRegimeAlignment(
        _ candidates: [ScoredCandidate],
        warnings: inout [String]
    ) {
        let bullish = candidates.filter { $0.strategyType == .longCall || $0.strategyType == .sellPut }.count
        let bearish = candidates.filter { $0.strategyType == .longPut  || $0.strategyType == .shortCall }.count

        if bullish == candidates.count {
            warnings.append("All trades are bullish — portfolio has no hedge exposure.")
        } else if bearish == candidates.count {
            warnings.append("All trades are bearish — consider whether the macro regime supports this.")
        }
    }

    private func isContradictory(_ lhs: StrategyType, _ rhs: StrategyType) -> Bool {
        let bullish: Set<StrategyType> = [.longCall, .sellPut]
        let bearish: Set<StrategyType> = [.longPut, .shortCall]
        return (bullish.contains(lhs) && bearish.contains(rhs))
            || (bearish.contains(lhs) && bullish.contains(rhs))
    }
}
