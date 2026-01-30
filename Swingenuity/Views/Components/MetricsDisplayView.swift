import SwiftUI

struct MetricsDisplayView: View {
    let metrics: LiveMetrics
    let sport: Sport

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                // Speed Metric
                MetricPill(
                    icon: "speedometer",
                    value: String(format: "%.0f", metrics.currentSpeed),
                    unit: "mph",
                    color: .blue
                )

                // Angle Metric
                MetricPill(
                    icon: "rotate.right",
                    value: String(format: "%.0f", metrics.currentAngle),
                    unit: "°",
                    color: .orange
                )
            }

            // Confidence Indicator
            ConfidenceBar(confidence: metrics.confidence)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Metric Pill

struct MetricPill: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Confidence Bar

struct ConfidenceBar: View {
    let confidence: Float

    var confidenceColor: Color {
        switch confidence {
        case 0.8...1.0:
            return .green
        case 0.6..<0.8:
            return .yellow
        case 0.4..<0.6:
            return .orange
        default:
            return .red
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Tracking Quality")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(confidence * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(confidenceColor)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))

                    Capsule()
                        .fill(confidenceColor)
                        .frame(width: geometry.size.width * CGFloat(confidence))
                }
            }
            .frame(height: 6)
        }
    }
}

#Preview {
    ZStack {
        Color.black
        MetricsDisplayView(
            metrics: LiveMetrics(
                currentSpeed: 98.5,
                currentAngle: 45.2,
                confidence: 0.87
            ),
            sport: .golf
        )
        .padding()
    }
}
