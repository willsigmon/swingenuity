import Foundation

/// Generates overall scores and ratings from swing metrics
final class ScoreGenerator {

    // MARK: - Score Generation

    /// Generate comprehensive scoring from metrics
    /// - Parameters:
    ///   - metrics: Calculated swing metrics
    ///   - sport: Sport type for sport-specific weighting
    /// - Returns: Score result with grade and suggestions
    func generateScore(
        from metrics: SwingMetrics,
        sport: Sport
    ) -> ScoreResult {
        // Get sport-specific weights
        let weights = getSportWeights(for: sport)

        // Calculate weighted overall score
        let overallScore = calculateWeightedScore(
            metrics: metrics,
            weights: weights
        )

        // Generate letter grade
        let grade = generateLetterGrade(score: overallScore)

        // Generate improvement suggestions
        let suggestions = generateImprovementSuggestions(
            metrics: metrics,
            sport: sport
        )

        // Calculate component scores
        let componentScores = ComponentScores(
            form: metrics.formMetrics.compositeScore,
            speed: metrics.speedMetrics.compositeScore,
            consistency: metrics.consistencyMetrics?.compositeScore
        )

        return ScoreResult(
            overallScore: overallScore,
            grade: grade,
            componentScores: componentScores,
            suggestions: suggestions,
            sport: sport
        )
    }

    // MARK: - Sport-Specific Weighting

    private func getSportWeights(for sport: Sport) -> SportWeights {
        switch sport {
        case .golf:
            return SportWeights(
                form: 0.45,      // Golf emphasizes form
                speed: 0.30,     // Speed matters but less than form
                consistency: 0.25 // Consistency is key
            )

        case .baseball, .softball:
            return SportWeights(
                form: 0.35,      // Form important
                speed: 0.45,     // Bat speed is critical
                consistency: 0.20 // Less emphasis on consistency
            )

        case .tennis:
            return SportWeights(
                form: 0.40,      // Technique critical
                speed: 0.35,     // Racket speed important
                consistency: 0.25 // Shot consistency matters
            )

        case .pickleball:
            return SportWeights(
                form: 0.35,      // Control over power
                speed: 0.30,     // Moderate speed importance
                consistency: 0.35 // Consistency very important
            )
        }
    }

    private func calculateWeightedScore(
        metrics: SwingMetrics,
        weights: SportWeights
    ) -> Double {
        var score = 0.0
        var totalWeight = 0.0

        // Form contribution
        score += metrics.formMetrics.compositeScore * weights.form
        totalWeight += weights.form

        // Speed contribution
        score += metrics.speedMetrics.compositeScore * weights.speed
        totalWeight += weights.speed

        // Consistency contribution (if available)
        if let consistency = metrics.consistencyMetrics {
            score += consistency.compositeScore * weights.consistency
            totalWeight += weights.consistency
        }

        // Normalize by total weight
        return totalWeight > 0 ? score / totalWeight : 0
    }

    // MARK: - Letter Grade

    private func generateLetterGrade(score: Double) -> LetterGrade {
        switch score {
        case 97...100:
            return .aPlus
        case 93..<97:
            return .a
        case 90..<93:
            return .aMinus
        case 87..<90:
            return .bPlus
        case 83..<87:
            return .b
        case 80..<83:
            return .bMinus
        case 77..<80:
            return .cPlus
        case 73..<77:
            return .c
        case 70..<73:
            return .cMinus
        case 67..<70:
            return .dPlus
        case 63..<67:
            return .d
        case 60..<63:
            return .dMinus
        default:
            return .f
        }
    }

    // MARK: - Improvement Suggestions

    private func generateImprovementSuggestions(
        metrics: SwingMetrics,
        sport: Sport
    ) -> [ImprovementSuggestion] {
        var suggestions: [ImprovementSuggestion] = []

        // Analyze form weaknesses
        suggestions.append(contentsOf: analyzeFormIssues(metrics.formMetrics, sport: sport))

        // Analyze speed issues
        suggestions.append(contentsOf: analyzeSpeedIssues(metrics.speedMetrics, sport: sport))

        // Analyze consistency issues
        if let consistency = metrics.consistencyMetrics {
            suggestions.append(contentsOf: analyzeConsistencyIssues(consistency, sport: sport))
        }

        // Sort by priority (highest impact first)
        return suggestions.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }

    // MARK: - Form Analysis

