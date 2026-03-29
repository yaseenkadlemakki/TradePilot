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

        for feature in features {
            let strategy = assignStrategy(to: feature)
            let score    = compositeScore(for: feature)
            let candidate = ScoredCandidate(features: feature, strategyType: strategy, compositeScore: score)

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
    func assignStrategy(to features: CandidateFeatures) -> StrategyType {
        let isOverbought  = features.rsiValue >= Self.overboughtRSI
                         || features.bollingerPosition >= Self.bollingerUpperZone
        let isSupported   = features.rsiValue <= Self.oversoldRSI
                         && features.impliedVolatilityRank < 0.5
        let isBullish     = features.sentimentScore >= Self.bullishThreshold
                         && features.callPutRatio > 0.55
        let isBearish     = features.sentimentScore <= Self.bearishThreshold
                         && features.callPutRatio < 0.45

        switch true {
        case isOverbought:         return .shortCall
        case isSupported:          return .sellPut
        case isBullish:            return .longCall
        case isBearish:            return .longPut
        default:                   return features.sentimentScore >= 0 ? .longCall : .longPut
        }
    }

    func compositeScore(for features: CandidateFeatures) -> Double {
        let signalComponent     = signalScore(features)
        let riskRewardComponent = riskRewardScore(features)
        let liquidityComponent  = liquidityScore(features)
        let convictionComponent = convictionScore(features)
        let noveltyComponent    = noveltyScore(features)

        return Self.wSignal     * signalComponent
             + Self.wRiskReward * riskRewardComponent
             + Self.wLiquidity  * liquidityComponent
             + Self.wConviction * convictionComponent
             + Self.wNovelty    * noveltyComponent
    }

    // Score sub-components (all normalised to 0–1)

    private func signalScore(_ features: CandidateFeatures) -> Double {
        let normalised = (features.sentimentScore + 1) / 2   // shift [-1,1] to [0,1]
        return (normalised + features.unusualFlowScore) / 2
    }

    private func riskRewardScore(_ features: CandidateFeatures) -> Double {
        // Lower spread = better risk/reward for the buyer
        return max(0, 1 - features.bidAskSpreadPct / 0.20)
    }

    private func liquidityScore(_ features: CandidateFeatures) -> Double {
        let oiNorm  = min(features.openInterest / 10_000, 1.0)
        let volNorm = min(features.optionVolume / 1_000, 1.0)
        return (oiNorm + volNorm) / 2
    }

    private func convictionScore(_ features: CandidateFeatures) -> Double {
        return (features.mentionVolume + features.openInterestRank) / 2
    }

    private func noveltyScore(_ features: CandidateFeatures) -> Double {
        // Momentum signals indicate novelty
        return min(abs(features.sentimentMomentum) * 2, 1.0)
    }
}
