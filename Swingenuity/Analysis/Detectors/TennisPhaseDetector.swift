//
//  TennisPhaseDetector.swift
//  Swingenuity
//
//  Tennis and pickleball swing phase detection
//

import Foundation
import Vision
import simd

/// Tennis/Pickleball swing phase detector
@Observable
final class TennisPhaseDetector: BaseSwingPhaseDetector {

    // Configuration
    var isLeftHanded: Bool = false
    var strokeType: StrokeType = .forehand

    // Detection thresholds (adjusted for tennis vs pickleball)
    private var preparationSpeedThreshold: Float { self.sport == .tennis ? 1.5 : 1.0 }
    private var swingSpeedThreshold: Float { self.sport == .tennis ? 4.0 : 3.0 }
    private var contactSpeedThreshold: Float { self.sport == .tennis ? 6.0 : 4.5 }

    // State tracking
    private var readyPositionConfirmed = false
    private var maxReachHeight: Float = 0
    private var strokeInitiationTime: TimeInterval?

    enum StrokeType {
        case forehand
        case backhand
        case serve
        case volley
        case overhead

        var displayName: String {
            switch self {
            case .forehand: return "Forehand"
            case .backhand: return "Backhand"
            case .serve: return "Serve"
            case .volley: return "Volley"
            case .overhead: return "Overhead"
            }
        }
    }

    init(sport: Sport = .tennis, isLeftHanded: Bool = false) {
        assert(sport == .tennis || sport == .pickleball, "TennisPhaseDetector only supports tennis and pickleball")
        self.isLeftHanded = isLeftHanded
        super.init(sport: sport)
    }

    // MARK: - Phase Detection

    override func detectPhase(pose: BodyPose, previousPoses: [BodyPose]) -> SwingAnalysis {
        // Update history
        _ = super.detectPhase(pose: pose, previousPoses: previousPoses)

        let allPoses = getRecentPoses(count: 30)
        guard !allPoses.isEmpty else { return currentAnalysis }

        // Detect stroke type if in setup
        if currentAnalysis.currentPhase == .setup {
            strokeType = detectStrokeType(pose: pose, history: allPoses)
        }

        switch currentAnalysis.currentPhase {
        case .setup:
            detectSetupToBackswing(pose: pose, history: allPoses)

        case .backswing:
            detectBackswingToTransition(pose: pose, history: allPoses)

        case .transition:
            detectTransitionToDownswing(pose: pose, history: allPoses)

        case .downswing:
            detectDownswingToImpact(pose: pose, history: allPoses)

        case .impact:
            detectImpactToFollowThrough(pose: pose, history: allPoses)

        case .followThrough:
            detectFollowThroughComplete(pose: pose, history: allPoses)
        }

        currentAnalysis.confidence = pose.overallConfidence
        return currentAnalysis
    }

    override func reset() {
        super.reset()
        readyPositionConfirmed = false
        maxReachHeight = 0
        strokeInitiationTime = nil
    }

    // MARK: - Stroke Type Detection

    private func detectStrokeType(pose: BodyPose, history: [BodyPose]) -> StrokeType {
        guard let dominantHand = dominantHandPosition(from: pose, isLeftHanded: isLeftHanded),
              let shoulders = pose.joints[.leftShoulder],
              shoulders.isTracked else {
            return .forehand
        }

        // Serve: hand above head
        if dominantHand.y > shoulders.position.y + 0.4 {
            return .serve
        }

        // Check hand position relative to body centerline
        let bodyCenter = calculateBodyCenter(from: pose)
        let handOffset = dominantHand.x - bodyCenter.x

        // Forehand: dominant hand on dominant side
        // Backhand: dominant hand crosses body
        if isLeftHanded {
            return handOffset < -0.1 ? .forehand : .backhand
        } else {
            return handOffset > 0.1 ? .forehand : .backhand
        }
    }

    // MARK: - Phase Transitions