    private func analyzeFormIssues(_ form: FormMetrics, sport: Sport) -> [ImprovementSuggestion] {
        var suggestions: [ImprovementSuggestion] = []

        // Hip rotation
        if form.hipRotationAngle < 45 {
            suggestions.append(ImprovementSuggestion(
                category: .form,
                title: "Increase Hip Rotation",
                description: "Your hip rotation is limited. Focus on rotating your hips more during the backswing.",
                priority: .high,
                metric: "Hip Rotation: \(Int(form.hipRotationAngle))°"
            ))
        } else if form.hipRotationAngle > 90 {
            suggestions.append(ImprovementSuggestion(
                category: .form,
                title: "Control Hip Rotation",
                description: "Excessive hip rotation can lead to loss of control. Focus on stability.",
                priority: .medium,
                metric: "Hip Rotation: \(Int(form.hipRotationAngle))°"
            ))
        }

        // Shoulder rotation
        if form.shoulderRotationAngle < 90 {
            suggestions.append(ImprovementSuggestion(
                category: .form,
                title: "Increase Shoulder Turn",
                description: "More shoulder rotation will help generate power. Focus on a fuller backswing.",
                priority: .high,
                metric: "Shoulder Rotation: \(Int(form.shoulderRotationAngle))°"
            ))
        }

        // X-Factor
        if form.xFactor < 20 {
            suggestions.append(ImprovementSuggestion(
                category: .form,
                title: "Improve Hip-Shoulder Separation",
                description: "Work on creating more separation between hip and shoulder rotation for increased power.",
                priority: .high,
                metric: "X-Factor: \(Int(form.xFactor))°"
            ))
        }

        // Weight transfer
        if form.weightTransferPercentage < 60 {
            suggestions.append(ImprovementSuggestion(
                category: .form,
                title: "Improve Weight Transfer",
                description: "Focus on shifting your weight more effectively from back to front foot.",
                priority: .high,
                metric: "Weight Transfer: \(Int(form.weightTransferPercentage))%"
            ))
        }

        // Spine angle consistency
        if form.spineAngleDeviation > 10 {
            suggestions.append(ImprovementSuggestion(
                category: .form,
                title: "Maintain Spine Angle",
                description: "Your spine angle changes too much during the swing. Focus on maintaining posture.",
                priority: .medium,
                metric: "Spine Deviation: \(Int(form.spineAngleDeviation))°"
            ))
        }

        // Arm extension
        if form.armExtensionScore < 80 {
            suggestions.append(ImprovementSuggestion(
                category: .form,
                title: "Extend Arms More",
                description: "Work on keeping your lead arm extended for better arc and power.",
                priority: .medium,
                metric: "Arm Extension: \(Int(form.armExtensionScore))/100"
            ))
        }

        return suggestions
    }

    // MARK: - Speed Analysis

    private func analyzeSpeedIssues(_ speed: SpeedMetrics, sport: Sport) -> [ImprovementSuggestion] {
        var suggestions: [ImprovementSuggestion] = []

        // Peak speed (sport-specific thresholds)
        let optimalSpeed = getOptimalSpeed(for: sport)
        if speed.peakSpeed < optimalSpeed.minimum {
            suggestions.append(ImprovementSuggestion(
                category: .speed,
                title: "Increase Swing Speed",
                description: "Your swing speed is below optimal. Focus on building rotational power and tempo.",
                priority: .high,
                metric: "Peak Speed: \(Int(speed.peakSpeed)) mph"
            ))
        }

        // Speed efficiency (impact vs peak)
        let speedEfficiency = speed.peakSpeed > 0 ? (speed.impactSpeed / speed.peakSpeed) * 100 : 0
        if speedEfficiency < 90 {
            suggestions.append(ImprovementSuggestion(
                category: .speed,
                title: "Improve Impact Timing",
                description: "You're losing speed before impact. Work on timing and acceleration through the ball.",
                priority: .high,
                metric: "Impact Efficiency: \(Int(speedEfficiency))%"
            ))
        }

        // Time to peak
        if speed.timeToPeakSpeed < 0.2 {
            suggestions.append(ImprovementSuggestion(
                category: .tempo,
                title: "Slow Down Your Tempo",
                description: "Your swing is too rushed. Focus on a smoother, more controlled tempo.",
                priority: .medium,
                metric: "Time to Peak: \(String(format: "%.2f", speed.timeToPeakSpeed))s"
            ))
        } else if speed.timeToPeakSpeed > 0.4 {
            suggestions.append(ImprovementSuggestion(
                category: .tempo,
                title: "Quicken Your Tempo",
                description: "Your swing is too slow. Work on a more dynamic, athletic tempo.",
                priority: .medium,
                metric: "Time to Peak: \(String(format: "%.2f", speed.timeToPeakSpeed))s"
            ))
        }

        return suggestions
    }

