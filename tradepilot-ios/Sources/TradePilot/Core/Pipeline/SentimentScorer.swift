import Foundation

/// Step 2 — Refines raw sentiment using time-decay weighting and source tier multipliers.
/// Matches the Python SentimentScorer formula exactly.
/// Delegates per-text scoring to SentimentModelManager (ready for Core ML swap-in).
struct SentimentScorer {
    // Source tier multipliers (higher = more trusted)
    private static let tierWeights: [String: Double] = [
        "news":   1.5,
        "reddit": 1.0
    ]

    // Time-decay half-life in hours
    private static let halfLifeHours: Double = 24

    private let modelManager: SentimentModelManager

    init(modelManager: SentimentModelManager = SentimentModelManager()) {
        self.modelManager = modelManager
    }

    /// Score a list of text items, returning a normalised score in [-1, +1].
    ///
    /// - Parameters:
    ///   - texts: Array of (text, source, publishedAt) tuples.
    ///   - referenceDate: The "now" anchor for decay calculation.
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

            let raw = modelManager.scoreSentiment(text: item.text)
            weightedSum += raw * weight
            totalWeight += weight
        }

        guard totalWeight > 0 else { return 0 }
        let raw = weightedSum / totalWeight
        return max(-1.0, min(1.0, raw))
    }
}
