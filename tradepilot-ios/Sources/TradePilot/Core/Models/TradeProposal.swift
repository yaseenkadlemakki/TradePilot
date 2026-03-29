import Foundation

/// A specific option contract and the signals that drive it.
struct TradeProposal: Codable, Hashable, Identifiable {
    let id: String
    let ticker: String
    let strategyType: StrategyType
    let contract: OptionContract
    let signals: [Signal]
    let riskAnalysis: RiskAnalysis
    let compositeScore: Double          // 0.0 to 1.0
    let features: CandidateFeatures

    enum CodingKeys: String, CodingKey {
        case id, ticker
        case strategyType    = "strategy_type"
        case contract, signals
        case riskAnalysis    = "risk_analysis"
        case compositeScore  = "composite_score"
        case features
    }
}

struct OptionContract: Codable, Hashable {
    let strike: Double
    let expiration: String             // ISO-8601 date
    let type: ContractType
    let action: ContractAction
    let bid: Double
    let ask: Double
    let lastPrice: Double
    let openInterest: Int
    let volume: Int

    var midPrice: Double { (bid + ask) / 2.0 }
    var spreadPct: Double { midPrice > 0 ? (ask - bid) / midPrice : 0 }

    enum CodingKeys: String, CodingKey {
        case strike, expiration, type, action
        case bid, ask
        case lastPrice    = "last_price"
        case openInterest = "open_interest"
        case volume
    }
}

enum ContractType: String, Codable, Hashable {
    case call
    case put
}

enum ContractAction: String, Codable, Hashable {
    case buy  = "BUY"
    case sell = "SELL"
}

struct Signal: Codable, Hashable {
    let source: String
    let description: String
    let strength: Double               // 0.0 to 1.0
    let category: SignalCategory
}

enum SignalCategory: String, Codable, Hashable {
    case sentiment
    case technical
    case flow
    case fundamental
}
