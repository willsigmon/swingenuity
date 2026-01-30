import Foundation
import simd

/// Analyzes swing form and technique from joint position data
final class FormAnalyzer {

    // MARK: - Joint Name Constants

    private enum Joint {
        static let head = "head"
        static let neck = "neck"
        static let leftShoulder = "left_shoulder"
        static let rightShoulder = "right_shoulder"
        static let leftElbow = "left_elbow"
        static let rightElbow = "right_elbow"
        static let leftWrist = "left_wrist"
        static let rightWrist = "right_wrist"
        static let leftHip = "left_hip"
        static let rightHip = "right_hip"
        static let leftKnee = "left_knee"
        static let rightKnee = "right_knee"
        static let leftAnkle = "left_ankle"
        static let rightAnkle = "right_ankle"
        static let root = "root"
    }

    // MARK: - Analysis

    /// Analyze form metrics across all frames
    func analyze(frames: [JointPositionFrame], phases: [DetectedSwingPhase]) -> FormMetrics {
        guard !frames.isEmpty else {
            return FormMetrics.zero
        }

        // Find key phase frames
        let setupFrame = frames.first ?? frames[0]
        let impactFrame = findImpactFrame(frames: frames, phases: phases)
        let backswingFrame = findBackswingFrame(frames: frames, phases: phases)
        let followThroughFrame = findFollowThroughFrame(frames: frames, phases: phases)

        // Calculate rotation angles
        let hipRotation = calculateHipRotation(from: setupFrame, to: impactFrame)
        let shoulderRotation = calculateShoulderRotation(from: setupFrame, to: impactFrame)

        // Calculate spine angles
        let spineAtAddress = calculateSpineAngle(frame: setupFrame)
        let spineAtImpact = calculateSpineAngle(frame: impactFrame)

        // Calculate weight transfer
        let weightTransfer = calculateWeightTransfer(
            setup: setupFrame,
            impact: impactFrame,
            frames: frames
        )

        // Calculate arm extension
        let armExtension = calculateArmExtension(
            backswing: backswingFrame,
            impact: impactFrame,
            followThrough: followThroughFrame
        )

        return FormMetrics(
            hipRotationAngle: hipRotation,
            shoulderRotationAngle: shoulderRotation,
            spineAngleAtAddress: spineAtAddress,
            spineAngleAtImpact: spineAtImpact,
            weightTransferPercentage: weightTransfer,
            armExtensionScore: armExtension
        )
    }

    // MARK: - Rotation Calculations

    private func calculateHipRotation(from start: JointPositionFrame, to end: JointPositionFrame) -> Double {
        guard let startLeftHip = start.position(for: Joint.leftHip),
              let startRightHip = start.position(for: Joint.rightHip),
              let endLeftHip = end.position(for: Joint.leftHip),
              let endRightHip = end.position(for: Joint.rightHip) else {
            return 0.0
        }

        // Calculate hip line vectors (in XZ plane for rotation)
        let startHipVector = SIMD2<Float>(
            startRightHip.x - startLeftHip.x,
            startRightHip.z - startLeftHip.z
        )
        let endHipVector = SIMD2<Float>(
            endRightHip.x - endLeftHip.x,
            endRightHip.z - endLeftHip.z
        )

        return angleBetweenVectors(startHipVector, endHipVector)
    }

    private func calculateShoulderRotation(from start: JointPositionFrame, to end: JointPositionFrame) -> Double {
        guard let startLeftShoulder = start.position(for: Joint.leftShoulder),
              let startRightShoulder = start.position(for: Joint.rightShoulder),
              let endLeftShoulder = end.position(for: Joint.leftShoulder),
              let endRightShoulder = end.position(for: Joint.rightShoulder) else {
            return 0.0
        }

        // Calculate shoulder line vectors (in XZ plane)
        let startShoulderVector = SIMD2<Float>(
            startRightShoulder.x - startLeftShoulder.x,
            startRightShoulder.z - startLeftShoulder.z
        )
        let endShoulderVector = SIMD2<Float>(
            endRightShoulder.x - endLeftShoulder.x,
            endRightShoulder.z - endLeftShoulder.z
        )

        return angleBetweenVectors(startShoulderVector, endShoulderVector)
    }

    // MARK: - Spine Angle

    private func calculateSpineAngle(frame: JointPositionFrame) -> Double {
        guard let head = frame.position(for: Joint.head),
              let leftHip = frame.position(for: Joint.leftHip),
              let rightHip = frame.position(for: Joint.rightHip) else {
            return 0.0
        }

        // Calculate center of hips
        let hipCenter = (leftHip + rightHip) / 2.0

        // Spine vector from hip center to head
        let spineVector = head - hipCenter

        // Vertical reference vector
        let verticalVector = SIMD3<Float>(0, 1, 0)

        // Calculate angle from vertical
        return Double(angleBetweenVectors3D(spineVector, verticalVector))
    }

    // MARK: - Weight Transfer

