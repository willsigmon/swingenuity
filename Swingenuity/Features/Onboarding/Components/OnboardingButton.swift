import SwiftUI

/// Styled primary button for onboarding navigation
struct OnboardingButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                        .fill(isEnabled ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                        .strokeBorder(Color.white.opacity(isEnabled ? 0.5 : 0.2), lineWidth: 1)
                )
        }
        .disabled(!isEnabled)
        .animation(DesignTokens.Animation.quick, value: isEnabled)
    }
}

#Preview {
    ZStack {
        Color.blue
        VStack(spacing: 20) {
            OnboardingButton(title: "Enabled", isEnabled: true) {}
            OnboardingButton(title: "Disabled", isEnabled: false) {}
        }
        .padding()
    }
}
