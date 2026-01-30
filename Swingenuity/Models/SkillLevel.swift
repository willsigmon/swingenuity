import Foundation

/// User's self-reported skill level for swing analysis calibration
enum SkillLevel: String, CaseIterable, Codable {
    case beginner
    case intermediate
    case advanced
    case pro

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .beginner:
            return "Beginner"
        case .intermediate:
            return "Intermediate"
        case .advanced:
            return "Advanced"
        case .pro:
            return "Pro"
        }
    }

    /// Helpful description for the user
    var description: String {
        switch self {
        case .beginner:
            return "Just starting out, learning the basics"
        case .intermediate:
            return "1-3 years of experience, comfortable with fundamentals"
        case .advanced:
            return "Competitive player with refined technique"
        case .pro:
            return "Professional player or instructor"
        }
    }

    /// SF Symbol for visual representation
    var symbolName: String {
        switch self {
        case .beginner:
            return "leaf.fill"
        case .intermediate:
            return "flame.fill"
        case .advanced:
            return "star.fill"
        case .pro:
            return "crown.fill"
        }
    }

    /// Color associated with skill level
    var color: String {
        switch self {
        case .beginner:
            return "green"
        case .intermediate:
            return "blue"
        case .advanced:
            return "purple"
        case .pro:
            return "orange"
        }
    }

    /// Tolerance multiplier for swing analysis (more forgiving for beginners)
    var analysisTolerance: Double {
        switch self {
        case .beginner:
            return 1.5  // 50% more forgiving
        case .intermediate:
            return 1.25 // 25% more forgiving
        case .advanced:
            return 1.0  // Standard tolerance
        case .pro:
            return 0.8  // 20% stricter
        }
    }
}
