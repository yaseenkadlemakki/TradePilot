import Foundation

/// Per-ticker aggregated sentiment data from multiple sources.
struct SentimentReport: Codable, Hashable {
    let ticker: String
    let overallScore: Double           // -1.0 to +1.0
    let mentionVolume: Int
    let mentionMomentum: Double        // volume change vs prior period
    let redditScore: Double
    let newsScore: Double
    let sourceCounts: SourceCounts
    let topKeywords: [String]
    let computedAt: Date

    enum CodingKeys: String, CodingKey {
        case ticker
        case overallScore     = "overall_score"
        case mentionVolume    = "mention_volume"
        case mentionMomentum  = "mention_momentum"
        case redditScore      = "reddit_score"
        case newsScore        = "news_score"
        case sourceCounts     = "source_counts"
        case topKeywords      = "top_keywords"
        case computedAt       = "computed_at"
    }
}

struct SourceCounts: Codable, Hashable {
    let reddit: Int
    let news: Int
}
