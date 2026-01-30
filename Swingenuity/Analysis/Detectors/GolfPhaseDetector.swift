//
//  GolfPhaseDetector.swift
//  Swingenuity
//
//  Golf-specific swing phase detection
//

import Foundation
import Vision
import simd

/// Golf swing phase detector
@Observable
final class GolfPhaseDetector: BaseSwingPhaseDetector {

    // Golf-specific configuration
    var isLeftHanded: Bool = false
    var clubType: ClubType = .driver

    // Detection thresholds
    private let addressStabilityFrames = 10  // Frames to confirm address
    private let backswingSpeedThreshold: Float = 1.0  // m/s
    private let downswingSpeedThreshold: Float = 3.0  // m/s
    private let impactSpeedThreshold: Float = 5.0     // m/s

    // State tracking
    private var addressConfirmed = false
    private var backswingPeakHeight: Float = 0
    private var transitionTime: TimeInterval?

    enum ClubType {
        case driver
        case iron
        case wedge
        case putter
    }

    init(isLeftHanded: Bool = false, clubType: ClubType = .driver) {
        self.isLeftHanded = isLeftHanded
        self.clubType = clubType
        super.init(sport: .golf)
    }

    // MARK: - Phase Detection

    override func detectPhase(pose: BodyPose, previousPoses: [BodyPose]) -> SwingAnalysis {
        // Call super to update history
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
        addressConfirmed = false
        backswingPeakHeight = 0
        transitionTime = nil
    }

    // MARK: - Phase Transition Detection

    private func detectSetupToBackswing(pose: BodyPose, history: [BodyPose]) {
        // Confirm address position first
        if !addressConfirmed {
            if isStaticPosition(poses: history, threshold: 0.05) {
                addressConfirmed = true
            }
            return
        }

        // Detect backswing initiation
        guard let handPos = handPosition(from: pose),
              history.count >= 2 else { return }

        let previousPose = history[history.count - 2]
        guard let prevHandPos = handPosition(from: previousPose) else { return }

        // Check for upward and backward movement
        let movement = handPos - prevHandPos
        let movingUp = movement.y > 0.01
        let movingBack = isLeftHanded ? movement.x < -0.01 : movement.x > 0.01

        if movingUp && movingBack {
            guard let speed = handSpeed(current: pose, previous: previousPose),
                  speed > backswingSpeedThreshold else { return }

            transitionToPhase(.backswing, at: pose.timestamp, confidence: pose.overallConfidence)
            backswingPeakHeight = handPos.y
        }
    }

    private func detectBackswingToTransition(pose: BodyPose, history: [BodyPose]) {
        guard let handPos = handPosition(from: pose) else { return }

        // Track peak height
        if handPos.y > backswingPeakHeight {
            backswingPeakHeight = handPos.y
        }

        // Detect top of backswing (hands stop rising, about to reverse)
        guard history.count >= 3 else { return }

        let recent = Array(history.suffix(3))
        guard let h1 = handPosition(from: recent[0]),
              let h2 = handPosition(from: recent[1]),
              let h3 = handPosition(from: recent[2]) else { return }

        // Check if hand height peaked and is starting to descend
        let wasRising = h2.y > h1.y
        let nowFalling = h3.y < h2.y

        if wasRising && nowFalling {
            // Additional validation: hands should be above shoulders
            if handsAboveShoulders(from: pose) {
                transitionToPhase(.transition, at: pose.timestamp, confidence: pose.overallConfidence)
                transitionTime = pose.timestamp
            }
        }
    }

    private func detectTransitionToDownswing(pose: BodyPose, history: [BodyPose]) {
        guard let transitionTime = self.transitionTime,
              pose.timestamp - transitionTime > 0.1 else { return }  // Min 100ms in transition

        guard history.count >= 2 else { return }
        let previousPose = history[history.count - 2]

        guard let speed = handSpeed(current: pose, previous: previousPose) else { return }

        // Downswing initiated with significant speed increase
        if speed > downswingSpeedThreshold {
            // Verify hands are moving down and forward
            guard let handPos = handPosition(from: pose),
                  let prevHandPos = handPosition(from: previousPose) else { return }

            let movement = handPos - prevHandPos
            let movingDown = movement.y < -0.01
            let movingForward = isLeftHanded ? movement.x > 0.01 : movement.x < -0.01

            if movingDown && movingForward {
                transitionToPhase(.downswing, at: pose.timestamp, confidence: pose.overallConfidence)
            }
        }
    }

