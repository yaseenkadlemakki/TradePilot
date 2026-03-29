import SwiftUI

/// The four option strategy types TradePilot generates recommendations for.
enum StrategyType: String, Codable, Hashable, CaseIterable {
    case longCall  = "LONG_CALL"
    case longPut   = "LONG_PUT"
    case shortCall = "SHORT_CALL"
    case sellPut   = "SELL_PUT"

    var displayName: String {
        switch self {
        case .longCall:  return "Long Call"
        case .longPut:   return "Long Put"
        case .shortCall: return "Short Call"
        case .sellPut:   return "Sell Put"
        }
    }

    var directionLabel: String {
        switch self {
        case .longCall:  return "Bullish"
        case .longPut:   return "Bearish"
        case .shortCall: return "Overbought"
        case .sellPut:   return "Supported"
        }
    }

    /// SwiftUI color for badges and charts.
    var color: Color {
        switch self {
        case .longCall:  return .green
        case .longPut:   return .red
        case .shortCall: return .orange
        case .sellPut:   return .blue
        }
    }

    var isDebit: Bool {
        switch self {
        case .longCall, .longPut: return true
        case .shortCall, .sellPut: return false
        }
    }
}
