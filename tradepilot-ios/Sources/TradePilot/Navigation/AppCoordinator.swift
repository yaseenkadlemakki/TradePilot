import SwiftUI

/// Routes first-launch users through Onboarding, then shows MainTabView.
struct AppCoordinator: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            MainTabView()
        } else {
            OnboardingView {
                hasCompletedOnboarding = true
            }
        }
    }
}
