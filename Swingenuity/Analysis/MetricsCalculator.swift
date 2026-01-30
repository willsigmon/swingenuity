import Foundation

/// Coordinates metric calculation across all analyzers
@MainActor
final class MetricsCalculator {

    private let formAnalyzer: FormAnalyzer
    private let speedAnalyzer: SpeedAnalyzer
    private let consistencyAnalyzer: ConsistencyAnalyzer

    /// Frame decimation factor for performance (1 = all frames, 2 = every other frame, etc.)
    private let decimationFactor: Int

    init(
        repository: SwingRepositoryProtocol,
        decimationFactor: Int = 1
    ) {
        self.formAnalyzer = FormAnalyzer()
        self.speedAnalyzer = SpeedAnalyzer()
        self.consistencyAnalyzer = ConsistencyAnalyzer(repository: repository)
        self.decimationFactor = max(1, decimationFactor)
    }

    // MARK: - Main Calculation

    /// Calculate all metrics for a swing session
    /// - Parameters:
    ///   - frames: Array of joint position frames
    ///   - sport: Sport type for the swing
    ///   - phases: Detected swing phases (optional, will estimate if not provided)
    /// - Returns: Complete SwingMetrics object
    func calculateMetrics(
        frames: [JointPositionFrame],
        sport: Sport,
        phases: [DetectedSwingPhase]? = nil
    ) async throws -> SwingMetrics {
        // Validate input
        guard !frames.isEmpty else {
            throw MetricsCalculatorError.insufficientFrames
        }

        // Apply frame decimation if needed
        let processedFrames = decimateFrames(frames)

        // Detect phases if not provided
        let detectedPhases = phases ?? detectPhases(from: processedFrames)

        // Calculate metrics in parallel where possible
        let form = await calculateFormMetrics(
            frames: processedFrames,
            phases: detectedPhases
        )

        let speed = await calculateSpeedMetrics(
            frames: processedFrames,
            phases: detectedPhases
        )

        // Create intermediate metrics object for consistency analysis
        let baseMetrics = SwingMetrics(
            formMetrics: form,
            speedMetrics: speed,
            consistencyMetrics: nil
        )

        // Calculate consistency (requires baseline comparison)
        let consistency = try? await consistencyAnalyzer.analyze(
            currentFrames: processedFrames,
            currentMetrics: baseMetrics,
            sport: sport
        )

        return SwingMetrics(
            formMetrics: form,
            speedMetrics: speed,
            consistencyMetrics: consistency
        )
    }

    /// Calculate metrics in streaming mode (frame-by-frame during recording)
    /// - Parameters:
    ///   - frames: Accumulated frames so far
    ///   - sport: Sport type
    /// - Returns: Partial metrics (no consistency until complete)
    func calculateStreamingMetrics(
        frames: [JointPositionFrame],
        sport: Sport
    ) -> SwingMetrics? {
        guard frames.count >= 10 else {
            return nil // Not enough frames yet
        }

        // Use accumulated frames for real-time analysis
        let processedFrames = decimateFrames(frames)
        let detectedPhases = detectPhases(from: processedFrames)

        let formMetrics = formAnalyzer.analyze(
            frames: processedFrames,
            phases: detectedPhases
        )

        let speedMetrics = speedAnalyzer.analyze(
            frames: processedFrames,
            phases: detectedPhases
        )

        return SwingMetrics(
            formMetrics: formMetrics,
            speedMetrics: speedMetrics,
            consistencyMetrics: nil // Not available in streaming mode
        )
    }

    // MARK: - Individual Metric Calculations

    private func calculateFormMetrics(
        frames: [JointPositionFrame],
        phases: [DetectedSwingPhase]
    ) async -> FormMetrics {
        return formAnalyzer.analyze(frames: frames, phases: phases)
    }

    private func calculateSpeedMetrics(
        frames: [JointPositionFrame],
        phases: [DetectedSwingPhase]
    ) async -> SpeedMetrics {
        return speedAnalyzer.analyze(frames: frames, phases: phases)
    }

