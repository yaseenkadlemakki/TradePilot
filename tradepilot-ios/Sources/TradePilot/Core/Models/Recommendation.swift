import Foundation

/// Full recommendation output — mirrors the Python Recommendation schema exactly.
struct Recommendation: Codable, Identifiable, Hashable {
    let id: String
    let generatedAt: Date
    let ticker: String
    let companyName: String
    let strategyType: StrategyType
    let contract: OptionContract
    let rationale: Rationale
    let supportingSignals: [Signal]
    let riskAnalysis: RiskAnalysis
    let confidenceScore: Double        // 0.0 to 1.0
    let signalConfirmations: Int
    let sourceCitations: [SourceCitation]
    let disclaimer: String

    enum CodingKeys: String, CodingKey {
        case id
        case generatedAt         = "generated_at"
        case ticker
        case companyName         = "company_name"
        case strategyType        = "strategy_type"
        case contract
        case rationale
        case supportingSignals   = "supporting_signals"
        case riskAnalysis        = "risk_analysis"
        case confidenceScore     = "confidence_score"
        case signalConfirmations = "signal_confirmations"
        case sourceCitations     = "source_citations"
        case disclaimer
    }
}

struct Rationale: Codable, Hashable {
    let summary: String
    let detailed: String
}

struct SourceCitation: Codable, Hashable {
    let source: String
    let title: String
    let url: String?
    let publishedAt: Date?

    enum CodingKeys: String, CodingKey {
        case source, title, url
        case publishedAt = "published_at"
    }
}
