import Foundation

/// Encapsulates raw text-to-score inference so it can be swapped from
/// keyword heuristics to a compiled Core ML model without changing callers.
struct SentimentModelManager {

    // MARK: - Keyword dictionaries (shared with SentimentScorer)

    static let bullishKeywords: [String: Double] = [
        "strong buy": 2.0, "buy": 1.0, "long": 1.0, "bull": 1.2, "bullish": 1.5,
        "breakout": 1.3, "moon": 0.8, "calls": 1.0, "upside": 1.2, "rally": 1.1,
        "positive": 0.7, "growth": 0.8, "upgrade": 1.5, "beat": 1.2, "record": 0.9
    ]

    static let bearishKeywords: [String: Double] = [
        "strong sell": 2.0, "sell": 1.0, "short": 1.0, "bear": 1.2, "bearish": 1.5,
        "breakdown": 1.3, "puts": 1.0, "downside": 1.2, "crash": 1.4, "dump": 1.1,
        "negative": 0.7, "decline": 0.8, "downgrade": 1.5, "miss": 1.2, "warning": 0.9
    ]

    /// Whether a compiled Core ML model is loaded (always `false` until integrated).
    var isUsingCoreML: Bool { false }

    // MARK: - Inference

    /// Return a raw sentiment score in [-1, +1] for a single lowercased text fragment.
    /// Delegates to keyword heuristics; replace body with Core ML inference when ready.
    func rawScore(text: String) -> Double {
        var bullScore = 0.0
        var bearScore = 0.0

        for (keyword, weight) in Self.bullishKeywords where text.contains(keyword) {
            bullScore += weight
        }
        for (keyword, weight) in Self.bearishKeywords where text.contains(keyword) {
            bearScore += weight
        }

        let total = bullScore + bearScore
        guard total > 0 else { return 0 }
        return (bullScore - bearScore) / total
    }
}