    private func detectDownswingToImpact(pose: BodyPose, history: [BodyPose]) {
        guard history.count >= 2 else { return }
        let previousPose = history[history.count - 2]

        guard let handPos = handPosition(from: pose),
              let speed = handSpeed(current: pose, previous: previousPose) else { return }

        // Impact zone: maximum hand speed + hands near address position height
        if speed > impactSpeedThreshold {
            // Check if hands are in impact zone (similar height to address)
            guard let hips = pose.joints[.leftHip] ?? pose.joints[.rightHip] else { return }

            let impactHeight = hips.position.y + 0.3  // ~30cm above hips
            let heightDiff = abs(handPos.y - impactHeight)

            if heightDiff < 0.15 {  // Within 15cm of impact zone
                transitionToPhase(.impact, at: pose.timestamp, confidence: pose.overallConfidence)
            }
        }
    }

    private func detectImpactToFollowThrough(pose: BodyPose, history: [BodyPose]) {
        guard history.count >= 2 else { return }
        let previousPose = history[history.count - 2]

        guard let speed = handSpeed(current: pose, previous: previousPose) else { return }

        // Follow-through begins when speed starts to decrease after impact
        if speed < impactSpeedThreshold {
            // Verify hands are moving up and around
            guard let handPos = handPosition(from: pose),
                  let prevHandPos = handPosition(from: previousPose) else { return }

            let movement = handPos - prevHandPos
            let movingUp = movement.y > 0

            if movingUp {
                transitionToPhase(.followThrough, at: pose.timestamp, confidence: pose.overallConfidence)
            }
        }
    }

    private func detectFollowThroughComplete(pose: BodyPose, history: [BodyPose]) {
        // Follow-through completes when hands reach high finish and stabilize
        guard handsAboveShoulders(from: pose) else { return }

        let recent = getRecentPoses(count: 15)
        if isStaticPosition(poses: recent, threshold: 0.1) {
            // Swing complete - could reset or track finish position
            // For now, just stay in follow-through
        }
    }

    // MARK: - Golf-Specific Analysis

    /// Detect if player is at address (setup position)
    func isAtAddress(pose: BodyPose) -> Bool {
        guard let handPos = handPosition(from: pose),
              let leftHip = pose.joints[.leftHip],
              let rightHip = pose.joints[.rightHip],
              leftHip.isTracked, rightHip.isTracked else {
            return false
        }

        let hipCenter = (leftHip.position + rightHip.position) / 2.0

        // At address: hands below hips, bent posture
        let handsBelowHips = handPos.y < hipCenter.y
        let properPosture = checkAddressPosture(pose: pose)

        return handsBelowHips && properPosture
    }

    /// Check for proper address posture
    private func checkAddressPosture(pose: BodyPose) -> Bool {
        // Check spine angle (forward tilt) using shoulders as proxy for head
        guard let shoulders = pose.joints[.leftShoulder] ?? pose.joints[.rightShoulder],
              let hips = pose.joints[.leftHip] ?? pose.joints[.rightHip],
              shoulders.isTracked, hips.isTracked else {
            return false
        }

        // Spine should tilt forward
        let spineAngle = atan2(shoulders.position.y - hips.position.y,
                               abs(shoulders.position.z - hips.position.z))

        // Address posture: 30-60 degree forward tilt
        let degrees = spineAngle * 180 / .pi
        return degrees > 30 && degrees < 60
    }

    /// Calculate backswing length (hand travel distance)
    func backswingLength() -> Float? {
        let backswingTransition = currentAnalysis.transitions.first { $0.toPhase == .backswing }
        let topTransition = currentAnalysis.transitions.first { $0.toPhase == .transition }

        // Would need to track hand positions during backswing
        // Simplified: return peak height
        return backswingPeakHeight
    }

    /// Get swing tempo (backswing:downswing ratio)
    func swingTempo() -> Float? {
        guard let backswingDuration = currentAnalysis.phaseDuration(.backswing),
              let downswingDuration = currentAnalysis.phaseDuration(.downswing),
              downswingDuration > 0 else {
            return nil
        }

        return Float(backswingDuration / downswingDuration)
    }
}
