import SwiftUI
import SwiftData
import Observation

enum RiskTolerance: String, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low:    return "Low"
        case .medium: return "Medium"
        case .high:   return "High"
        }
    }
}

@Observable
final class SettingsViewModel {
    // API key fields (in-memory; persisted to Keychain on save)
    var polygonKey        = ""
    var unusualWhalesKey  = ""
    var claudeKey         = ""
    var newsKey           = ""
    var redditClientID    = ""
    var redditClientSecret = ""

    var riskTolerance: RiskTolerance = .medium
    var validationMessage: String?
    var isSaving = false

    private let keychain = KeychainManager()

    // MARK: - Load

    func loadFromKeychain() {
        polygonKey          = keychain.load(service: KeychainManager.ServiceKey.polygonAPIKey)        ?? ""
        unusualWhalesKey    = keychain.load(service: KeychainManager.ServiceKey.unusualWhalesAPIKey)  ?? ""
        claudeKey           = keychain.load(service: KeychainManager.ServiceKey.claudeAPIKey)         ?? ""
        newsKey             = keychain.load(service: KeychainManager.ServiceKey.newsAPIKey)           ?? ""
        redditClientID      = keychain.load(service: KeychainManager.ServiceKey.redditClientID)      ?? ""
        redditClientSecret  = keychain.load(service: KeychainManager.ServiceKey.redditClientSecret)  ?? ""
    }

    func loadPreferences(context: ModelContext) {
        let cache = LocalCache()
        if let raw = cache.getPreference(key: UserPreference.Key.riskTolerance, in: context),
           let parsed = RiskTolerance(rawValue: raw) {
            riskTolerance = parsed
        }
    }

    // MARK: - Save

    @MainActor
    func save(context: ModelContext) async {
        isSaving = true
        validationMessage = nil
        defer { isSaving = false }

        do {
            if polygonKey.isEmpty {
                keychain.delete(service: KeychainManager.ServiceKey.polygonAPIKey)
            } else { try keychain.save(key: polygonKey, service: KeychainManager.ServiceKey.polygonAPIKey) }
            if unusualWhalesKey.isEmpty {
                keychain.delete(service: KeychainManager.ServiceKey.unusualWhalesAPIKey)
            } else { try keychain.save(key: unusualWhalesKey, service: KeychainManager.ServiceKey.unusualWhalesAPIKey) }
            if claudeKey.isEmpty {
                keychain.delete(service: KeychainManager.ServiceKey.claudeAPIKey)
            } else { try keychain.save(key: claudeKey, service: KeychainManager.ServiceKey.claudeAPIKey) }
            if newsKey.isEmpty {
                keychain.delete(service: KeychainManager.ServiceKey.newsAPIKey)
            } else { try keychain.save(key: newsKey, service: KeychainManager.ServiceKey.newsAPIKey) }
            if redditClientID.isEmpty {
                keychain.delete(service: KeychainManager.ServiceKey.redditClientID)
            } else { try keychain.save(key: redditClientID, service: KeychainManager.ServiceKey.redditClientID) }
            if redditClientSecret.isEmpty {
                keychain.delete(service: KeychainManager.ServiceKey.redditClientSecret)
            } else { try keychain.save(key: redditClientSecret, service: KeychainManager.ServiceKey.redditClientSecret) }

            let cache = LocalCache()
            cache.setPreference(key: UserPreference.Key.riskTolerance, value: riskTolerance.rawValue, in: context)

            validationMessage = "Settings saved."
        } catch {
            validationMessage = "Save failed: \(error.localizedDescription)"
        }
    }
}
