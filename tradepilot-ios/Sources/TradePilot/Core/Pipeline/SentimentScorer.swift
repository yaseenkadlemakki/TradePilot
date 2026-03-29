import Foundation

/// Step 2 — Refines raw sentiment using time-decay weighting and source tier multipliers.
/// Matches the Python SentimentScorer formula exactly.
struct SentimentScorer {
    // Source tier multipliers (higher = more trusted)
    private static let tierWeights: [String: Double] = [
        "news": 1.5,
        "reddit": 1.0
    ]

    // Time-decay half-life in hours
    private static let halfLifeHours: Double = 24

    // Keyword dictionaries with weights
    private static let bullishKeywords: [String: Double] = [
        "strong buy": 2.0, "buy": 1.0, "long": 1.0, "bull": 1.2, "bullish": 1.5,
        "breakout": 1.3, "moon": 0.8, "calls": 1.0, "upside": 1.2, "rally": 1.1,
        "positive": 0.7, "growth": 0.8, "upgrade": 1.5, "beat": 1.2, "record": 0.9
    ]

    private static let bearishKeywords: [String: Double] = [
        "strong sell": 2.0, "sell": 1.0, "short": 1.0, "bear": 1.2, "bearish": 1.5,
        "breakdown": 1.3, "puts": 1.0, "downside": 1.2, "crash": 1.4, "dump": 1.1,
        "negative": 0.7, "decline": 0.8, "downgrade": 1.5, "miss": 1.2, "warning": 0.9
    ]

    /// Score a list of text items, returning a normalised score in [-1, +1].
    ///
    /// - Parameters:
    ///   - texts: Array of (text, source, publishedAt) tuples.
    ///   - referenceDate: The "now" anchor for decay calculation.
    // swiftlint:disable:next large_tuple
    func score(
        texts: [(text: String, source: String, publishedAt: Date)],
        referenceDate: Date = Date()
    ) -> Double {
        guard !texts.isEmpty else { return 0 }

        var weightedSum = 0.0
        var totalWeight = 0.0

        for item in texts {
            let tierWeight  = Self.tierWeights[item.source.lowercased()] ?? 0.8
            let ageHours    = referenceDate.timeIntervalSince(item.publishedAt) / 3600
            let decayFactor = pow(0.5, ageHours / Self.halfLifeHours)
            let weight      = tierWeight * decayFactor

            let raw = keywordScore(text: item.text.lowercased())
            weightedSum += raw * weight
            totalWeight += weight
        }

        guard totalWeight > 0 else { return 0 }
        let raw = weightedSum / totalWeight
        return max(-1.0, min(1.0, raw))
    }

    // MARK: Private

    private func keywordScore(text: String) -> Double {
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
