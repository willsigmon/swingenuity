//
//  BaseballPhaseDetector.swift
//  Swingenuity
//
//  Baseball and softball swing phase detection
//

import Foundation
import Vision
import simd

/// Baseball/Softball swing phase detector
@Observable
final class BaseballPhaseDetector: BaseSwingPhaseDetector {

    // Configuration
    var isLeftHanded: Bool = false
    var battingSide: BattingSide

    // Detection thresholds
    private let stanceStabilityFrames = 15
    private let loadSpeedThreshold: Float = 1.2
    private let swingSpeedThreshold: Float = 4.0
    private let contactSpeedThreshold: Float = 7.0  // Baseball swings are fast!

    // State tracking
    private var stanceConfirmed = false
    private var loadDepth: Float = 0  // Max backward hand position
    private var hipRotationAtLoad: Float = 0

    enum BattingSide {
        case right
        case left

        var displayName: String {
            self == .right ? "Right" : "Left"
        }
    }

    init(sport: Sport = .baseball, battingSide: BattingSide = .right) {
        assert(sport == .baseball || sport == .softball, "BaseballPhaseDetector only supports baseball and softball")
        self.battingSide = battingSide
        self.isLeftHanded = battingSide == .left
        super.init(sport: sport)
    }

    // MARK: - Phase Detection

    override func detectPhase(pose: BodyPose, previousPoses: [BodyPose]) -> SwingAnalysis {
        // Update history
        _ = super.detectPhase(pose: pose, previousPoses: previousPoses)

        let allPoses = getRecentPoses(count: 30)
        guard !allPoses.isEmpty else { return currentAnalysis }

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
        stanceConfirmed = false
        loadDepth = 0
        hipRotationAtLoad = 0
    }

    // MARK: - Phase Transitions

    private func detectSetupToBackswing(pose: BodyPose, history: [BodyPose]) {
        // Confirm batting stance
        if !stanceConfirmed {
            if isInBattingStance(pose: pose, history: history) {
                stanceConfirmed = true
            }
            return
        }

        // Detect load phase initiation (weight shift backward)
        guard let handPos = handPosition(from: pose),
              history.count >= 2 else { return }

        let previousPose = history[history.count - 2]
        guard let prevHandPos = handPosition(from: previousPose) else { return }

        guard let speed = handSpeed(current: pose, previous: previousPose) else { return }

        // Load: hands move backward and slightly up
        let movement = handPos - prevHandPos

        // Backward movement depends on batting side
        let movingBack: Bool
        if battingSide == .right {
            // Right-handed: hands move toward right (positive x)
            movingBack = movement.x > 0.015
        } else {
            // Left-handed: hands move toward left (negative x)
            movingBack = movement.x < -0.015
        }

        let movingUp = movement.y > 0.01

        if movingBack && movingUp && speed > loadSpeedThreshold {
            transitionToPhase(.backswing, at: pose.timestamp, confidence: pose.overallConfidence)
            loadDepth = handPos.x
        }
    }

    private func detectBackswingToTransition(pose: BodyPose, history: [BodyPose]) {
        guard let handPos = handPosition(from: pose) else { return }

        // Track maximum load depth
        if battingSide == .right {
            loadDepth = max(loadDepth, handPos.x)
        } else {
            loadDepth = min(loadDepth, handPos.x)
        }

        // Store hip rotation at load
        if let rotation = hipRotation(from: pose) {
            hipRotationAtLoad = rotation
        }

        // Detect peak of load (hands stop moving back, hips begin to open)
        guard history.count >= 3 else { return }
        let recent = Array(history.suffix(3))

        guard let h1 = handPosition(from: recent[0]),
              let h2 = handPosition(from: recent[1]),
              let h3 = handPosition(from: recent[2]) else { return }

        // Check for load completion and reversal
        let loadingPhase: Bool
        let unloadingPhase: Bool

        if battingSide == .right {
            loadingPhase = h2.x > h1.x
            unloadingPhase = h3.x < h2.x
        } else {
            loadingPhase = h2.x < h1.x
            unloadingPhase = h3.x > h2.x
        }

        if loadingPhase && unloadingPhase {
            // Additional check: front foot should be planted
            if isFrontFootPlanted(pose: pose) {
                transitionToPhase(.transition, at: pose.timestamp, confidence: pose.overallConfidence)
            }
        }
    }

    private func detectTransitionToDownswing(pose: BodyPose, history: [BodyPose]) {
        guard history.count >= 2 else { return }
        let previousPose = history[history.count - 2]

        guard let speed = handSpeed(current: pose, previous: previousPose) else { return }

        // Swing initiated with rapid acceleration
        if speed > swingSpeedThreshold {
            guard let handPos = handPosition(from: pose),
                  let prevHandPos = handPosition(from: previousPose) else { return }

            let movement = handPos - prevHandPos

            // Hands moving forward and down toward contact zone
            let movingForward: Bool
            if battingSide == .right {
                // Right-handed: hands move left (negative x)
                movingForward = movement.x < -0.02
            } else {
                // Left-handed: hands move right (positive x)
                movingForward = movement.x > 0.02
            }

            // Check hip rotation (hips should be opening)
            if movingForward && isHipsOpening(current: pose, previous: previousPose) {
                transitionToPhase(.downswing, at: pose.timestamp, confidence: pose.overallConfidence)
            }
        }
    }

