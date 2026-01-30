import SwiftUI
import SwiftData

struct AnalysisResultView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: AnalysisResultViewModel

    init(session: SwingSession) {
        _viewModel = State(initialValue: AnalysisResultViewModel(swingSession: session))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Video Replay Section
                    videoReplaySection

                    // Score Display
                    if let rating = viewModel.swingSession.rating {
                        ScoreCardView(rating: rating)
                            .padding(.horizontal)
                    }

                    // Metrics Breakdown
                    if let metrics = viewModel.swingSession.metrics {
                        metricsBreakdownSection(metrics: metrics)
                    }

                    // Phase Analysis
                    phaseAnalysisSection

                    // Improvement Tips
                    improvementTipsSection
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: saveSession) {
                            Label("Save", systemImage: "square.and.arrow.down")
                        }

                        Button(action: shareResults) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    // MARK: - Video Replay Section

    private var videoReplaySection: some View {
        VStack(spacing: 12) {
            // Video Preview with Skeleton
            ZStack {
                Rectangle()
                    .fill(Color.black)
                    .aspectRatio(16/9, contentMode: .fit)

                if let frame = viewModel.currentFrame {
                    SkeletonOverlayView(frame: frame)
                }

                // Playback Controls Overlay
                VStack {
                    Spacer()

                    HStack(spacing: 20) {
                        Button(action: viewModel.previousFrame) {
                            Image(systemName: "backward.frame.fill")
                                .font(.title2)
                        }

                        Button(action: viewModel.togglePlayback) {
                            Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 50))
                        }

                        Button(action: viewModel.nextFrame) {
                            Image(systemName: "forward.frame.fill")
                                .font(.title2)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.bottom, 20)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            // Progress Slider
            Slider(
                value: Binding(
                    get: { viewModel.progressPercentage },
                    set: { viewModel.seekToPercentage($0) }
                ),
                in: 0...1
            )
            .padding(.horizontal)
        }
    }

    // MARK: - Metrics Breakdown

    private func metricsBreakdownSection(metrics: SwingMetrics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Metrics Breakdown")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            // Category Selector
            Picker("Category", selection: $viewModel.selectedMetricCategory) {
                ForEach(MetricCategory.allCases, id: \.self) { category in
                    Label(category.rawValue, systemImage: category.icon)
                        .tag(category)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Metric Details
            VStack(spacing: 12) {
                switch viewModel.selectedMetricCategory {
                case .form:
                    formMetricsDetail(metrics.formMetrics)
                case .speed:
                    speedMetricsDetail(metrics.speedMetrics)
                case .consistency:
                    if let consistency = metrics.consistencyMetrics {
                        consistencyMetricsDetail(consistency)
                    } else {
                        Text("Record multiple swings to see consistency metrics")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    private func formMetricsDetail(_ form: FormMetrics) -> some View {
        VStack(spacing: 12) {
            MetricRow(title: "Hip Rotation", value: "\(Int(form.hipRotationAngle))°", score: form.compositeScore)
            MetricRow(title: "Shoulder Rotation", value: "\(Int(form.shoulderRotationAngle))°", score: form.compositeScore)
            MetricRow(title: "Weight Transfer", value: "\(Int(form.weightTransferPercentage))%", score: form.compositeScore)
            MetricRow(title: "Arm Extension", value: "\(Int(form.armExtensionScore))", score: form.compositeScore)
            MetricRow(title: "X-Factor", value: "\(Int(form.xFactor))°", score: form.compositeScore)
        }
    }

    private func speedMetricsDetail(_ speed: SpeedMetrics) -> some View {
        VStack(spacing: 12) {
            MetricRow(title: "Peak Speed", value: "\(Int(speed.peakSpeed)) mph", score: speed.compositeScore)
            MetricRow(title: "Impact Speed", value: "\(Int(speed.impactSpeed)) mph", score: speed.compositeScore)
            MetricRow(title: "Average Speed", value: "\(Int(speed.averageSpeed)) mph", score: speed.compositeScore)
            MetricRow(title: "Peak Acceleration", value: "\(Int(speed.peakAcceleration)) mph/s", score: speed.compositeScore)
            MetricRow(title: "Time to Peak", value: String(format: "%.2fs", speed.timeToPeakSpeed), score: speed.compositeScore)
        }
    }

    private func consistencyMetricsDetail(_ consistency: ConsistencyMetrics) -> some View {
        VStack(spacing: 12) {
            MetricRow(title: "Speed Variance", value: String(format: "%.1f mph", consistency.speedVariance), score: consistency.compositeScore)
            MetricRow(title: "Position Variance", value: String(format: "%.3f", consistency.positionVariance), score: consistency.compositeScore)
            MetricRow(title: "Repeatability", value: "\(Int(consistency.repeatabilityScore))", score: consistency.compositeScore)
            MetricRow(title: "Swings Analyzed", value: "\(consistency.swingCount)", score: consistency.compositeScore)
        }
    }

    // MARK: - Phase Analysis

    private var phaseAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Phase Analysis")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            VStack(spacing: 8) {
                PhaseRow(phase: "Setup", score: 88, color: .blue)
                PhaseRow(phase: "Backswing", score: 92, color: .yellow)
                PhaseRow(phase: "Downswing", score: 85, color: .orange)
                PhaseRow(phase: "Impact", score: 90, color: .red)
                PhaseRow(phase: "Follow Through", score: 87, color: .purple)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    // MARK: - Improvement Tips

    private var improvementTipsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Improvement Tips")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(viewModel.improvementTips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                            .font(.title3)

                        Text(tip)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    // MARK: - Actions

    private func saveSession() {
        viewModel.saveSession(to: modelContext)
    }

    private func shareResults() {
        // TODO: Implement sharing functionality
    }
}

// MARK: - Supporting Views

struct MetricRow: View {
    let title: String
    let value: String
    let score: Double

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

struct PhaseRow: View {
    let phase: String
    let score: Int
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)

            Text(phase)
                .font(.subheadline)

            Spacer()

            ProgressBar(value: Double(score) / 100.0, color: color)
                .frame(width: 100, height: 8)

            Text("\(score)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

struct ProgressBar: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(.systemGray5))

                Rectangle()
                    .fill(color)
                    .frame(width: geometry.size.width * value)
            }
            .clipShape(Capsule())
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: SwingSession.self, configurations: config)

    let mockMetrics = SwingMetrics(
        formMetrics: FormMetrics(
            hipRotationAngle: 75,
            shoulderRotationAngle: 95,
            spineAngleAtAddress: 35,
            spineAngleAtImpact: 38,
            weightTransferPercentage: 72,
            armExtensionScore: 85
        ),
        speedMetrics: SpeedMetrics(
            peakSpeed: 105,
            peakAcceleration: 1200,
            averageSpeed: 95,
            timeToPeakSpeed: 0.3,
            impactSpeed: 102
        )
    )

    let session = SwingSession(
        sport: .golf,
        metrics: mockMetrics,
        rating: Rating(score: mockMetrics.overallScore)
    )

    return AnalysisResultView(session: session)
        .modelContainer(container)
}
