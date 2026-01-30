import Foundation

/// Represents the distinct phases of a swing motion
enum SwingPhase: String, Codable, CaseIterable {
    case setup
    case backswing
    case transition
    case downswing
    case impact
    case followThrough

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .setup:
            return "Setup"
        case .backswing:
            return "Backswing"
        case .transition:
            return "Transition"
        case .downswing:
            return "Downswing"
        case .impact:
            return "Impact"
        case .followThrough:
            return "Follow Through"
        }
    }

    /// Typical duration percentage of total swing (approximate)
    var typicalDurationPercentage: Double {
        switch self {
        case .setup:
            return 0.0 // Static position
        case .backswing:
            return 0.35
        case .transition:
            return 0.10
        case .downswing:
            return 0.30
        case .impact:
            return 0.05
        case .followThrough:
            return 0.20
        }
    }

    /// Order index for phase sequencing
    var orderIndex: Int {
        switch self {
        case .setup: return 0
        case .backswing: return 1
        case .transition: return 2
        case .downswing: return 3
        case .impact: return 4
        case .followThrough: return 5
        }
    }
}

/// Represents a detected swing phase with timing information
struct DetectedSwingPhase: Codable {
    let phase: SwingPhase
    let startTime: Double
    let endTime: Double
    let startFrameIndex: Int
    let endFrameIndex: Int

    var duration: Double {
        endTime - startTime
    }

    var frameCount: Int {
        endFrameIndex - startFrameIndex + 1
    }
}
