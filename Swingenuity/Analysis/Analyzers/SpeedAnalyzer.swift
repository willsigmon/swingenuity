import Foundation
import simd

/// Analyzes swing speed and acceleration from joint position data
final class SpeedAnalyzer {

    // MARK: - Joint Name Constants

    private enum Joint {
        static let leftWrist = "left_wrist"
        static let rightWrist = "right_wrist"
        static let leftShoulder = "left_shoulder"
        static let rightShoulder = "right_shoulder"
        static let leftHip = "left_hip"
        static let rightHip = "right_hip"
        static let leftElbow = "left_elbow"
        static let rightElbow = "right_elbow"
    }

    // MARK: - Constants

    private let metersPerSecondToMPH: Float = 2.23694

    // MARK: - Analysis

    /// Analyze speed metrics across all frames
    func analyze(frames: [JointPositionFrame], phases: [DetectedSwingPhase]) -> SpeedMetrics {
        guard frames.count > 2 else {
            return SpeedMetrics.zero
        }

        // Calculate hand speeds across all frames
        let handSpeeds = calculateHandSpeeds(frames: frames)

        // Build acceleration curve
        let accelerations = calculateAccelerations(speeds: handSpeeds, frames: frames)

        // Find peak values
        let peakSpeed = findPeakSpeed(speeds: handSpeeds)
        let peakAcceleration = findPeakAcceleration(accelerations: accelerations)

        // Calculate average speed during power phase (downswing to impact)
        let averageSpeed = calculateAveragePowerPhaseSpeed(
            speeds: handSpeeds,
            frames: frames,
            phases: phases
        )

        // Calculate time to peak speed
        let timeToPeak = calculateTimeToPeakSpeed(
            speeds: handSpeeds,
            frames: frames
        )

        // Find impact speed
        let impactSpeed = calculateImpactSpeed(
            speeds: handSpeeds,
            frames: frames,
            phases: phases
        )

        // Analyze kinetic chain (sequential activation)
        _ = analyzeKineticChain(frames: frames, phases: phases)

        return SpeedMetrics(
            peakSpeed: Double(peakSpeed),
            peakAcceleration: Double(peakAcceleration),
            averageSpeed: Double(averageSpeed),
            timeToPeakSpeed: timeToPeak,
            impactSpeed: Double(impactSpeed)
        )
    }

    // MARK: - Hand Speed Calculations

    private func calculateHandSpeeds(frames: [JointPositionFrame]) -> [Float] {
        var speeds: [Float] = []

        for i in 1..<frames.count {
            let currentFrame = frames[i]
            let previousFrame = frames[i - 1]
            let deltaTime = Float(currentFrame.timestamp - previousFrame.timestamp)

            guard deltaTime > 0 else {
                speeds.append(0)
                continue
            }

            // Use lead hand (calculate both and take max for handedness agnostic)
            let leftSpeed = calculateWristSpeed(
                current: currentFrame.position(for: Joint.leftWrist),
                previous: previousFrame.position(for: Joint.leftWrist),
                deltaTime: deltaTime
            )

            let rightSpeed = calculateWristSpeed(
                current: currentFrame.position(for: Joint.rightWrist),
                previous: previousFrame.position(for: Joint.rightWrist),
                deltaTime: deltaTime
            )

            speeds.append(max(leftSpeed, rightSpeed))
        }

        return speeds
    }

    private func calculateWristSpeed(
        current: SIMD3<Float>?,
        previous: SIMD3<Float>?,
        deltaTime: Float
    ) -> Float {
        guard let current = current,
              let previous = previous else {
            return 0
        }

        // Calculate displacement
        let displacement = current - previous
        let distance = length(displacement)

        // Speed = distance / time, converted to MPH
        let speedMetersPerSecond = distance / deltaTime
        return speedMetersPerSecond * metersPerSecondToMPH
    }

    // MARK: - Acceleration Calculations

    private func calculateAccelerations(speeds: [Float], frames: [JointPositionFrame]) -> [Float] {
        var accelerations: [Float] = []

        for i in 1..<speeds.count {
            let deltaSpeed = speeds[i] - speeds[i - 1]
            let deltaTime = Float(frames[i + 1].timestamp - frames[i].timestamp)

            guard deltaTime > 0 else {
                accelerations.append(0)
                continue
            }

            // Acceleration in mph/s
            accelerations.append(deltaSpeed / deltaTime)
        }

        return accelerations
    }

    // MARK: - Peak Calculations

    private func findPeakSpeed(speeds: [Float]) -> Float {
        return speeds.max() ?? 0
    }

    private func findPeakAcceleration(accelerations: [Float]) -> Float {
        return accelerations.max() ?? 0
    }

    private func calculateAveragePowerPhaseSpeed(
        speeds: [Float],
        frames: [JointPositionFrame],
        phases: [DetectedSwingPhase]
    ) -> Float {
        // Find downswing and impact phases
        let powerPhases = phases.filter { $0.phase == .downswing || $0.phase == .impact }

        guard !powerPhases.isEmpty else {
            // Fallback: use last 30% of swing
            let startIndex = max(0, speeds.count - Int(Double(speeds.count) * 0.3))
            let powerSpeeds = Array(speeds[startIndex...])
            return powerSpeeds.reduce(0, +) / Float(powerSpeeds.count)
        }

        // Calculate average across power phase frames
        var totalSpeed: Float = 0
        var count = 0

        for phase in powerPhases {
            let startIdx = max(0, phase.startFrameIndex - 1) // -1 because speeds array is 1 shorter
            let endIdx = min(speeds.count - 1, phase.endFrameIndex - 1)

            for i in startIdx...endIdx {
                totalSpeed += speeds[i]
                count += 1
            }
        }

        return count > 0 ? totalSpeed / Float(count) : 0
    }

