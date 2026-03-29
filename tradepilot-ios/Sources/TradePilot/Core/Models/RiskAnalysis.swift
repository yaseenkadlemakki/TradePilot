import Foundation

/// Greeks, P&L scenarios, and probability estimates for an option position.
struct RiskAnalysis: Codable, Hashable {
    let maxProfit: Double?
    let maxLoss: Double
    let breakEvenPrice: Double
    let probabilityOfProfit: Double
    let riskRewardRatio: Double

    // Greeks
    let delta: Double
    let gamma: Double
    let theta: Double
    let vega: Double
    let impliedVolatility: Double

    // P&L scenarios
    let scenarioBullish: Double
    let scenarioBase: Double
    let scenarioBearish: Double

    enum CodingKeys: String, CodingKey {
        case maxProfit             = "max_profit"
        case maxLoss               = "max_loss"
        case breakEvenPrice        = "break_even_price"
        case probabilityOfProfit   = "probability_of_profit"
        case riskRewardRatio       = "risk_reward_ratio"
        case delta, gamma, theta, vega
        case impliedVolatility     = "implied_volatility"
        case scenarioBullish       = "scenario_bullish"
        case scenarioBase          = "scenario_base"
        case scenarioBearish       = "scenario_bearish"
    }
}
