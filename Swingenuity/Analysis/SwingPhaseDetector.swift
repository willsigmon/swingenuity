//
//  SwingPhaseDetector.swift
//  Swingenuity
//
//  Base protocol and implementation for swing phase detection
//

import Foundation
import Vision
import simd
import Observation

// BodyPose and BodyJoint are defined in BodyPoseAnalyzer.swift

// MARK: - Phase Transition

/// Represents a transition between swing phases
struct PhaseTransition: Identifiable, Codable {
    let id: UUID
    let fromPhase: SwingPhase?
    let toPhase: SwingPhase
    let timestamp: TimeInterval
    let confidence: Float

    init(from: SwingPhase?,
         to: SwingPhase,
         timestamp: TimeInterval,
         confidence: Float = 1.0) {
        self.id = UUID()
        self.fromPhase = from
        self.toPhase = to
        self.timestamp = timestamp
        self.confidence = confidence
    }
}

/// Complete swing analysis result
@Observable
final class SwingAnalysis {
    var currentPhase: SwingPhase
    var phaseStartTime: TimeInterval
    var transitions: [PhaseTransition]
    var confidence: Float

    init(currentPhase: SwingPhase = .setup,
         phaseStartTime: TimeInterval = 0,
         transitions: [PhaseTransition] = [],
         confidence: Float = 0) {
        self.currentPhase = currentPhase
        self.phaseStartTime = phaseStartTime
        self.transitions = transitions
        self.confidence = confidence
    }

    /// Duration of current phase
    func currentPhaseDuration(at timestamp: TimeInterval) -> TimeInterval {
        return timestamp - phaseStartTime
    }

    /// Get duration of a specific phase
    func phaseDuration(_ phase: SwingPhase) -> TimeInterval? {
        let phaseTransitions = transitions.filter { $0.toPhase == phase || $0.fromPhase == phase }
        guard phaseTransitions.count >= 2 else { return nil }

        let start = phaseTransitions.first(where: { $0.toPhase == phase })?.timestamp ?? 0
        let end = phaseTransitions.first(where: { $0.fromPhase == phase })?.timestamp ?? 0

        return end - start
    }

    /// Total swing duration
    var totalDuration: TimeInterval {
        guard let first = transitions.first, let last = transitions.last else { return 0 }
        return last.timestamp - first.timestamp
    }
}

// MARK: - Phase Detector Protocol

/// Protocol for sport-specific swing phase detectors
protocol SwingPhaseDetectorProtocol: AnyObject {
    /// Sport this detector is designed for
    var sport: Sport { get }

    /// Analyze current pose and update phase
    func detectPhase(pose: BodyPose, previousPoses: [BodyPose]) -> SwingAnalysis

    /// Reset detector state for new swing
    func reset()

    /// Minimum confidence threshold for phase transitions
    var minimumConfidence: Float { get set }
}

// MARK: - Base Detector Implementation

/// Base implementation with common utilities for all detectors
@Observable
class BaseSwingPhaseDetector: SwingPhaseDetectorProtocol {

    let sport: Sport
    var minimumConfidence: Float = 0.5

    // Current analysis state
    var currentAnalysis: SwingAnalysis

    // Pose history
    private var poseHistory: [BodyPose] = []
    private let maxHistoryLength = 30  // ~1 second at 30fps

    init(sport: Sport) {
        self.sport = sport
        self.currentAnalysis = SwingAnalysis()
    }

    // MARK: - Protocol Requirements

    func detectPhase(pose: BodyPose, previousPoses: [BodyPose]) -> SwingAnalysis {
        // Update history
        poseHistory.append(pose)
        if poseHistory.count > maxHistoryLength {
            poseHistory.removeFirst()
        }

        // Subclasses override this
        fatalError("Subclass must implement detectPhase()")
    }

    func reset() {
        poseHistory.removeAll()
        currentAnalysis = SwingAnalysis()
    }

    // MARK: - Helper Methods

    /// Record a phase transition
    func transitionToPhase(_ newPhase: SwingPhase,
                           at timestamp: TimeInterval,
                           confidence: Float = 1.0) {
        guard newPhase != currentAnalysis.currentPhase else { return }

        let transition = PhaseTransition(
            from: currentAnalysis.currentPhase,
            to: newPhase,
            timestamp: timestamp,
            confidence: confidence
        )

        currentAnalysis.transitions.append(transition)
        currentAnalysis.currentPhase = newPhase
        currentAnalysis.phaseStartTime = timestamp
    }