    // MARK: - Consistency Analysis

    private func analyzeConsistencyIssues(_ consistency: ConsistencyMetrics, sport: Sport) -> [ImprovementSuggestion] {
        var suggestions: [ImprovementSuggestion] = []

        // Speed variance
        if consistency.speedVariance > 5 {
            suggestions.append(ImprovementSuggestion(
                category: .consistency,
                title: "Improve Speed Consistency",
                description: "Your swing speed varies too much. Focus on maintaining a consistent tempo.",
                priority: .medium,
                metric: "Speed Variance: \(String(format: "%.1f", consistency.speedVariance)) mph"
            ))
        }

        // Position variance
        if consistency.positionVariance > 0.1 {
            suggestions.append(ImprovementSuggestion(
                category: .consistency,
                title: "Improve Swing Path Consistency",
                description: "Your swing path is inconsistent. Focus on repeating the same positions.",
                priority: .high,
                metric: "Position Variance: \(String(format: "%.2f", consistency.positionVariance))"
            ))
        }

        // Overall repeatability
        if consistency.repeatabilityScore < 70 {
            suggestions.append(ImprovementSuggestion(
                category: .consistency,
                title: "Work on Repeatability",
                description: "Focus on drilling the same swing repeatedly to build muscle memory.",
                priority: .high,
                metric: "Repeatability: \(Int(consistency.repeatabilityScore))/100"
            ))
        }

        return suggestions
    }

    // MARK: - Sport-Specific Constants

    private func getOptimalSpeed(for sport: Sport) -> (minimum: Double, optimal: Double) {
        switch sport {
        case .golf:
            return (minimum: 80, optimal: 110)
        case .baseball:
            return (minimum: 65, optimal: 85)
        case .softball:
            return (minimum: 60, optimal: 75)
        case .tennis:
            return (minimum: 70, optimal: 90)
        case .pickleball:
            return (minimum: 40, optimal: 55)
        }
    }
}

// MARK: - Supporting Types

struct SportWeights {
    let form: Double
    let speed: Double
    let consistency: Double
}

struct ComponentScores: Codable, Hashable {
    let form: Double
    let speed: Double
    let consistency: Double?
}

struct ScoreResult: Codable {
    let overallScore: Double
    let grade: LetterGrade
    let componentScores: ComponentScores
    let suggestions: [ImprovementSuggestion]
    let sport: Sport
    let timestamp: Date

    init(
        overallScore: Double,
        grade: LetterGrade,
        componentScores: ComponentScores,
        suggestions: [ImprovementSuggestion],
        sport: Sport,
        timestamp: Date = Date()
    ) {
        self.overallScore = overallScore
        self.grade = grade
        self.componentScores = componentScores
        self.suggestions = suggestions
        self.sport = sport
        self.timestamp = timestamp
    }
}

// LetterGrade is defined in Rating.swift - using that definition

struct ImprovementSuggestion: Codable, Identifiable {
    let id: UUID
    let category: SuggestionCategory
    let title: String
    let description: String
    let priority: SuggestionPriority
    let metric: String

    init(
        id: UUID = UUID(),
        category: SuggestionCategory,
        title: String,
        description: String,
        priority: SuggestionPriority,
        metric: String
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.description = description
        self.priority = priority
        self.metric = metric
    }
}

enum SuggestionCategory: String, Codable {
    case form
    case speed
    case tempo
    case consistency

    var displayName: String {
        switch self {
        case .form: return "Form"
        case .speed: return "Speed"
        case .tempo: return "Tempo"
        case .consistency: return "Consistency"
        }
    }

    var iconName: String {
        switch self {
        case .form: return "figure.stand"
        case .speed: return "speedometer"
        case .tempo: return "metronome"
        case .consistency: return "arrow.clockwise"
        }
    }
}

enum SuggestionPriority: Int, Codable {
    case low = 1
    case medium = 2
    case high = 3

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}
