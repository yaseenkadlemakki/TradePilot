import Foundation
import SwiftData

// MARK: - SwiftData models

@Model
final class CachedRecommendation {
    var id: String
    var ticker: String
    var strategyType: String
    var confidenceScore: Double
    var generatedAt: Date
    var jsonPayload: Data          // full Recommendation encoded as JSON

    init(id: String, ticker: String, strategyType: String, confidenceScore: Double, generatedAt: Date, jsonPayload: Data) {
        self.id              = id
        self.ticker          = ticker
        self.strategyType    = strategyType
        self.confidenceScore = confidenceScore
        self.generatedAt     = generatedAt
        self.jsonPayload     = jsonPayload
    }
}

@Model
final class UserPreference {
    var key: String
    var value: String
    var updatedAt: Date

    init(key: String, value: String) {
        self.key       = key
        self.value     = value
        self.updatedAt = Date()
    }
}

// MARK: - Preference keys

extension UserPreference {
    enum Key {
        static let riskTolerance       = "risk_tolerance"    // "low" | "medium" | "high"
        static let notificationsEnabled = "notifications_enabled"
        static let maxPositions        = "max_positions"
    }
}

// MARK: - Cache operations

/// Provides CRUD operations for recommendations and user preferences.
struct LocalCache {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        encoder = enc
        decoder = dec
    }

    // MARK: Recommendations

    /// Persist a `Recommendation` (upsert by id).
    func save(_ recommendation: Recommendation, in context: ModelContext) throws {
        let payload = try encoder.encode(recommendation)
        if let existing = fetchByID(recommendation.id, in: context) {
            existing.jsonPayload     = payload
            existing.confidenceScore = recommendation.confidenceScore
        } else {
            let cached = CachedRecommendation(
                id:              recommendation.id,
                ticker:          recommendation.ticker,
                strategyType:    recommendation.strategyType.rawValue,
                confidenceScore: recommendation.confidenceScore,
                generatedAt:     recommendation.generatedAt,
                jsonPayload:     payload
            )
            context.insert(cached)
        }
    }

    /// Fetch all recommendations generated today.
    func fetchToday(in context: ModelContext) -> [Recommendation] {
        let start = Calendar.current.startOfDay(for: Date())
        let pred  = #Predicate<CachedRecommendation> { $0.generatedAt >= start }
        let desc  = FetchDescriptor(predicate: pred, sortBy: [SortDescriptor(\.generatedAt, order: .reverse)])
        do {
            let cached = try context.fetch(desc)
            return cached.compactMap { decode($0) }
        } catch {
            print("SwiftData error fetching today's recommendations: \(error)")
            return []
        }
    }

    /// Fetch recommendations in a date range.
    func fetchHistory(from start: Date, to end: Date, in context: ModelContext) -> [Recommendation] {
        let pred = #Predicate<CachedRecommendation> { $0.generatedAt >= start && $0.generatedAt <= end }
        let desc = FetchDescriptor(predicate: pred, sortBy: [SortDescriptor(\.generatedAt, order: .reverse)])
        do {
            let cached = try context.fetch(desc)
            return cached.compactMap { decode($0) }
        } catch {
            print("SwiftData error fetching recommendation history: \(error)")
            return []
        }
    }

    /// Delete a recommendation by id.
    func delete(id: String, in context: ModelContext) {
        if let cached = fetchByID(id, in: context) {
            context.delete(cached)
        }
    }

    // MARK: Preferences

    func setPreference(key: String, value: String, in context: ModelContext) {
        let pred = #Predicate<UserPreference> { $0.key == key }
        let desc = FetchDescriptor(predicate: pred)
        do {
            if let existing = try context.fetch(desc).first {
                existing.value     = value
                existing.updatedAt = Date()
            } else {
                context.insert(UserPreference(key: key, value: value))
            }
        } catch {
            print("SwiftData error setting preference '\(key)': \(error)")
        }
    }

    func getPreference(key: String, in context: ModelContext) -> String? {
        let pred = #Predicate<UserPreference> { $0.key == key }
        let desc = FetchDescriptor(predicate: pred)
        do {
            return try context.fetch(desc).first?.value
        } catch {
            print("SwiftData error getting preference '\(key)': \(error)")
            return nil
        }
    }

    // MARK: Private

    private func fetchByID(_ id: String, in context: ModelContext) -> CachedRecommendation? {
        let pred = #Predicate<CachedRecommendation> { $0.id == id }
        let desc = FetchDescriptor(predicate: pred)
        do {
            return try context.fetch(desc).first
        } catch {
            print("SwiftData error fetching recommendation by id '\(id)': \(error)")
            return nil
        }
    }

    private func decode(_ cached: CachedRecommendation) -> Recommendation? {
        try? decoder.decode(Recommendation.self, from: cached.jsonPayload)
    }
}
