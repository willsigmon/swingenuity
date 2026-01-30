import SwiftUI

struct ScoreCardView: View {
    let rating: Rating
    @State private var animateScore = false

    var body: some View {
        VStack(spacing: 20) {
            // Letter Grade with Animation
            Text(rating.letterGrade.rawValue)
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [rating.color, rating.color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(animateScore ? 1.0 : 0.5)
                .opacity(animateScore ? 1.0 : 0.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6), value: animateScore)

            // Numeric Score with Progress Ring
            ZStack {
                // Background Ring
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 12)
                    .frame(width: 120, height: 120)

                // Progress Ring
                Circle()
                    .trim(from: 0, to: animateScore ? rating.score / 100 : 0)
                    .stroke(
                        rating.color,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: animateScore)

                // Score Number
                VStack(spacing: 4) {
                    Text("\(Int(rating.score))")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(rating.color)

                    Text("out of 100")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Description Text
            Text(gradeDescription)
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: rating.color.opacity(0.3), radius: 10, y: 5)
        .onAppear {
            withAnimation {
                animateScore = true
            }
        }
    }

    private var gradeDescription: String {
        switch rating.letterGrade {
        case .aPlus, .a:
            return "Excellent Form!"
        case .aMinus, .bPlus:
            return "Great Swing!"
        case .b, .bMinus:
            return "Good Technique"
        case .cPlus, .c:
            return "Solid Foundation"
        case .cMinus, .dPlus:
            return "Room for Improvement"
        case .d, .dMinus:
            return "Keep Practicing"
        case .f:
            return "Needs Work"
        }
    }
}

#Preview("High Score") {
    ScoreCardView(rating: Rating(score: 94))
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("Medium Score") {
    ScoreCardView(rating: Rating(score: 76))
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("Low Score") {
    ScoreCardView(rating: Rating(score: 58))
        .padding()
        .background(Color(.systemGroupedBackground))
}
