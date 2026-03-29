import Foundation

// MARK: - Result types

enum ComplianceResult {
    case passed
    case rejected(reason: String)
}

// MARK: - Hard-limit constants

private enum Limits {
    static let minOpenInterest: Double  = 500
    static let minVolume: Double        = 100
    static let maxSpreadPct: Double     = 0.15   // 15 %
    static let maxIVRank: Double        = 0.90   // avoid insanely expensive options
    static let pumpThresholdSentiment   = 0.90   // near-max sentiment is suspicious
    static let pumpThresholdMentions    = 0.95   // near-max mention volume
    static let minDTE: Double           = 7
    static let maxDTE: Double           = 60
}

// MARK: - Compliance validator

/// Step 4 — Applies hard rejection criteria; identical logic to the Python RiskCompliance agent.
struct RiskCompliance {

    /// Validate a single candidate. Returns `.passed` or `.rejected(reason:)`.
    func validate(_ features: CandidateFeatures) -> ComplianceResult {
        if features.openInterest < Limits.minOpenInterest {
            return .rejected(reason: "Open interest \(Int(features.openInterest)) < \(Int(Limits.minOpenInterest))")
        }
        if features.optionVolume < Limits.minVolume {
            return .rejected(reason: "Volume \(Int(features.optionVolume)) < \(Int(Limits.minVolume))")
        }
        if features.bidAskSpreadPct > Limits.maxSpreadPct {
            return .rejected(reason: "Bid-ask spread \(String(format: "%.1f%%", features.bidAskSpreadPct * 100)) > 15%")
        }
        if features.impliedVolatilityRank > Limits.maxIVRank {
            return .rejected(reason: "IV rank \(String(format: "%.0f%%", features.impliedVolatilityRank * 100)) > 90%")
        }
        if features.daysToExpiration < Limits.minDTE {
            return .rejected(reason: "DTE \(Int(features.daysToExpiration)) < \(Int(Limits.minDTE))")
        }
        if features.daysToExpiration > Limits.maxDTE {
            return .rejected(reason: "DTE \(Int(features.daysToExpiration)) > \(Int(Limits.maxDTE))")
        }
        if isPumpDetected(features) {
            return .rejected(reason: "Pump pattern detected — abnormally high sentiment and mention velocity")
        }
        return .passed
    }

    /// Filter a list down to only compliant candidates.
    func filter(_ candidates: [CandidateFeatures]) -> [CandidateFeatures] {
        candidates.filter { validate($0) == .passed }
    }

    // MARK: Private

    /// Pump heuristic: extreme sentiment AND extreme mention volume simultaneously.
    func isPumpDetected(_ f: CandidateFeatures) -> Bool {
        f.sentimentScore   >= Limits.pumpThresholdSentiment
        && f.mentionVolume >= Limits.pumpThresholdMentions
    }
}

extension ComplianceResult: Equatable {
    static func == (lhs: ComplianceResult, rhs: ComplianceResult) -> Bool {
        switch (lhs, rhs) {
        case (.passed, .passed):             return true
        case (.rejected(let a), .rejected(let b)): return a == b
        default:                             return false
        }
    }
}
