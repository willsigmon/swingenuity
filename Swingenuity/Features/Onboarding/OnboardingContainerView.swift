import SwiftUI

/// Main container view orchestrating the onboarding flow
struct OnboardingContainerView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            // Animated background
            OnboardingBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                OnboardingProgressView(
                    currentPage: viewModel.currentPage,
                    totalPages: viewModel.totalPages
                )
                .padding(.top, DesignTokens.Spacing.lg)
                .padding(.horizontal, DesignTokens.Spacing.xl)

                // Page content
                TabView(selection: $viewModel.currentPage) {
                    WelcomeStepView()
                        .tag(0)

                    SportSelectionStepView(selectedSport: $viewModel.selectedSport)
                        .tag(1)

                    SkillLevelStepView(skillLevel: $viewModel.skillLevel)
                        .tag(2)

                    HandednessStepView(isLeftHanded: $viewModel.isLeftHanded)
                        .tag(3)

                    PermissionsStepView(viewModel: viewModel)
                        .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(DesignTokens.Animation.standard, value: viewModel.currentPage)

                // Navigation buttons
                HStack(spacing: DesignTokens.Spacing.md) {
                    // Back button
                    if viewModel.currentPage > 0 {
                        Button(action: viewModel.previousPage) {
                            HStack(spacing: DesignTokens.Spacing.xs) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Next/Complete button
                    OnboardingButton(
                        title: viewModel.isOnLastPage ? "Get Started" : "Next",
                        isEnabled: viewModel.canProceedFromCurrentPage
                    ) {
                        if viewModel.isOnLastPage {
                            completeOnboarding()
                        } else {
                            viewModel.nextPage()
                        }
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.xl)
                .padding(.bottom, DesignTokens.Spacing.xxl)
            }
        }
        .onAppear {
            viewModel.checkCameraPermission()
            viewModel.loadExistingPreferences()
        }
    }

    private func completeOnboarding() {
        viewModel.savePreferences()
        coordinator.completeOnboarding()
    }
}

#Preview {
    OnboardingContainerView()
        .environment(AppCoordinator())
}
