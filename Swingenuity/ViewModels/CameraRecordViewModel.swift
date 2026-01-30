import Foundation
import AVFoundation
import Observation

@Observable
final class CameraRecordViewModel {
    // MARK: - Published State
    var selectedSport: Sport = .golf
    var isRecording = false
    var recordingPhase: RecordingPhase = .idle
    var currentJointFrame: JointPositionFrame?
    var recordedFrames: [JointPositionFrame] = []
    var showMetricsOverlay = false
    var currentMetrics: LiveMetrics?
    var errorMessage: String?

    // MARK: - Recording State
    private(set) var recordingStartTime: Date?
    private(set) var recordingDuration: TimeInterval = 0

    // MARK: - Actions

    func startRecording() {
        guard !isRecording else { return }

        isRecording = true
        recordingStartTime = Date()
        recordingPhase = .setup
        recordedFrames.removeAll()
        errorMessage = nil
    }

    func stopRecording() {
        guard isRecording else { return }

        isRecording = false
        recordingPhase = .idle

        if let startTime = recordingStartTime {
            recordingDuration = Date().timeIntervalSince(startTime)
        }
        recordingStartTime = nil
    }

    func updatePhase(_ phase: RecordingPhase) {
        recordingPhase = phase
    }

    func addJointFrame(_ frame: JointPositionFrame) {
        currentJointFrame = frame
        if isRecording {
            recordedFrames.append(frame)
        }
    }

    func updateLiveMetrics(_ metrics: LiveMetrics) {
        currentMetrics = metrics
    }

    func toggleMetricsOverlay() {
        showMetricsOverlay.toggle()
    }

    func reset() {
        isRecording = false
        recordingPhase = .idle
        currentJointFrame = nil
        recordedFrames.removeAll()
        currentMetrics = nil
        recordingStartTime = nil
        recordingDuration = 0
        errorMessage = nil
    }
}

// MARK: - Supporting Types

enum RecordingPhase: String, Codable {
    case idle = "Ready"
    case setup = "Setup"
    case backswing = "Backswing"
    case downswing = "Downswing"
    case impact = "Impact"
    case followThrough = "Follow Through"
    case complete = "Complete"

    var displayName: String {
        rawValue
    }

    var color: String {
        switch self {
        case .idle: return "gray"
        case .setup: return "blue"
        case .backswing: return "yellow"
        case .downswing: return "orange"
        case .impact: return "red"
        case .followThrough: return "purple"
        case .complete: return "green"
        }
    }
}

struct LiveMetrics {
    var currentSpeed: Double
    var currentAngle: Double
    var confidence: Float

    init(currentSpeed: Double = 0, currentAngle: Double = 0, confidence: Float = 0) {
        self.currentSpeed = currentSpeed
        self.currentAngle = currentAngle
        self.confidence = confidence
    }
}
