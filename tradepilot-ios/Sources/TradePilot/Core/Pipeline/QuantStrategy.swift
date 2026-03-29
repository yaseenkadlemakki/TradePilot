import Foundation

// MARK: - Scored candidate

struct ScoredCandidate {
    let features: CandidateFeatures
    let strategyType: StrategyType
    let compositeScore: Double
}

// MARK: - Strategy selector

/// Step 3 — Assigns a strategy type to each candidate and selects one per slot via composite scoring.
///
/// Composite score = 0.30 × signal + 0.25 × risk_reward + 0.20 × liquidity + 0.15 × conviction + 0.10 × novelty
struct QuantStrategy {
    // Score component weights
    private static let wSignal     = 0.30
    private static let wRiskReward = 0.25
    private static let wLiquidity  = 0.20
    private static let wConviction = 0.15
    private static let wNovelty    = 0.10

    // Strategy thresholds (matching Python constants)
    private static let bullishThreshold: Double    =  0.2
    private static let bearishThreshold: Double    = -0.2
    private static let overboughtRSI: Double       =  65.0
    private static let oversoldRSI: Double         =  40.0
    private static let bollingerUpperZone: Double  =  0.8

    /// Select the best candidate for each of the four strategy slots.
    /// Returns up to 4 `ScoredCandidate` values, one per `StrategyType`.
    func selectCandidates(from features: [CandidateFeatures]) -> [ScoredCandidate] {
        var slotBest: [StrategyType: ScoredCandidate] = [:]

        for f in features {
            let strategy = assignStrategy(to: f)
            let score    = compositeScore(for: f)
            let candidate = ScoredCandidate(features: f, strategyType: strategy, compositeScore: score)

            if let existing = slotBest[strategy] {
                if score > existing.compositeScore {
                    slotBest[strategy] = candidate
                }
            } else {
                slotBest[strategy] = candidate
            }
        }

        return Array(slotBest.values).sorted { $0.compositeScore > $1.compositeScore }
    }

    // MARK: Private

    /// Determine strategy based on the feature vector's direction signals.
    func assignStrategy(to f: CandidateFeatures) -> StrategyType {
        let isOverbought  = f.rsiValue >= Self.overboughtRSI
                         || f.bollingerPosition >= Self.bollingerUpperZone
        let isSupported   = f.rsiValue <= Self.oversoldRSI
                         && f.impliedVolatilityRank < 0.5
        let isBullish     = f.sentimentScore >= Self.bullishThreshold
                         && f.callPutRatio > 0.55
        let isBearish     = f.sentimentScore <= Self.bearishThreshold
                         && f.callPutRatio < 0.45

        switch true {
        case isOverbought:         return .shortCall
        case isSupported:          return .sellPut
        case isBullish:            return .longCall
        case isBearish:            return .longPut
        default:                   return f.sentimentScore >= 0 ? .longCall : .longPut
        }
    }

    func compositeScore(for f: CandidateFeatures) -> Double {
        let signalComponent     = signalScore(f)
        let riskRewardComponent = riskRewardScore(f)
        let liquidityComponent  = liquidityScore(f)
        let convictionComponent = convictionScore(f)
        let noveltyComponent    = noveltyScore(f)

        return Self.wSignal     * signalComponent
             + Self.wRiskReward * riskRewardComponent
             + Self.wLiquidity  * liquidityComponent
             + Self.wConviction * convictionComponent
             + Self.wNovelty    * noveltyComponent
    }

    // Score sub-components (all normalised to 0–1)

    private func signalScore(_ f: CandidateFeatures) -> Double {
        let normalised = (f.sentimentScore + 1) / 2   // shift [-1,1] to [0,1]
        return (normalised + f.unusualFlowScore) / 2
    }

    private func riskRewardScore(_ f: CandidateFeatures) -> Double {
        // Lower spread = better risk/reward for the buyer
        return max(0, 1 - f.bidAskSpreadPct / 0.20)
    }

    private func liquidityScore(_ f: CandidateFeatures) -> Double {
        let oiNorm  = min(f.openInterest / 10_000, 1.0)
        let volNorm = min(f.optionVolume  / 1_000,  1.0)
        return (oiNorm + volNorm) / 2
    }

    private func convictionScore(_ f: CandidateFeatures) -> Double {
        return (f.mentionVolume + f.openInterestRank) / 2
    }

    private func noveltyScore(_ f: CandidateFeatures) -> Double {
        // Momentum signals indicate novelty
        return min(abs(f.sentimentMomentum) * 2, 1.0)
    }
}
