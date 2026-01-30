import Foundation
import SwiftData
import Observation

@Observable
final class AnalysisResultViewModel {
    // MARK: - State
    var swingSession: SwingSession
    var isPlaying = false
    var currentFrameIndex = 0
    var playbackSpeed: Double = 1.0
    var showingImprovementTips = false
    var selectedMetricCategory: MetricCategory = .form

    // MARK: - Computed Properties

    var currentFrame: JointPositionFrame? {
        guard currentFrameIndex < swingSession.jointFrames.count else { return nil }
        return swingSession.jointFrames[currentFrameIndex]
    }

    var progressPercentage: Double {
        guard !swingSession.jointFrames.isEmpty else { return 0 }
        return Double(currentFrameIndex) / Double(swingSession.jointFrames.count)
    }

    var improvementTips: [String] {
        generateImprovementTips()
    }

    // MARK: - Initialization

    init(swingSession: SwingSession) {
        self.swingSession = swingSession
    }

    // MARK: - Actions

    func togglePlayback() {
        isPlaying.toggle()
    }

    func seekTo(frameIndex: Int) {
        currentFrameIndex = min(max(0, frameIndex), swingSession.jointFrames.count - 1)
    }

    func seekToPercentage(_ percentage: Double) {
        let targetIndex = Int(Double(swingSession.jointFrames.count) * percentage)
        seekTo(frameIndex: targetIndex)
    }

    func nextFrame() {
        if currentFrameIndex < swingSession.jointFrames.count - 1 {
            currentFrameIndex += 1
        }
    }

    func previousFrame() {
        if currentFrameIndex > 0 {
            currentFrameIndex -= 1
        }
    }

    func resetPlayback() {
        currentFrameIndex = 0
        isPlaying = false
    }

    func saveSession(to modelContext: ModelContext) {
        modelContext.insert(swingSession)
        try? modelContext.save()
    }

    // MARK: - Private Helpers

    private func generateImprovementTips() -> [String] {
        var tips: [String] = []

        guard let metrics = swingSession.metrics else {
            return ["Complete your swing analysis to get improvement tips."]
        }

        // Form-based tips
        if metrics.formMetrics.hipRotationAngle < 45 {
            tips.append("Increase hip rotation to generate more power.")
        }

        if metrics.formMetrics.shoulderRotationAngle < 90 {
            tips.append("Focus on a fuller shoulder turn for better coil.")
        }

        if metrics.formMetrics.weightTransferPercentage < 60 {
            tips.append("Improve weight transfer to your front foot for more consistency.")
        }

        if metrics.formMetrics.armExtensionScore < 70 {
            tips.append("Maintain arm extension through impact for better accuracy.")
        }

        // Speed-based tips
        if metrics.speedMetrics.peakSpeed < 80 {
            tips.append("Work on acceleration through the ball to increase club speed.")
        }

        let speedEfficiency = metrics.speedMetrics.peakSpeed > 0 ?
            (metrics.speedMetrics.impactSpeed / metrics.speedMetrics.peakSpeed) * 100 : 0

        if speedEfficiency < 90 {
            tips.append("Focus on maintaining speed through impact.")
        }

        // Consistency tips
        if let consistency = metrics.consistencyMetrics {
            if consistency.speedVariance > 5 {
                tips.append("Practice tempo drills to improve speed consistency.")
            }

            if consistency.repeatabilityScore < 70 {
                tips.append("Focus on repeating your setup position and swing path.")
            }
        }

        if tips.isEmpty {
            tips.append("Great swing! Keep practicing to maintain this form.")
        }

        return tips
    }
}

// MARK: - Supporting Types

enum MetricCategory: String, CaseIterable {
    case form = "Form"
    case speed = "Speed"
    case consistency = "Consistency"

    var icon: String {
        switch self {
        case .form: return "figure.stand"
        case .speed: return "speedometer"
        case .consistency: return "chart.line.uptrend.xyaxis"
        }
    }
}
