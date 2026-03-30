import Foundation

/// Manages sentiment scoring, with a clear seam for swapping in a Core ML model.
///
/// Current implementation: delegates to the keyword-based `SentimentScorer`.
/// Future upgrade path (one-line change when `.mlmodel` is bundled):
/// ```swift
/// usesCoreML = true
/// // Replace keywordScorer call with:
/// // return try await finBERT.prediction(input: text).sentimentScore
/// ```
final class SentimentModelManager: Sendable {

    /// `true` once a Core ML FinBERT model is bundled and loaded.
    let usesCoreML: Bool = false

    private let keywordScorer = SentimentScorer()

    /// Returns a sentiment score in [-1.0, +1.0] for a single text string.
    ///
    /// - Positive values indicate bullish sentiment.
    /// - Negative values indicate bearish sentiment.
    func scoreSentiment(text: String) -> Double {
        // Wrap the single text in the format SentimentScorer expects.
        let item = (text: text, source: "direct", publishedAt: Date())
        return keywordScorer.score(texts: [item])
    }

    /// Batch variant — scores multiple texts and returns the array of scores.
    func scoreSentiments(texts: [String]) -> [Double] {
        texts.map { scoreSentiment(text: $0) }
    }
}