    private func calculateTimeToPeakSpeed(
        speeds: [Float],
        frames: [JointPositionFrame]
    ) -> Double {
        guard let peakIndex = speeds.firstIndex(of: speeds.max() ?? 0) else {
            return 0
        }

        // Time from first frame to peak
        let peakFrameIndex = peakIndex + 1 // +1 because speeds array is offset by 1
        guard peakFrameIndex < frames.count else {
            return 0
        }

        return frames[peakFrameIndex].timestamp - frames[0].timestamp
    }

    private func calculateImpactSpeed(
        speeds: [Float],
        frames: [JointPositionFrame],
        phases: [DetectedSwingPhase]
    ) -> Float {
        if let impactPhase = phases.first(where: { $0.phase == .impact }) {
            let index = max(0, min(impactPhase.startFrameIndex - 1, speeds.count - 1))
            return speeds[index]
        }

        // Fallback: use 70% through swing
        let index = min(Int(Double(speeds.count) * 0.7), speeds.count - 1)
        return speeds[index]
    }

    // MARK: - Kinetic Chain Analysis

    /// Analyze sequential joint activation (hips → shoulders → arms)
    private func analyzeKineticChain(
        frames: [JointPositionFrame],
        phases: [DetectedSwingPhase]
    ) -> KineticChainMetrics {
        // Find transition/downswing phase
        guard let downswingPhase = phases.first(where: { $0.phase == .downswing || $0.phase == .transition }) else {
            return KineticChainMetrics.zero
        }

        let startIdx = downswingPhase.startFrameIndex
        let endIdx = min(downswingPhase.endFrameIndex, frames.count - 1)

        // Calculate peak angular velocities for each segment
        let hipPeakTime = findPeakAngularVelocityTime(
            frames: Array(frames[startIdx...endIdx]),
            joint1: Joint.leftHip,
            joint2: Joint.rightHip
        )

        let shoulderPeakTime = findPeakAngularVelocityTime(
            frames: Array(frames[startIdx...endIdx]),
            joint1: Joint.leftShoulder,
            joint2: Joint.rightShoulder
        )

        let handPeakTime = findPeakAngularVelocityTime(
            frames: Array(frames[startIdx...endIdx]),
            joint1: Joint.leftWrist,
            joint2: Joint.rightWrist
        )

        // Ideal sequence: hips → shoulders → hands
        let hipToShoulderDelay = shoulderPeakTime - hipPeakTime
        let shoulderToHandDelay = handPeakTime - shoulderPeakTime

        return KineticChainMetrics(
            hipToShoulderDelay: hipToShoulderDelay,
            shoulderToHandDelay: shoulderToHandDelay,
            sequenceScore: calculateSequenceScore(
                hipToShoulder: hipToShoulderDelay,
                shoulderToHand: shoulderToHandDelay
            )
        )
    }

    private func findPeakAngularVelocityTime(
        frames: [JointPositionFrame],
        joint1: String,
        joint2: String
    ) -> Double {
        var maxVelocity: Float = 0
        var peakTime: Double = 0

        for i in 1..<frames.count {
            let current = frames[i]
            let previous = frames[i - 1]
            let deltaTime = Float(current.timestamp - previous.timestamp)

            guard deltaTime > 0,
                  let currPos1 = current.position(for: joint1),
                  let currPos2 = current.position(for: joint2),
                  let prevPos1 = previous.position(for: joint1),
                  let prevPos2 = previous.position(for: joint2) else {
                continue
            }

            // Calculate angular velocity
            let currVector = SIMD2<Float>(currPos2.x - currPos1.x, currPos2.z - currPos1.z)
            let prevVector = SIMD2<Float>(prevPos2.x - prevPos1.x, prevPos2.z - prevPos1.z)

            let angle = angleBetweenVectors(currVector, prevVector)
            let angularVelocity = angle / deltaTime

            if angularVelocity > maxVelocity {
                maxVelocity = angularVelocity
                peakTime = current.timestamp
            }
        }

        return peakTime
    }

    private func calculateSequenceScore(
        hipToShoulder: Double,
        shoulderToHand: Double
    ) -> Double {
        // Ideal delays: hip-shoulder 0.05-0.15s, shoulder-hand 0.05-0.15s
        var score = 100.0

        // Penalize if sequence is reversed or too slow
        if hipToShoulder < 0 { score -= 30 } // Shoulders before hips
        if shoulderToHand < 0 { score -= 30 } // Hands before shoulders
        if hipToShoulder > 0.2 { score -= 20 } // Too slow
        if shoulderToHand > 0.2 { score -= 20 } // Too slow

        return max(0, score)
    }

    // MARK: - Helpers

    private func angleBetweenVectors(_ v1: SIMD2<Float>, _ v2: SIMD2<Float>) -> Float {
        let dotProduct = dot(normalize(v1), normalize(v2))
        let clampedDot = max(-1.0, min(1.0, dotProduct))
        return acos(clampedDot)
    }
}

// MARK: - Supporting Types

private struct KineticChainMetrics {
    let hipToShoulderDelay: Double
    let shoulderToHandDelay: Double
    let sequenceScore: Double

    static var zero: KineticChainMetrics {
        KineticChainMetrics(
            hipToShoulderDelay: 0,
            shoulderToHandDelay: 0,
            sequenceScore: 0
        )
    }
}

// MARK: - SpeedMetrics Extension

extension SpeedMetrics {
    static var zero: SpeedMetrics {
        SpeedMetrics(
            peakSpeed: 0,
            peakAcceleration: 0,
            averageSpeed: 0,
            timeToPeakSpeed: 0,
            impactSpeed: 0
        )
    }
}
