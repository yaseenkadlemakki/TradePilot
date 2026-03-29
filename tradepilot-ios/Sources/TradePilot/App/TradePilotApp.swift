import SwiftUI
import SwiftData

@main
struct TradePilotApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(
                for: CachedRecommendation.self, UserPreference.self
            )
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppCoordinator()
                .modelContainer(modelContainer)
        }
    }
}
