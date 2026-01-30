import SwiftUI

struct ContentView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        Group {
            if coordinator.isOnboardingComplete {
                MainTabView()
            } else {
                OnboardingContainerView()
            }
        }
        .animation(DesignTokens.Animation.standard, value: coordinator.isOnboardingComplete)
    }
}

#Preview("Main App") {
    ContentView()
        .environment(AppCoordinator())
        .modelContainer(for: [SwingSession.self], inMemory: true)
}

#Preview("Onboarding") {
    let coordinator = AppCoordinator()
    coordinator.resetOnboarding()
    return ContentView()
        .environment(coordinator)
        .modelContainer(for: [SwingSession.self], inMemory: true)
}