    private func detectSetupToBackswing(pose: BodyPose, history: [BodyPose]) {
        // Confirm ready position
        if !readyPositionConfirmed {
            if isStaticPosition(poses: history, threshold: 0.08) {
                readyPositionConfirmed = true
            }
            return
        }

        // Detect preparation phase initiation
        guard let handPos = dominantHandPosition(from: pose, isLeftHanded: isLeftHanded),
              history.count >= 2 else { return }

        let previousPose = history[history.count - 2]
        guard let prevHandPos = dominantHandPosition(from: previousPose, isLeftHanded: isLeftHanded) else { return }

        guard let speed = handSpeed(current: pose, previous: previousPose) else { return }

        // Backswing starts with hand moving backward
        let movement = handPos - prevHandPos

        if strokeType == .serve {
            // Serve: upward motion
            if movement.y > 0.02 && speed > preparationSpeedThreshold {
                transitionToPhase(.backswing, at: pose.timestamp, confidence: pose.overallConfidence)
                maxReachHeight = handPos.y
                strokeInitiationTime = pose.timestamp
            }
        } else {
            // Groundstrokes: backward rotation
            let movingBack = (isLeftHanded && movement.x > 0.02) || (!isLeftHanded && movement.x < -0.02)

            if movingBack && speed > preparationSpeedThreshold {
                transitionToPhase(.backswing, at: pose.timestamp, confidence: pose.overallConfidence)
                strokeInitiationTime = pose.timestamp
            }
        }
    }

    private func detectBackswingToTransition(pose: BodyPose, history: [BodyPose]) {
        guard let handPos = dominantHandPosition(from: pose, isLeftHanded: isLeftHanded) else { return }

        if strokeType == .serve {
            // Track max reach height
            if handPos.y > maxReachHeight {
                maxReachHeight = handPos.y
            }
        }

        // Detect peak of preparation (direction reversal)
        guard history.count >= 3 else { return }
        let recent = Array(history.suffix(3))

        guard let h1 = dominantHandPosition(from: recent[0], isLeftHanded: isLeftHanded),
              let h2 = dominantHandPosition(from: recent[1], isLeftHanded: isLeftHanded),
              let h3 = dominantHandPosition(from: recent[2], isLeftHanded: isLeftHanded) else { return }

        if strokeType == .serve {
            // Serve: detect peak height
            let wasRising = h2.y > h1.y
            let nowFalling = h3.y < h2.y

            if wasRising && nowFalling && handPos.y > maxReachHeight - 0.05 {
                transitionToPhase(.transition, at: pose.timestamp, confidence: pose.overallConfidence)
            }
        } else {
            // Groundstrokes: detect forward motion start
            let backwardDist1 = isLeftHanded ? h2.x - h1.x : h1.x - h2.x
            let forwardDist2 = isLeftHanded ? h2.x - h3.x : h3.x - h2.x

            if backwardDist1 > 0 && forwardDist2 > 0 {
                transitionToPhase(.transition, at: pose.timestamp, confidence: pose.overallConfidence)
            }
        }
    }

    private func detectTransitionToDownswing(pose: BodyPose, history: [BodyPose]) {
        guard history.count >= 2 else { return }
        let previousPose = history[history.count - 2]

        guard let speed = handSpeed(current: pose, previous: previousPose) else { return }

        // Forward swing initiated with acceleration
        if speed > swingSpeedThreshold {
            guard let handPos = dominantHandPosition(from: pose, isLeftHanded: isLeftHanded),
                  let prevHandPos = dominantHandPosition(from: previousPose, isLeftHanded: isLeftHanded) else { return }

            let movement = handPos - prevHandPos

            if strokeType == .serve {
                // Serve: downward and forward
                if movement.y < -0.01 {
                    transitionToPhase(.downswing, at: pose.timestamp, confidence: pose.overallConfidence)
                }
            } else {
                // Groundstrokes: forward toward contact
                let movingForward = (isLeftHanded && movement.x < -0.01) || (!isLeftHanded && movement.x > 0.01)

                if movingForward {
                    transitionToPhase(.downswing, at: pose.timestamp, confidence: pose.overallConfidence)
                }
            }
        }
    }