    // MARK: - Phase Detection

    /// Detect swing phases from joint position data
    private func detectPhases(from frames: [JointPositionFrame]) -> [DetectedSwingPhase] {
        guard frames.count >= 10 else {
            return []
        }

        // Simple heuristic-based phase detection
        // In production, this could be ML-based or more sophisticated

        var phases: [DetectedSwingPhase] = []
        let totalFrames = frames.count
        let totalDuration = frames.last!.timestamp - frames.first!.timestamp

        // Setup: First frame (static)
        phases.append(DetectedSwingPhase(
            phase: .setup,
            startTime: frames[0].timestamp,
            endTime: frames[0].timestamp,
            startFrameIndex: 0,
            endFrameIndex: 0
        ))

        // Backswing: ~35% of swing
        let backswingStart = 0
        let backswingEnd = Int(Double(totalFrames) * 0.35)
        phases.append(DetectedSwingPhase(
            phase: .backswing,
            startTime: frames[backswingStart].timestamp,
            endTime: frames[min(backswingEnd, totalFrames - 1)].timestamp,
            startFrameIndex: backswingStart,
            endFrameIndex: backswingEnd
        ))

        // Transition: ~10% of swing
        let transitionStart = backswingEnd
        let transitionEnd = Int(Double(totalFrames) * 0.45)
        phases.append(DetectedSwingPhase(
            phase: .transition,
            startTime: frames[transitionStart].timestamp,
            endTime: frames[min(transitionEnd, totalFrames - 1)].timestamp,
            startFrameIndex: transitionStart,
            endFrameIndex: transitionEnd
        ))

        // Downswing: ~30% of swing
        let downswingStart = transitionEnd
        let downswingEnd = Int(Double(totalFrames) * 0.75)
        phases.append(DetectedSwingPhase(
            phase: .downswing,
            startTime: frames[downswingStart].timestamp,
            endTime: frames[min(downswingEnd, totalFrames - 1)].timestamp,
            startFrameIndex: downswingStart,
            endFrameIndex: downswingEnd
        ))

        // Impact: ~5% of swing
        let impactStart = downswingEnd
        let impactEnd = Int(Double(totalFrames) * 0.80)
        phases.append(DetectedSwingPhase(
            phase: .impact,
            startTime: frames[impactStart].timestamp,
            endTime: frames[min(impactEnd, totalFrames - 1)].timestamp,
            startFrameIndex: impactStart,
            endFrameIndex: impactEnd
        ))

        // Follow-through: Remaining frames
        let followThroughStart = impactEnd
        phases.append(DetectedSwingPhase(
            phase: .followThrough,
            startTime: frames[followThroughStart].timestamp,
            endTime: frames[totalFrames - 1].timestamp,
            startFrameIndex: followThroughStart,
            endFrameIndex: totalFrames - 1
        ))

        return phases
    }

    // MARK: - Frame Processing

    /// Apply decimation to reduce computational load
    private func decimateFrames(_ frames: [JointPositionFrame]) -> [JointPositionFrame] {
        guard decimationFactor > 1 else {
            return frames
        }

        return stride(from: 0, to: frames.count, by: decimationFactor).map { frames[$0] }
    }

    /// Track metrics over time for consistency analysis (future enhancement)
    func trackMetricsOverTime(
        _ metrics: SwingMetrics,
        for sport: Sport
    ) {
        // TODO: Implement time-series tracking
        // Could store rolling window of recent metrics
        // Useful for trend analysis and progress tracking
    }
}

// MARK: - Errors

enum MetricsCalculatorError: LocalizedError {
    case insufficientFrames
    case invalidFrameData
    case phaseDetectionFailed

    var errorDescription: String? {
        switch self {
        case .insufficientFrames:
            return "Not enough frames to calculate metrics"
        case .invalidFrameData:
            return "Frame data is invalid or corrupted"
        case .phaseDetectionFailed:
            return "Failed to detect swing phases"
        }
    }
}
