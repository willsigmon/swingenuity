import SwiftUI

/// Animated gradient background for onboarding screens
struct OnboardingBackground: View {
    @State private var animateGradient = false

    private let colors: [Color] = [
        Color(red: 0.15, green: 0.45, blue: 0.35),  // Deep green
        Color(red: 0.1, green: 0.35, blue: 0.55),   // Deep blue
        Color(red: 0.2, green: 0.5, blue: 0.4),     // Teal
        Color(red: 0.15, green: 0.4, blue: 0.5),    // Blue-green
    ]

    var body: some View {
        LinearGradient(
            colors: animateGradient ? colors : colors.reversed(),
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

#Preview {
    OnboardingBackground()
}