    private func calculateWeightTransfer(
        setup: JointPositionFrame,
        impact: JointPositionFrame,
        frames: [JointPositionFrame]
    ) -> Double {
        guard let setupLeftHip = setup.position(for: Joint.leftHip),
              let setupRightHip = setup.position(for: Joint.rightHip),
              let impactLeftHip = impact.position(for: Joint.leftHip),
              let impactRightHip = impact.position(for: Joint.rightHip) else {
            return 0.0
        }

        // Calculate hip center positions
        let setupHipCenter = (setupLeftHip + setupRightHip) / 2.0
        let impactHipCenter = (impactLeftHip + impactRightHip) / 2.0

        // Calculate lateral shift (X-axis movement)
        let lateralShift = abs(impactHipCenter.x - setupHipCenter.x)

        // Calculate forward shift (Z-axis movement)
        let forwardShift = abs(impactHipCenter.z - setupHipCenter.z)

        // Total shift magnitude
        let totalShift = sqrt(lateralShift * lateralShift + forwardShift * forwardShift)

        // Convert to percentage (assume 0.3 units = 100% transfer, adjust based on testing)
        let transferPercentage = min(Double(totalShift / 0.3) * 100.0, 100.0)

        return transferPercentage
    }

    // MARK: - Arm Extension

    private func calculateArmExtension(
        backswing: JointPositionFrame,
        impact: JointPositionFrame,
        followThrough: JointPositionFrame
    ) -> Double {
        // Calculate extension at each key phase
        let backswingExtension = calculateArmExtensionAtFrame(backswing)
        let impactExtension = calculateArmExtensionAtFrame(impact)
        let followThroughExtension = calculateArmExtensionAtFrame(followThrough)

        // Average across key phases (weighted toward impact)
        let weightedAverage = (backswingExtension * 0.2 + impactExtension * 0.5 + followThroughExtension * 0.3)

        return weightedAverage
    }

    private func calculateArmExtensionAtFrame(_ frame: JointPositionFrame) -> Double {
        // Calculate lead arm extension (left arm for right-handed, right arm for left-handed)
        // For simplicity, measure both and take the better one
        let leftExtension = calculateSingleArmExtension(
            shoulder: frame.position(for: Joint.leftShoulder),
            elbow: frame.position(for: Joint.leftElbow),
            wrist: frame.position(for: Joint.leftWrist)
        )

        let rightExtension = calculateSingleArmExtension(
            shoulder: frame.position(for: Joint.rightShoulder),
            elbow: frame.position(for: Joint.rightElbow),
            wrist: frame.position(for: Joint.rightWrist)
        )

        return max(leftExtension, rightExtension)
    }

    private func calculateSingleArmExtension(
        shoulder: SIMD3<Float>?,
        elbow: SIMD3<Float>?,
        wrist: SIMD3<Float>?
    ) -> Double {
        guard let shoulder = shoulder,
              let elbow = elbow,
              let wrist = wrist else {
            return 0.0
        }

        // Calculate arm segments
        let upperArm = elbow - shoulder
        let forearm = wrist - elbow

        // Calculate angle at elbow (180° = fully extended)
        let elbowAngle = angleBetweenVectors3D(upperArm, forearm)

        // Convert to extension score (0-100, where 180° = 100)
        let extensionScore = (Double(elbowAngle) / 180.0) * 100.0

        return min(extensionScore, 100.0)
    }

    // MARK: - Phase Frame Finders

    private func findImpactFrame(frames: [JointPositionFrame], phases: [DetectedSwingPhase]) -> JointPositionFrame {
        if let impactPhase = phases.first(where: { $0.phase == .impact }) {
            let index = min(impactPhase.startFrameIndex, frames.count - 1)
            return frames[index]
        }
        // Fallback to 70% through swing
        let index = min(Int(Double(frames.count) * 0.7), frames.count - 1)
        return frames[index]
    }

    private func findBackswingFrame(frames: [JointPositionFrame], phases: [DetectedSwingPhase]) -> JointPositionFrame {
        if let backswingPhase = phases.first(where: { $0.phase == .backswing }) {
            let index = min(backswingPhase.endFrameIndex, frames.count - 1)
            return frames[index]
        }
        // Fallback to 30% through swing
        let index = min(Int(Double(frames.count) * 0.3), frames.count - 1)
        return frames[index]
    }

    private func findFollowThroughFrame(frames: [JointPositionFrame], phases: [DetectedSwingPhase]) -> JointPositionFrame {
        if let followThroughPhase = phases.first(where: { $0.phase == .followThrough }) {
            let index = min(followThroughPhase.endFrameIndex, frames.count - 1)
            return frames[index]
        }
        // Fallback to last frame
        return frames.last ?? frames[0]
    }

    // MARK: - Vector Math Helpers

    private func angleBetweenVectors(_ v1: SIMD2<Float>, _ v2: SIMD2<Float>) -> Double {
        let dotProduct = dot(normalize(v1), normalize(v2))
        let clampedDot = max(-1.0, min(1.0, dotProduct))
        let angleRadians = acos(clampedDot)
        return Double(angleRadians * 180.0 / .pi)
    }

    private func angleBetweenVectors3D(_ v1: SIMD3<Float>, _ v2: SIMD3<Float>) -> Float {
        let dotProduct = dot(normalize(v1), normalize(v2))
        let clampedDot = max(-1.0, min(1.0, dotProduct))
        let angleRadians = acos(clampedDot)
        return angleRadians * 180.0 / .pi
    }
}

// MARK: - FormMetrics Extension

extension FormMetrics {
    static var zero: FormMetrics {
        FormMetrics(
            hipRotationAngle: 0,
            shoulderRotationAngle: 0,
            spineAngleAtAddress: 0,
            spineAngleAtImpact: 0,
            weightTransferPercentage: 0,
            armExtensionScore: 0
        )
    }
}
