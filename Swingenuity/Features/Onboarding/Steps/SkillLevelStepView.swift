import SwiftUI

/// Third step - select skill level
struct SkillLevelStepView: View {
    @Binding var skillLevel: SkillLevel?

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            // Header
            VStack(spacing: DesignTokens.Spacing.sm) {
                Text("Your Experience Level")
                    .font(DesignTokens.Typography.title)
                    .foregroundStyle(.white)

                Text("This helps us calibrate the analysis")
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.top, DesignTokens.Spacing.xxl)

            // Skill level options
            VStack(spacing: DesignTokens.Spacing.md) {
                ForEach(SkillLevel.allCases, id: \.self) { level in
                    SkillLevelRow(
                        level: level,
                        isSelected: skillLevel == level
                    ) {
                        withAnimation(DesignTokens.Animation.spring) {
                            skillLevel = level
                        }
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)

            Spacer()
        }
    }
}

struct SkillLevelRow: View {
    let level: SkillLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: level.symbolName)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(level.displayName)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(.white)

                    Text(level.description)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }
            .padding(DesignTokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .fill(isSelected ? Color.white.opacity(0.25) : Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .strokeBorder(isSelected ? Color.white : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        OnboardingBackground()
        SkillLevelStepView(skillLevel: .constant(.intermediate))
    }
}
