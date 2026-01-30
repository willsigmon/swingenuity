import SwiftUI

/// Step indicator dots for onboarding progress
struct OnboardingProgressView: View {
    let currentPage: Int
    let totalPages: Int

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(index <= currentPage ? Color.white : Color.white.opacity(0.3))
                    .frame(width: index == currentPage ? 12 : 8, height: index == currentPage ? 12 : 8)
                    .animation(DesignTokens.Animation.spring, value: currentPage)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.blue
        OnboardingProgressView(currentPage: 2, totalPages: 5)
    }
}
