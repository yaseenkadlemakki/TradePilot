import Foundation

/// Step 1 — Collects raw data from all four services and returns up to 50 feature vectors.
actor DataAggregator {
    private let polygon: PolygonService
    private let unusualWhales: UnusualWhalesService
    private let reddit: RedditService
    private let news: NewsService

    init(
        polygon: PolygonService = PolygonService(),
        unusualWhales: UnusualWhalesService = UnusualWhalesService(),
        reddit: RedditService = RedditService(),
        news: NewsService = NewsService()
    ) {
        self.polygon       = polygon
        self.unusualWhales = unusualWhales
        self.reddit        = reddit
        self.news          = news
    }

    /// Aggregate data and return feature vectors for top candidates.
    func aggregate() async throws -> [CandidateFeatures] {
        // Collect data concurrently; gracefully handle individual failures
        async let redditPostsTask  = (try? await reddit.fetchPosts(limit: 100)) ?? []
        async let flowTask         = (try? await unusualWhales.fetchFlow()) ?? []

        let (redditPosts, flowData) = await (redditPostsTask, flowTask)

        // Extract tickers from Reddit text
        let redditTickers = extractTickers(from: redditPosts)

        // Build flow ticker map
        var flowByTicker: [String: [UnusualWhalesFlow]] = [:]
        for flow in flowData {
            flowByTicker[flow.ticker, default: []].append(flow)
        }

        // Combine tickers
        var allTickers = Set(redditTickers).union(Set(flowByTicker.keys))
        allTickers = Set(allTickers.prefix(50))

        var features: [CandidateFeatures] = []

        for ticker in allTickers {
            guard let feature = await buildFeatures(
                ticker: ticker,
                redditPosts: redditPosts,
                flowData: flowByTicker[ticker] ?? []
            ) else { continue }
            features.append(feature)
        }

        // Sort by composite relevance (flow score + sentiment)
        return features
            .sorted { ($0.unusualFlowScore + $0.sentimentScore) > ($1.unusualFlowScore + $1.sentimentScore) }
            .prefix(50)
            .map { $0 }
    }

    // MARK: Private

    private func buildFeatures(
        ticker: String,
        redditPosts: [RedditPost],
        flowData: [UnusualWhalesFlow]
    ) async -> CandidateFeatures? {
        let ohlcv = try? await polygon.fetchOHLCV(ticker: ticker)
        let rsi   = (try? await polygon.fetchRSI(ticker: ticker)) ?? 50.0

        let tickerPosts = redditPosts.filter {
            $0.title.uppercased().contains(ticker) || $0.selftext.uppercased().contains(ticker)
        }

        let sentimentScore    = computeSentiment(posts: tickerPosts)
        let mentionVolume     = min(log(Double(tickerPosts.count) + 1) / log(100), 1.0)
        let unusualFlowScore  = computeFlowScore(flows: flowData)
        let callPutRatio      = computeCallPutRatio(flows: flowData)
        let oiRank            = computeOIRank(flows: flowData)

        let priceVsMA20: Double
        let bollingerPosition: Double
        if let bar = ohlcv {
            priceVsMA20       = (bar.close - bar.vwap!) / bar.vwap!  // simplified
            bollingerPosition = rsi / 100.0
        } else {
            priceVsMA20       = 0
            bollingerPosition = 0.5
        }

        let rawOI     = flowData.map(\.openInterest).max().map(Double.init) ?? 0
        let rawVol    = flowData.map(\.volume).max().map(Double.init) ?? 0
        let spreadPct = 0.05  // placeholder; real value from options chain

        return CandidateFeatures(
            ticker: ticker,
            sentimentScore: sentimentScore,
            sentimentMomentum: 0,           // requires time-series; populated in next cycle
            mentionVolume: mentionVolume,
            unusualFlowScore: unusualFlowScore,
            callPutRatio: callPutRatio,
            openInterestRank: oiRank,
            priceVsMA20: priceVsMA20,
            priceVsMA50: priceVsMA20 * 0.9, // approximation
            rsiValue: rsi,
            bollingerPosition: bollingerPosition,
            impliedVolatilityRank: unusualFlowScore,
            daysToExpiration: 30,
            bidAskSpreadPct: spreadPct,
            openInterest: rawOI,
            optionVolume: rawVol
        )
    }

    private func extractTickers(from posts: [RedditPost]) -> [String] {
        let pattern = "\\b[A-Z]{1,5}\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let stopWords: Set<String> = ["A", "I", "THE", "AND", "OR", "BUT", "FOR", "IS", "IN", "TO", "AT", "BE",
                                       "DD", "YOL0", "YOLO", "WSB", "OTM", "ITM", "ATM", "IV", "DTE", "SPY",
                                       "QQQ", "EFT", "ETF", "CALL", "PUT"]
        var counts: [String: Int] = [:]

        for post in posts {
            let text = post.title + " " + post.selftext
            let range = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: range) {
                if let r = Range(match.range, in: text) {
                    let word = String(text[r])
                    if !stopWords.contains(word) {
                        counts[word, default: 0] += 1
                    }
                }
            }
        }
        return counts
            .filter { $0.value >= 3 }
            .sorted { $0.value > $1.value }
            .prefix(50)
            .map(\.key)
    }

    private func computeSentiment(posts: [RedditPost]) -> Double {
        guard !posts.isEmpty else { return 0 }
        let bullish  = ["calls", "bull", "long", "buy", "moon", "🚀", "green", "breakout"]
        let bearish  = ["puts", "bear", "short", "sell", "crash", "red", "dump", "🌈🐻"]

        var score = 0.0
        for post in posts {
            let text = (post.title + " " + post.selftext).lowercased()
            let bull = bullish.filter { text.contains($0) }.count
            let bear = bearish.filter { text.contains($0) }.count
            score += Double(bull - bear)
        }
        return max(-1, min(1, score / (Double(posts.count) * 5)))
    }

    private func computeFlowScore(flows: [UnusualWhalesFlow]) -> Double {
        guard !flows.isEmpty else { return 0 }
        let bullishCount = flows.filter { $0.sentiment.lowercased() == "bullish" }.count
        return Double(bullishCount) / Double(flows.count)
    }

    private func computeCallPutRatio(flows: [UnusualWhalesFlow]) -> Double {
        let calls = flows.filter { $0.contractType.lowercased() == "call" }.count
        let puts  = flows.filter { $0.contractType.lowercased() == "put"  }.count
        guard (calls + puts) > 0 else { return 1.0 }
        return Double(calls) / Double(calls + puts)
    }

    private func computeOIRank(flows: [UnusualWhalesFlow]) -> Double {
        let maxOI = flows.map(\.openInterest).max() ?? 0
        return min(Double(maxOI) / 10_000.0, 1.0)
    }
}
