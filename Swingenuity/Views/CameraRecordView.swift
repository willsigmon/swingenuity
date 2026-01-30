import SwiftUI
import AVFoundation

struct CameraRecordView: View {
    @State private var viewModel = CameraRecordViewModel()
    @State private var showingSportSelector = false
    @State private var showingAnalysisResult = false
    @State private var analyzedSession: SwingSession?

    var body: some View {
        ZStack {
            // Camera Preview (Placeholder)
            CameraPreviewPlaceholder()

            // Skeleton Overlay
            if let frame = viewModel.currentJointFrame {
                SkeletonOverlayView(frame: frame)
            }

            // Main UI Overlay
            VStack {
                // Top Bar
                HStack {
                    // Sport Selector Button
                    Button(action: {
                        showingSportSelector = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: viewModel.selectedSport.symbolName)
                            Text(viewModel.selectedSport.displayName)
                                .font(.headline)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }

                    Spacer()

                    // Metrics Toggle
                    Button(action: {
                        viewModel.toggleMetricsOverlay()
                    }) {
                        Image(systemName: viewModel.showMetricsOverlay ? "chart.bar.fill" : "chart.bar")
                            .font(.title2)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding()

                Spacer()

                // Phase Indicator
                if viewModel.isRecording {
                    PhaseIndicatorView(phase: viewModel.recordingPhase)
                        .padding(.bottom, 20)
                }

                // Metrics Overlay
                if viewModel.showMetricsOverlay, let metrics = viewModel.currentMetrics {
                    MetricsDisplayView(metrics: metrics, sport: viewModel.selectedSport)
                        .padding(.bottom, 20)
                }

                // Record Button
                RecordButton(
                    isRecording: viewModel.isRecording,
                    action: {
                        if viewModel.isRecording {
                            viewModel.stopRecording()
                            processRecording()
                        } else {
                            viewModel.startRecording()
                        }
                    }
                )
                .padding(.bottom, 50)
            }

            // Error Message
            if let error = viewModel.errorMessage {
                VStack {
                    Spacer()
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.white)
                        .padding()
                        .background(.red.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding()
                }
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showingSportSelector) {
            SportSelectorView(selectedSport: $viewModel.selectedSport)
        }
        .fullScreenCover(item: $analyzedSession) { session in
            AnalysisResultView(session: session)
        }
    }

    private func processRecording() {
        // TODO: Integrate with ML analysis service
        // For now, create a mock session
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
            sport: viewModel.selectedSport,
            jointFrames: viewModel.recordedFrames,
            metrics: mockMetrics,
            rating: Rating(score: mockMetrics.overallScore)
        )

        analyzedSession = session
    }
}

// MARK: - Camera Preview Placeholder

struct CameraPreviewPlaceholder: View {
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.black, .gray.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                VStack(spacing: 16) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("Camera Preview")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
    }
}

// MARK: - Record Button

struct RecordButton: View {
    let isRecording: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(lineWidth: 5)
                    .foregroundStyle(.white)
                    .frame(width: 80, height: 80)

                if isRecording {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.red)
                        .frame(width: 35, height: 35)
                } else {
                    Circle()
                        .fill(.red)
                        .frame(width: 65, height: 65)
                }
            }
        }
    }
}

// MARK: - Phase Indicator

struct PhaseIndicatorView: View {
    let phase: RecordingPhase

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(colorForPhase(phase))
                .frame(width: 12, height: 12)

            Text(phase.displayName)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    private func colorForPhase(_ phase: RecordingPhase) -> Color {
        switch phase.color {
        case "gray": return .gray
        case "blue": return .blue
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        case "green": return .green
        default: return .white
        }
    }
}

#Preview {
    CameraRecordView()
}
