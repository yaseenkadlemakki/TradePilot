import Foundation

/// 15-feature vector used by QuantStrategy to score and rank option candidates.
struct CandidateFeatures: Codable, Hashable {
    let ticker: String

    // Sentiment features
    let sentimentScore: Double          // -1.0 to +1.0
    let sentimentMomentum: Double       // change in sentiment score
    let mentionVolume: Double           // normalised log mention count

    // Options flow features
    let unusualFlowScore: Double        // 0.0 to 1.0
    let callPutRatio: Double
    let openInterestRank: Double        // 0.0 to 1.0 within universe

    // Technical features
    let priceVsMA20: Double             // (price - MA20) / MA20
    let priceVsMA50: Double
    let rsiValue: Double                // 0-100
    let bollingerPosition: Double       // position within bands 0-1

    // Options-specific features
    let impliedVolatilityRank: Double   // 0.0 to 1.0 vs 52-week range
    let daysToExpiration: Double        // target DTE
    let bidAskSpreadPct: Double         // (ask - bid) / mid
    let openInterest: Double            // raw OI for hard-reject filter

    // Liquidity
    let optionVolume: Double            // raw option volume

    enum CodingKeys: String, CodingKey {
        case ticker
        case sentimentScore       = "sentiment_score"
        case sentimentMomentum    = "sentiment_momentum"
        case mentionVolume        = "mention_volume"
        case unusualFlowScore     = "unusual_flow_score"
        case callPutRatio         = "call_put_ratio"
        case openInterestRank     = "open_interest_rank"
        case priceVsMA20          = "price_vs_ma20"
        case priceVsMA50          = "price_vs_ma50"
        case rsiValue             = "rsi_value"
        case bollingerPosition    = "bollinger_position"
        case impliedVolatilityRank = "implied_volatility_rank"
        case daysToExpiration     = "days_to_expiration"
        case bidAskSpreadPct      = "bid_ask_spread_pct"
        case openInterest         = "open_interest"
        case optionVolume         = "option_volume"
    }
}
