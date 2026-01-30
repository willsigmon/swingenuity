import Foundation
import simd

/// Analyzes swing consistency by comparing to ideal baseline
@MainActor
final class ConsistencyAnalyzer {

    private let repository: SwingRepositoryProtocol

    init(repository: SwingRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Analysis

    /// Analyze consistency metrics by comparing to ideal baseline
    func analyze(
        currentFrames: [JointPositionFrame],
        currentMetrics: SwingMetrics,
        sport: Sport
    ) async throws -> ConsistencyMetrics? {
        // Get ideal baseline for this sport
        guard let baseline = try await repository.getIdealBaseline(for: sport),
              let baselineMetrics = baseline.metrics else {
            // No baseline available yet
            return nil
        }

        // Calculate speed variance
        let speedVariance = calculateSpeedVariance(
            current: currentMetrics.speedMetrics,
            baseline: baselineMetrics.speedMetrics
        )

        // Calculate position variance
        let positionVariance = calculatePositionVariance(
            currentFrames: currentFrames,
            baselineFrames: baseline.jointFrames
        )

        // Calculate repeatability score
        let repeatabilityScore = calculateRepeatabilityScore(
            speedVariance: speedVariance,
            positionVariance: positionVariance,
            currentMetrics: currentMetrics,
            baselineMetrics: baselineMetrics
        )

        return ConsistencyMetrics(
            speedVariance: speedVariance,
            positionVariance: positionVariance,
            repeatabilityScore: repeatabilityScore,
            swingCount: 2 // Current + baseline
        )
    }

    // MARK: - Speed Variance

    private func calculateSpeedVariance(
        current: SpeedMetrics,
        baseline: SpeedMetrics
    ) -> Double {
        // Calculate variance in peak speed
        let peakSpeedDiff = abs(current.peakSpeed - baseline.peakSpeed)

        // Calculate variance in impact speed
        let impactSpeedDiff = abs(current.impactSpeed - baseline.impactSpeed)

        // Calculate variance in average speed
        let avgSpeedDiff = abs(current.averageSpeed - baseline.averageSpeed)

        // Weighted average variance
        let variance = (peakSpeedDiff * 0.4) + (impactSpeedDiff * 0.4) + (avgSpeedDiff * 0.2)

        return variance
    }

    // MARK: - Position Variance

    private func calculatePositionVariance(
        currentFrames: [JointPositionFrame],
        baselineFrames: [JointPositionFrame]
    ) -> Double {
        guard !currentFrames.isEmpty && !baselineFrames.isEmpty else {
            return 1.0 // Maximum variance
        }

        // Normalize frame counts (compare same phases)
        let samplePoints = min(currentFrames.count, baselineFrames.count, 10)
        var totalVariance: Double = 0

        for i in 0..<samplePoints {
            let currentIndex = Int(Double(i) / Double(samplePoints) * Double(currentFrames.count - 1))
            let baselineIndex = Int(Double(i) / Double(samplePoints) * Double(baselineFrames.count - 1))

            let currentFrame = currentFrames[currentIndex]
            let baselineFrame = baselineFrames[baselineIndex]

            // Calculate variance for key joints
            let jointVariance = calculateJointPositionVariance(
                current: currentFrame,
                baseline: baselineFrame
            )

            totalVariance += jointVariance
        }

        return totalVariance / Double(samplePoints)
    }

    private func calculateJointPositionVariance(
        current: JointPositionFrame,
        baseline: JointPositionFrame
    ) -> Double {
        // Key joints to compare
        let keyJoints = [
            "left_shoulder", "right_shoulder",
            "left_hip", "right_hip",
            "left_wrist", "right_wrist",
            "left_elbow", "right_elbow"
        ]

        var totalDistance: Float = 0
        var count = 0

        for joint in keyJoints {
            guard let currentPos = current.position(for: joint),
                  let baselinePos = baseline.position(for: joint) else {
                continue
            }

            // Calculate Euclidean distance
            let diff = currentPos - baselinePos
            let distance = length(diff)

            totalDistance += distance
            count += 1
        }

        guard count > 0 else { return 1.0 }

        // Average distance (normalized)
        let avgDistance = totalDistance / Float(count)
        return Double(avgDistance)
    }

    // MARK: - Repeatability Score

    private func calculateRepeatabilityScore(
        speedVariance: Double,
        positionVariance: Double,
        currentMetrics: SwingMetrics,
        baselineMetrics: SwingMetrics
    ) -> Double {
        var score = 100.0

        // Speed consistency (30 points)
        // Ideal: <5 mph variance
        if speedVariance < 5 {
            score -= 0 // Perfect
        } else if speedVariance < 10 {
            score -= (speedVariance - 5) * 3
        } else {
            score -= 30
        }

        // Position consistency (30 points)
        // Ideal: <0.1 units variance
        if positionVariance < 0.1 {
            score -= 0 // Perfect
        } else if positionVariance < 0.3 {
            score -= (positionVariance - 0.1) * 150
        } else {
            score -= 30
        }

        // Form consistency (20 points)
        let formVariance = calculateFormVariance(
            current: currentMetrics.formMetrics,
            baseline: baselineMetrics.formMetrics
        )
        score -= formVariance * 0.2

        // Timing consistency (20 points)
        let timingVariance = abs(
            currentMetrics.speedMetrics.timeToPeakSpeed -
            baselineMetrics.speedMetrics.timeToPeakSpeed
        )
        if timingVariance < 0.05 {
            score -= 0
        } else if timingVariance < 0.15 {
            score -= (timingVariance - 0.05) * 200
        } else {
            score -= 20
        }

        return max(0, min(100, score))
    }

    private func calculateFormVariance(
        current: FormMetrics,
        baseline: FormMetrics
    ) -> Double {
        var totalVariance = 0.0

        // Hip rotation variance
        totalVariance += abs(current.hipRotationAngle - baseline.hipRotationAngle)

        // Shoulder rotation variance
        totalVariance += abs(current.shoulderRotationAngle - baseline.shoulderRotationAngle)

        // Spine angle variance
        totalVariance += abs(current.spineAngleAtImpact - baseline.spineAngleAtImpact)

        // Weight transfer variance
        totalVariance += abs(current.weightTransferPercentage - baseline.weightTransferPercentage)

        // Arm extension variance
        totalVariance += abs(current.armExtensionScore - baseline.armExtensionScore)

        return totalVariance / 5.0 // Average
    }
}