    private func detectDownswingToImpact(pose: BodyPose, history: [BodyPose]) {
        guard history.count >= 2 else { return }
        let previousPose = history[history.count - 2]

        guard let speed = handSpeed(current: pose, previous: previousPose) else { return }

        // Impact: maximum speed + proper contact zone
        if speed > contactSpeedThreshold {
            guard let handPos = dominantHandPosition(from: pose, isLeftHanded: isLeftHanded) else { return }

            // Check if in contact zone
            if isInContactZone(handPos: handPos, pose: pose) {
                transitionToPhase(.impact, at: pose.timestamp, confidence: pose.overallConfidence)
            }
        }
    }

    private func detectImpactToFollowThrough(pose: BodyPose, history: [BodyPose]) {
        guard history.count >= 2 else { return }
        let previousPose = history[history.count - 2]

        guard let speed = handSpeed(current: pose, previous: previousPose) else { return }

        // Follow-through: deceleration after contact
        if speed < contactSpeedThreshold * 0.7 {
            transitionToPhase(.followThrough, at: pose.timestamp, confidence: pose.overallConfidence)
        }
    }

    private func detectFollowThroughComplete(pose: BodyPose, history: [BodyPose]) {
        // Follow-through completes when hand stabilizes
        let recent = getRecentPoses(count: 10)

        if isStaticPosition(poses: recent, threshold: 0.12) {
            // Stroke complete - ready for next shot
        }
    }

    // MARK: - Helper Methods

    private func calculateBodyCenter(from pose: BodyPose) -> simd_float3 {
        guard let leftHip = pose.joints[.leftHip],
              let rightHip = pose.joints[.rightHip],
              leftHip.isTracked, rightHip.isTracked else {
            return .zero
        }

        return (leftHip.position + rightHip.position) / 2.0
    }

    private func isInContactZone(handPos: simd_float3, pose: BodyPose) -> Bool {
        guard let shoulders = pose.joints[isLeftHanded ? .leftShoulder : .rightShoulder],
              shoulders.isTracked else {
            return false
        }

        if strokeType == .serve {
            // Serve contact: above head, extended
            return handPos.y > shoulders.position.y + 0.3
        } else {
            // Groundstroke contact: between waist and shoulders, in front of body
            guard let hips = pose.joints[.leftHip] ?? pose.joints[.rightHip] else { return false }

            let waistHeight = hips.position.y + 0.3
            let shoulderHeight = shoulders.position.y

            let inHeightRange = handPos.y > waistHeight && handPos.y < shoulderHeight + 0.2

            // Check if hand is in front of body
            let bodyCenter = calculateBodyCenter(from: pose)
            let inFrontOfBody = abs(handPos.z - bodyCenter.z) > 0.2

            return inHeightRange && inFrontOfBody
        }
    }

    // MARK: - Tennis-Specific Analysis

    /// Detect if player is in ready position
    func isInReadyPosition(pose: BodyPose) -> Bool {
        guard let leftHand = pose.joints[.leftWrist],
              let rightHand = pose.joints[.rightWrist],
              leftHand.isTracked, rightHand.isTracked else {
            return false
        }

        // Ready position: both hands in front, similar height
        let heightDiff = abs(leftHand.position.y - rightHand.position.y)
        let handsLevel = heightDiff < 0.15

        guard let bodyCenter = calculateBodyCenter(from: pose) as simd_float3? else { return false }
        let bothInFront = leftHand.position.z > bodyCenter.z && rightHand.position.z > bodyCenter.z

        return handsLevel && bothInFront
    }

    /// Calculate swing path length
    func swingPathLength() -> Float? {
        // Would need to track hand positions through swing
        // Simplified version
        return nil
    }

    /// Get racquet speed at contact (estimated from hand speed)
    func racquetSpeedAtContact() -> Float? {
        let impactTransition = currentAnalysis.transitions.first { $0.toPhase == .impact }
        // Would need to store speed at transition
        return nil
    }
}