    private func detectDownswingToImpact(pose: BodyPose, history: [BodyPose]) {
        guard history.count >= 2 else { return }
        let previousPose = history[history.count - 2]

        guard let speed = handSpeed(current: pose, previous: previousPose) else { return }

        // Contact zone: maximum bat speed + proper contact position
        if speed > contactSpeedThreshold {
            guard let handPos = handPosition(from: pose) else { return }

            // Check if in contact zone (in front of plate)
            if isInContactZone(handPos: handPos, pose: pose) {
                transitionToPhase(.impact, at: pose.timestamp, confidence: pose.overallConfidence)
            }
        }
    }

    private func detectImpactToFollowThrough(pose: BodyPose, history: [BodyPose]) {
        guard history.count >= 2 else { return }
        let previousPose = history[history.count - 2]

        guard let speed = handSpeed(current: pose, previous: previousPose) else { return }

        // Follow-through begins after contact, speed decreases
        if speed < contactSpeedThreshold * 0.8 {
            guard let handPos = handPosition(from: pose),
                  let prevHandPos = handPosition(from: previousPose) else { return }

            // Hands continue around the body
            let movement = handPos - prevHandPos
            let continuingRotation = abs(movement.x) > 0.01 || abs(movement.y) > 0.01

            if continuingRotation {
                transitionToPhase(.followThrough, at: pose.timestamp, confidence: pose.overallConfidence)
            }
        }
    }

    private func detectFollowThroughComplete(pose: BodyPose, history: [BodyPose]) {
        // Follow-through completes when hands wrap around and stabilize
        guard let handPos = handPosition(from: pose) else { return }

        // Check if hands have completed rotation (opposite side from start)
        let completedRotation: Bool
        if battingSide == .right {
            // Right-handed: hands end on left side
            completedRotation = handPos.x < -0.2
        } else {
            // Left-handed: hands end on right side
            completedRotation = handPos.x > 0.2
        }

        if completedRotation {
            let recent = getRecentPoses(count: 10)
            if isStaticPosition(poses: recent, threshold: 0.15) {
                // Swing complete
            }
        }
    }

    // MARK: - Helper Methods

    private func isInBattingStance(pose: BodyPose, history: [BodyPose]) -> Bool {
        // Check for stable stance position
        guard isStaticPosition(poses: history, threshold: 0.05) else { return false }

        // Verify proper stance characteristics
        guard let leftFoot = pose.joints[.leftAnkle],
              let rightFoot = pose.joints[.rightAnkle],
              let hips = pose.joints[.leftHip] ?? pose.joints[.rightHip],
              leftFoot.isTracked, rightFoot.isTracked, hips.isTracked else {
            return false
        }

        // Feet should be apart (shoulder width or more)
        let feetDistance = simd_distance(leftFoot.position, rightFoot.position)
        let properStance = feetDistance > 0.4  // ~40cm apart

        // Weight should be balanced
        let weightCentered = abs(leftFoot.position.y - rightFoot.position.y) < 0.05

        return properStance && weightCentered
    }

    private func isFrontFootPlanted(pose: BodyPose) -> Bool {
        // Front foot depends on batting side
        let frontFoot: VNHumanBodyPose3DObservation.JointName = battingSide == .right ? .leftAnkle : .rightAnkle

        guard let foot = pose.joints[frontFoot], foot.isTracked else { return false }

        // Check if foot is on ground (low y position)
        return foot.position.y < 0.1
    }

    private func isHipsOpening(current: BodyPose, previous: BodyPose) -> Bool {
        guard let currentRotation = hipRotation(from: current),
              let previousRotation = hipRotation(from: previous) else {
            return false
        }

        // Hips should be rotating (opening up)
        return currentRotation > previousRotation + 0.05  // ~3 degrees
    }

    private func isInContactZone(handPos: simd_float3, pose: BodyPose) -> Bool {
        guard let hips = pose.joints[.leftHip] ?? pose.joints[.rightHip] else { return false }

        // Contact zone: waist to chest height, in front of body
        let contactHeight = hips.position.y + 0.4  // ~40cm above hips (waist/belt)
        let heightDiff = abs(handPos.y - contactHeight)

        let inHeightRange = heightDiff < 0.3  // 30cm window

        // Hands should be in front of body
        let inFrontOfBody = handPos.z > hips.position.z + 0.1

        return inHeightRange && inFrontOfBody
    }

    // MARK: - Baseball-Specific Analysis

    /// Detect if batter has proper batting stance
    func hasProperStance(pose: BodyPose) -> Bool {
        return isInBattingStance(pose: pose, history: getRecentPoses(count: 10))
    }

    /// Calculate stride length (front foot movement)
    func strideLength(from startPose: BodyPose, to endPose: BodyPose) -> Float? {
        let frontFoot: VNHumanBodyPose3DObservation.JointName = battingSide == .right ? .leftAnkle : .rightAnkle

        guard let start = startPose.joints[frontFoot],
              let end = endPose.joints[frontFoot],
              start.isTracked, end.isTracked else {
            return nil
        }

        return simd_distance(start.position, end.position)
    }

    /// Get hip-shoulder separation angle (X-factor)
    func hipShoulderSeparation(pose: BodyPose) -> Float? {
        guard let hipRot = hipRotation(from: pose),
              let shoulderRot = shoulderRotation(from: pose) else {
            return nil
        }

        return abs(shoulderRot - hipRot)
    }

    /// Calculate bat speed at contact (estimated from hand speed)
    func batSpeedAtContact() -> Float? {
        // Impact transition
        let impactTransition = currentAnalysis.transitions.first { $0.toPhase == .impact }

        // Would need to store hand speed at transition
        // Bat speed ≈ hand speed × 1.5 (lever arm effect)
        return nil
    }

    /// Get swing plane angle
    func swingPlaneAngle() -> Float? {
        // Would need to track hand path through swing
        // Calculate angle from horizontal
        return nil
    }
}
