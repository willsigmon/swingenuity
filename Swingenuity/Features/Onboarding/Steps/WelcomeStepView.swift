import SwiftUI

/// First onboarding step - app introduction
struct WelcomeStepView: View {
    @State private var showContent = false

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xxl) {
            Spacer()

            // App icon
            Image(systemName: "figure.golf")
                .font(.system(size: 80))
                .foregroundStyle(.white)
                .scaleEffect(showContent ? 1 : 0.5)
                .opacity(showContent ? 1 : 0)

            VStack(spacing: DesignTokens.Spacing.md) {
                Text("Swingenuity")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)

                Text("Analyze and perfect your swing across any sport")
                    .font(DesignTokens.Typography.title3)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 20)

            Spacer()

            // Feature highlights
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                FeatureRow(icon: "camera.fill", text: "Record your swing")
                FeatureRow(icon: "figure.walk", text: "AI-powered body tracking")
                FeatureRow(icon: "chart.bar.fill", text: "Detailed metrics & scores")
            }
            .padding(DesignTokens.Spacing.xl)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 30)

            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                showContent = true
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 30)

            Text(text)
                .font(DesignTokens.Typography.body)
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}

#Preview {
    ZStack {
        OnboardingBackground()
        WelcomeStepView()
    }
}
