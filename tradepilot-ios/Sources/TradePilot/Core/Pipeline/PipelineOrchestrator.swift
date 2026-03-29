import Foundation

// MARK: - Pipeline errors

enum PipelineError: Error, LocalizedError {
    case insufficientCandidates(count: Int)
    case agentTimeout(agent: String)
    case allSlotsRejected

    var errorDescription: String? {
        switch self {
        case .insufficientCandidates(let count): return "Only \(count) candidates passed compliance checks."
        case .agentTimeout(let agentName):       return "Agent '\(agentName)' timed out."
        case .allSlotsRejected:              return "All strategy slots were rejected after \(maxRetries) retries."
        }
    }
}

private let maxRetries       = 3
private let agentTimeoutSecs = 60.0

// MARK: - Orchestrator

/// Runs the five pipeline agents sequentially and retries rejected strategy slots.
actor PipelineOrchestrator {
    private let aggregator: DataAggregator
    private let scorer: SentimentScorer
    private let strategy: QuantStrategy
    private let compliance: RiskCompliance
    private let advisor: ExpertAdvisor

    init(
        aggregator: DataAggregator = DataAggregator(),
        scorer: SentimentScorer    = SentimentScorer(),
        strategy: QuantStrategy    = QuantStrategy(),
        compliance: RiskCompliance = RiskCompliance(),
        advisor: ExpertAdvisor     = ExpertAdvisor()
    ) {
        self.aggregator = aggregator
        self.scorer     = scorer
        self.strategy   = strategy
        self.compliance = compliance
        self.advisor    = advisor
    }

    /// Run the full pipeline and return the expert-reviewed recommendations.
    func run() async throws -> AdvisorReview {
        // Step 1 — Data collection
        let rawFeatures = try await withTimeout(seconds: agentTimeoutSecs, agent: "DataAggregator") {
            try await self.aggregator.aggregate()
        }

        // Step 2 — Compliance filter (no separate async step needed)
        let compliantFeatures = compliance.filter(rawFeatures)
        guard compliantFeatures.count >= 4 else {
            throw PipelineError.insufficientCandidates(count: compliantFeatures.count)
        }

        // Step 3 — Strategy selection with retry loop
        var selected: [ScoredCandidate] = []
        var pool = compliantFeatures
        var attempts = 0

        while selected.count < 4 && attempts < maxRetries {
            let candidates = strategy.selectCandidates(from: pool)
            let validated  = candidates.filter { compliance.validate($0.features) == .passed }
            selected       = validated

            if selected.count < 4 {
                // Remove already-selected tickers and retry with remainder
                let usedTickers = Set(selected.map(\.features.ticker))
                pool = pool.filter { !usedTickers.contains($0.ticker) }
            }
            attempts += 1
        }

        guard !selected.isEmpty else {
            throw PipelineError.allSlotsRejected
        }

        // Step 4 — Expert review
        let review = advisor.review(selected)
        return review
    }

    // MARK: Private

    private func withTimeout<T: Sendable>(
        seconds: Double,
        agent: String,
        work: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await work() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw PipelineError.agentTimeout(agent: agent)
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
