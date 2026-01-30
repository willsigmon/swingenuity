import SwiftUI
import AVFoundation

/// View model managing onboarding state and user selections
@Observable
@MainActor
final class OnboardingViewModel {
    // MARK: - State
    var currentPage: Int = 0
    var selectedSport: Sport?
    var skillLevel: SkillLevel?
    var isLeftHanded: Bool = false

    // MARK: - Camera Permission
    var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    var isRequestingPermission: Bool = false

    // MARK: - Navigation
    let totalPages = 5

    var canProceedFromCurrentPage: Bool {
        switch currentPage {
        case 0: return true  // Welcome - always can proceed
        case 1: return selectedSport != nil  // Sport selection required
        case 2: return skillLevel != nil  // Skill level required
        case 3: return true  // Handedness has default
        case 4: return cameraPermissionStatus == .authorized  // Camera required
        default: return false
        }
    }

    var isOnLastPage: Bool {
        currentPage == totalPages - 1
    }

    var progressPercentage: Double {
        Double(currentPage + 1) / Double(totalPages)
    }

    // MARK: - Actions
    func nextPage() {
        guard currentPage < totalPages - 1 else { return }
        withAnimation(DesignTokens.Animation.standard) {
            currentPage += 1
        }
    }

    func previousPage() {
        guard currentPage > 0 else { return }
        withAnimation(DesignTokens.Animation.standard) {
            currentPage -= 1
        }
    }

    func goToPage(_ page: Int) {
        guard page >= 0 && page < totalPages else { return }
        withAnimation(DesignTokens.Animation.standard) {
            currentPage = page
        }
    }

    // MARK: - Camera Permission
    func checkCameraPermission() {
        cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    func requestCameraPermission() async {
        isRequestingPermission = true
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        isRequestingPermission = false
        cameraPermissionStatus = granted ? .authorized : .denied
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasRequestedCameraPermission)
    }

    // MARK: - Persistence
    func savePreferences() {
        if let sport = selectedSport {
            UserDefaults.standard.set(sport.rawValue, forKey: UserDefaultsKeys.preferredSport)
        }
        if let level = skillLevel {
            UserDefaults.standard.set(level.rawValue, forKey: UserDefaultsKeys.skillLevel)
        }
        UserDefaults.standard.set(isLeftHanded, forKey: UserDefaultsKeys.isLeftHanded)
    }

    func loadExistingPreferences() {
        if let sportRaw = UserDefaults.standard.string(forKey: UserDefaultsKeys.preferredSport),
           let sport = Sport(rawValue: sportRaw) {
            selectedSport = sport
        }
        if let levelRaw = UserDefaults.standard.string(forKey: UserDefaultsKeys.skillLevel),
           let level = SkillLevel(rawValue: levelRaw) {
            skillLevel = level
        }
        isLeftHanded = UserDefaults.standard.bool(forKey: UserDefaultsKeys.isLeftHanded)
    }
}
