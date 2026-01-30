import SwiftUI

/// Fourth step - select handedness
struct HandednessStepView: View {
    @Binding var isLeftHanded: Bool

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            // Header
            VStack(spacing: DesignTokens.Spacing.sm) {
                Text("Which Hand?")
                    .font(DesignTokens.Typography.title)
                    .foregroundStyle(.white)

                Text("This helps us analyze your swing correctly")
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, DesignTokens.Spacing.xxl)

            Spacer()

            // Handedness options
            HStack(spacing: DesignTokens.Spacing.lg) {
                HandednessButton(
                    title: "Right",
                    subtitle: "Right-handed",
                    icon: "hand.raised.fill",
                    isSelected: !isLeftHanded,
                    isFlipped: false
                ) {
                    withAnimation(DesignTokens.Animation.spring) {
                        isLeftHanded = false
                    }
                }

                HandednessButton(
                    title: "Left",
                    subtitle: "Left-handed",
                    icon: "hand.raised.fill",
                    isSelected: isLeftHanded,
                    isFlipped: true
                ) {
                    withAnimation(DesignTokens.Animation.spring) {
                        isLeftHanded = true
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)

            Spacer()
            Spacer()
        }
    }
}

struct HandednessButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let isFlipped: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 50))
                    .foregroundStyle(.white)
                    .scaleEffect(x: isFlipped ? -1 : 1, y: 1)

                VStack(spacing: 2) {
                    Text(title)
                        .font(DesignTokens.Typography.title2)
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.xxl)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                    .fill(isSelected ? Color.white.opacity(0.25) : Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                    .strokeBorder(isSelected ? Color.white : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        OnboardingBackground()
        HandednessStepView(isLeftHanded: .constant(false))
    }
}
