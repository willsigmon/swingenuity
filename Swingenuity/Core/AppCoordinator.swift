import SwiftUI

/// Root coordinator managing app-level navigation state
@Observable
@MainActor
final class AppCoordinator {
    /// Whether onboarding has been completed for current app version
    var isOnboardingComplete: Bool

    init() {
        let completedVersion = UserDefaults.standard.string(forKey: UserDefaultsKeys.onboardingCompletionVersion)
        let currentVersion = Bundle.main.appVersion
        isOnboardingComplete = (completedVersion == currentVersion) &&
                               UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasCompletedOnboarding)
    }

    /// Mark onboarding as complete and persist
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasCompletedOnboarding)
        UserDefaults.standard.set(Bundle.main.appVersion, forKey: UserDefaultsKeys.onboardingCompletionVersion)
        isOnboardingComplete = true
    }

    /// Reset onboarding state (for testing or re-onboarding)
    func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: UserDefaultsKeys.hasCompletedOnboarding)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.onboardingCompletionVersion)
        isOnboardingComplete = false
    }
}

// MARK: - Bundle Extension
extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
