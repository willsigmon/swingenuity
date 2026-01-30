import Foundation

/// Calculated metrics from swing analysis
struct SwingMetrics: Codable, Hashable {
    let formMetrics: FormMetrics
    let speedMetrics: SpeedMetrics
    let consistencyMetrics: ConsistencyMetrics?
    let timestamp: Date

    init(
        formMetrics: FormMetrics,
        speedMetrics: SpeedMetrics,
        consistencyMetrics: ConsistencyMetrics? = nil,
        timestamp: Date = Date()
    ) {
        self.formMetrics = formMetrics
        self.speedMetrics = speedMetrics
        self.consistencyMetrics = consistencyMetrics
        self.timestamp = timestamp
    }

    /// Composite score combining all metrics (0-100)
    var overallScore: Double {
        var score = 0.0
        var weights = 0.0

        // Form metrics weight: 40%
        score += formMetrics.compositeScore * 0.4
        weights += 0.4

        // Speed metrics weight: 30%
        score += speedMetrics.compositeScore * 0.3
        weights += 0.3

        // Consistency metrics weight: 30% (if available)
        if let consistency = consistencyMetrics {
            score += consistency.compositeScore * 0.3
            weights += 0.3
        }

        return weights > 0 ? score / weights : 0
    }
}

// MARK: - Form Metrics

/// Metrics related to swing form and technique
struct FormMetrics: Codable, Hashable {
    /// Hip rotation angle in degrees
    let hipRotationAngle: Double

    /// Shoulder rotation angle in degrees
    let shoulderRotationAngle: Double

    /// Spine angle at address (degrees from vertical)
    let spineAngleAtAddress: Double

    /// Spine angle at impact (degrees from vertical)
    let spineAngleAtImpact: Double

    /// Weight transfer percentage (0-100)
    let weightTransferPercentage: Double

    /// Arm extension at key positions (0-100, 100 = fully extended)
    let armExtensionScore: Double

    /// X-factor (difference between shoulder and hip rotation)
    var xFactor: Double {
        abs(shoulderRotationAngle - hipRotationAngle)
    }

    /// Spine angle consistency (lower is better)
    var spineAngleDeviation: Double {
        abs(spineAngleAtImpact - spineAngleAtAddress)
    }

    /// Composite form score (0-100)
    var compositeScore: Double {
        var score = 0.0

        // Hip rotation: ideal is 45-90 degrees
        score += normalizeScore(hipRotationAngle, optimal: 45...90, weight: 20)

        // Shoulder rotation: ideal is 90-110 degrees
        score += normalizeScore(shoulderRotationAngle, optimal: 90...110, weight: 20)

        // Weight transfer: ideal is 60-80%
        score += normalizeScore(weightTransferPercentage, optimal: 60...80, weight: 20)

        // Arm extension: higher is generally better
        score += normalizeScore(armExtensionScore, optimal: 80...100, weight: 15)

        // X-factor: ideal is 20-40 degrees
        score += normalizeScore(xFactor, optimal: 20...40, weight: 15)

        // Spine angle consistency: ideal is minimal deviation (0-10 degrees)
        score += normalizeScore(spineAngleDeviation, optimal: 0...10, weight: 10, inverse: true)

        return score
    }
}

// MARK: - Speed Metrics

/// Metrics related to swing speed and acceleration
struct SpeedMetrics: Codable, Hashable {
    /// Peak club/bat/racket head speed in mph
    let peakSpeed: Double

    /// Peak acceleration in mph/s
    let peakAcceleration: Double

    /// Average speed during power phase in mph
    let averageSpeed: Double

    /// Time to peak speed in seconds
    let timeToPeakSpeed: Double

    /// Speed at impact in mph
    let impactSpeed: Double

    /// Composite speed score (0-100)
    var compositeScore: Double {
        var score = 0.0

        // Peak speed score (sport-dependent, using golf as baseline: 80-120 mph optimal)
        score += normalizeScore(peakSpeed, optimal: 80...120, weight: 30)

        // Impact speed should be close to peak speed (90-100% of peak)
        let speedEfficiency = peakSpeed > 0 ? (impactSpeed / peakSpeed) * 100 : 0
        score += normalizeScore(speedEfficiency, optimal: 90...100, weight: 30)

        // Acceleration score (higher is generally better, capped)
        score += normalizeScore(peakAcceleration, optimal: 800...1500, weight: 20)

        // Time to peak (should be quick but not instant: 0.2-0.4s optimal)
        score += normalizeScore(timeToPeakSpeed, optimal: 0.2...0.4, weight: 20)

        return score
    }
}

// MARK: - Consistency Metrics

/// Metrics related to swing consistency (requires multiple swings)
struct ConsistencyMetrics: Codable, Hashable {
    /// Variance in peak speed across swings (lower is better)
    let speedVariance: Double

    /// Variance in key joint positions (lower is better)
    let positionVariance: Double

    /// Repeatability score (0-100, higher is better)
    let repeatabilityScore: Double

    /// Number of swings analyzed for consistency
    let swingCount: Int

    /// Composite consistency score (0-100)
    var compositeScore: Double {
        var score = 0.0

        // Speed consistency: variance should be minimal (0-5 mph optimal)
        score += normalizeScore(speedVariance, optimal: 0...5, weight: 30, inverse: true)

        // Position consistency: variance should be minimal (0-0.1 optimal)
        score += normalizeScore(positionVariance, optimal: 0...0.1, weight: 30, inverse: true)

        // Repeatability directly contributes
        score += repeatabilityScore * 0.4

        return score
    }
}

// MARK: - Helper Functions

/// Normalize a value to a 0-100 score based on optimal range
/// - Parameters:
///   - value: The value to score
///   - optimal: The optimal range for the value
///   - weight: Weight of this component in the overall score
///   - inverse: If true, lower values are better (for variance metrics)
/// - Returns: Weighted score contribution
private func normalizeScore(
    _ value: Double,
    optimal: ClosedRange<Double>,
    weight: Double,
    inverse: Bool = false
) -> Double {
    let normalizedValue: Double

    if inverse {
        // For metrics where lower is better (e.g., variance)
        if value <= optimal.lowerBound {
            normalizedValue = 100
        } else if value >= optimal.upperBound {
            normalizedValue = 0
        } else {
            let range = optimal.upperBound - optimal.lowerBound
            normalizedValue = 100 * (1 - (value - optimal.lowerBound) / range)
        }
    } else {
        // For metrics where being in range is better
        if optimal.contains(value) {
            normalizedValue = 100
        } else if value < optimal.lowerBound {
            // Below optimal: scale from 0 to 100
            let distance = optimal.lowerBound - value
            let penalty = min(distance / optimal.lowerBound, 1.0)
            normalizedValue = 100 * (1 - penalty)
        } else {
            // Above optimal: scale from 100 to 0
            let distance = value - optimal.upperBound
            let penalty = min(distance / optimal.upperBound, 1.0)
            normalizedValue = 100 * (1 - penalty)
        }
    }

    return normalizedValue * (weight / 100.0)
}
