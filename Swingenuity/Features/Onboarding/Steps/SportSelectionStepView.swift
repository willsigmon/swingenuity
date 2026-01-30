import SwiftUI

/// Second step - select primary sport
struct SportSelectionStepView: View {
    @Binding var selectedSport: Sport?

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            // Header
            VStack(spacing: DesignTokens.Spacing.sm) {
                Text("Choose Your Sport")
                    .font(DesignTokens.Typography.title)
                    .foregroundStyle(.white)

                Text("Select the sport you'll analyze most often")
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, DesignTokens.Spacing.xxl)

            // Sport grid
            LazyVGrid(columns: columns, spacing: DesignTokens.Spacing.md) {
                ForEach(Sport.allCases, id: \.self) { sport in
                    SportCard(
                        sport: sport,
                        isSelected: selectedSport == sport
                    ) {
                        withAnimation(DesignTokens.Animation.spring) {
                            selectedSport = sport
                        }
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)

            Spacer()
        }
    }
}

struct SportCard: View {
    let sport: Sport
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: sport.symbolName)
                    .font(.system(size: 40))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.8))

                Text(sport.displayName)
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.xl)
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
        SportSelectionStepView(selectedSport: .constant(.golf))
    }
}
