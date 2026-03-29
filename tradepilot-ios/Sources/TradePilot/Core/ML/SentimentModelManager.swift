import Foundation

// MARK: - Sentiment Model Manager

/// Manages sentiment scoring, with a path to swap in a Core ML model (e.g. FinBERT).
///
/// Current implementation delegates to the keyword-based scorer already in SentimentScorer.
/// When a real `.mlmodel` is bundled, flip `usesCoreML = true` and implement `_coreMLScore`.
final class SentimentModelManager {

    // MARK: - Public flag

    /// True when a compiled Core ML model (.mlmodelc) is bundled and loaded.
    /// Flip to `true` after adding FinBERT.mlmodel to the Xcode target.
    private(set) var usesCoreML: Bool = false

    // MARK: - Keyword scorer (current implementation)

    private static let bullishKeywords: [String: Double] = [
        "strong buy": 2.0, "buy": 1.0, "long": 1.0, "bull": 1.2, "bullish": 1.5,
        "breakout": 1.3, "calls": 1.0, "upside": 1.2, "rally": 1.1,
        "positive": 0.7, "growth": 0.8, "upgrade": 1.5, "beat": 1.2, "record": 0.9
    ]

    private static let bearishKeywords: [String: Double] = [
        "strong sell": 2.0, "sell": 1.0, "short": 1.0, "bear": 1.2, "bearish": 1.5,
        "breakdown": 1.3, "puts": 1.0, "downside": 1.2, "crash": 1.4, "dump": 1.1,
        "negative": 0.7, "decline": 0.8, "downgrade": 1.5, "miss": 1.2, "warning": 0.9
    ]

    // MARK: - Core ML model (placeholder)

    // When bundling FinBERT.mlmodel:
    //   1. Add the .mlmodel to Xcode target
    //   2. let model = try FinBERT(configuration: MLModelConfiguration())
    //   3. Set usesCoreML = true
    //   4. Implement _coreMLScore below

    // MARK: - Public API

    /// Score a text string in [-1.0, +1.0].
    /// Positive = bullish, negative = bearish, 0 = neutral.
    func scoreSentiment(text: String) -> Double {
        if usesCoreML {
            return _coreMLScore(text: text)
        }
        return _keywordScore(text: text.lowercased())
    }

    // MARK: - Private implementations

    private func _keywordScore(text: String) -> Double {
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
        let raw = (bullScore - bearScore) / total
        return max(-1.0, min(1.0, raw))
    }

    /// Placeholder for Core ML inference. Replace with real MLModel prediction call.
    private func _coreMLScore(text: String) -> Double {
        // Replace with:
        //   let input = FinBERTInput(text: text)
        //   let output = try? model.prediction(input: input)
        //   return output?.sentiment ?? 0
        return _keywordScore(text: text.lowercased())
    }
}