    /// Get hand position (average of both wrists)
    func handPosition(from pose: BodyPose) -> simd_float3? {
        guard let left = pose.joints[.leftWrist],
              let right = pose.joints[.rightWrist],
              left.isTracked || right.isTracked else {
            return nil
        }

        if left.isTracked && right.isTracked {
            return (left.position + right.position) / 2.0
        }
        return left.isTracked ? left.position : right.position
    }

    /// Get dominant hand position (right wrist for most players)
    func dominantHandPosition(from pose: BodyPose, isLeftHanded: Bool = false) -> simd_float3? {
        let jointName: VNHumanBodyPose3DObservation.JointName = isLeftHanded ? .leftWrist : .rightWrist
        return pose.joints[jointName]?.position
    }

    /// Check if player is in static/setup position
    func isStaticPosition(poses: [BodyPose], threshold: Float = 0.1) -> Bool {
        guard poses.count >= 10 else { return false }

        let recentPoses = Array(poses.suffix(10))
        guard let firstHand = handPosition(from: recentPoses[0]) else { return false }

        // Check if hand movement is minimal
        for pose in recentPoses {
            guard let hand = handPosition(from: pose) else { return false }
            if simd_distance(hand, firstHand) > threshold {
                return false
            }
        }

        return true
    }

    /// Calculate hand speed
    func handSpeed(current: BodyPose, previous: BodyPose) -> Float? {
        guard let velocity = current.velocity(of: .rightWrist, from: previous) ??
                             current.velocity(of: .leftWrist, from: previous) else {
            return nil
        }
        return simd_length(velocity)
    }

    /// Get hip rotation angle (relative to shoulders)
    func hipRotation(from pose: BodyPose) -> Float? {
        guard let leftHip = pose.joints[.leftHip],
              let rightHip = pose.joints[.rightHip],
              let leftShoulder = pose.joints[.leftShoulder],
              let rightShoulder = pose.joints[.rightShoulder],
              leftHip.isTracked, rightHip.isTracked,
              leftShoulder.isTracked, rightShoulder.isTracked else {
            return nil
        }

        // Hip line vector
        let hipVector = rightHip.position - leftHip.position
        // Shoulder line vector
        let shoulderVector = rightShoulder.position - leftShoulder.position

        // Project to horizontal plane (ignore Y)
        let hipVec2D = simd_float2(hipVector.x, hipVector.z)
        let shoulderVec2D = simd_float2(shoulderVector.x, shoulderVector.z)

        let dot = simd_dot(hipVec2D, shoulderVec2D)
        let mag1 = simd_length(hipVec2D)
        let mag2 = simd_length(shoulderVec2D)

        guard mag1 > 0, mag2 > 0 else { return nil }

        let cosAngle = dot / (mag1 * mag2)
        return acos(simd_clamp(cosAngle, -1.0, 1.0))
    }

    /// Get shoulder rotation relative to hips
    func shoulderRotation(from pose: BodyPose) -> Float? {
        guard let leftShoulder = pose.joints[.leftShoulder],
              let rightShoulder = pose.joints[.rightShoulder],
              leftShoulder.isTracked, rightShoulder.isTracked else {
            return nil
        }

        let shoulderLine = rightShoulder.position - leftShoulder.position
        // Angle from horizontal
        let horizontal = simd_float3(1, 0, 0)
        let projected = simd_float3(shoulderLine.x, 0, shoulderLine.z)

        let dot = simd_dot(projected, horizontal)
        let mag = simd_length(projected)

        guard mag > 0 else { return nil }

        return acos(simd_clamp(dot / mag, -1.0, 1.0))
    }

    /// Detect if hands are above shoulders (high backswing)
    func handsAboveShoulders(from pose: BodyPose) -> Bool {
        guard let handPos = handPosition(from: pose),
              let leftShoulder = pose.joints[.leftShoulder],
              let rightShoulder = pose.joints[.rightShoulder],
              leftShoulder.isTracked, rightShoulder.isTracked else {
            return false
        }

        let shoulderHeight = (leftShoulder.position.y + rightShoulder.position.y) / 2.0
        return handPos.y > shoulderHeight + 0.1  // 10cm above shoulders
    }

    /// Get pose history window
    func getRecentPoses(count: Int) -> [BodyPose] {
        guard count > 0 else { return [] }
        let start = max(0, poseHistory.count - count)
        return Array(poseHistory[start...])
    }
}
