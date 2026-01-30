import Foundation

/// Type-safe UserDefaults keys
enum UserDefaultsKeys {
    // MARK: - Onboarding
    static let hasCompletedOnboarding = "onboarding.hasCompleted"
    static let onboardingCompletionVersion = "onboarding.completionAppVersion"

    // MARK: - User Preferences
    static let preferredSport = "preferences.sport"
    static let skillLevel = "preferences.skillLevel"
    static let isLeftHanded = "preferences.isLeftHanded"

    // MARK: - App Settings
    static let hasRequestedCameraPermission = "permissions.cameraRequested"
    static let showSkeletonOverlay = "settings.showSkeletonOverlay"
    static let autoSaveRecordings = "settings.autoSaveRecordings"
}
