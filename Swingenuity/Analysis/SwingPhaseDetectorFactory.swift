//
//  SwingPhaseDetectorFactory.swift
//  Swingenuity
//
//  Factory for creating sport-specific phase detectors
//

import Foundation

/// Factory for creating appropriate swing phase detectors based on sport
final class SwingPhaseDetectorFactory {

    /// Create a phase detector for the specified sport
    /// - Parameters:
    ///   - sport: The sport to analyze
    ///   - isLeftHanded: Whether the player is left-handed (default: false)
    /// - Returns: A configured phase detector for the sport
    static func createDetector(for sport: Sport, isLeftHanded: Bool = false) -> any SwingPhaseDetectorProtocol {
        switch sport {
        case .golf:
            return GolfPhaseDetector(isLeftHanded: isLeftHanded)

        case .tennis:
            return TennisPhaseDetector(sport: .tennis, isLeftHanded: isLeftHanded)

        case .pickleball:
            return TennisPhaseDetector(sport: .pickleball, isLeftHanded: isLeftHanded)

        case .baseball:
            let battingSide: BaseballPhaseDetector.BattingSide = isLeftHanded ? .left : .right
            return BaseballPhaseDetector(sport: .baseball, battingSide: battingSide)

        case .softball:
            let battingSide: BaseballPhaseDetector.BattingSide = isLeftHanded ? .left : .right
            return BaseballPhaseDetector(sport: .softball, battingSide: battingSide)
        }
    }

    /// Create a detector with advanced configuration
    /// - Parameters:
    ///   - sport: The sport to analyze
    ///   - configuration: Sport-specific configuration
    /// - Returns: A configured phase detector
    static func createDetector(for sport: Sport, configuration: DetectorConfiguration) -> any SwingPhaseDetectorProtocol {
        switch sport {
        case .golf:
            let detector = GolfPhaseDetector(
                isLeftHanded: configuration.isLeftHanded,
                clubType: configuration.golfClubType ?? .driver
            )
            detector.minimumConfidence = configuration.minimumConfidence
            return detector

        case .tennis:
            let detector = TennisPhaseDetector(sport: .tennis, isLeftHanded: configuration.isLeftHanded)
            detector.minimumConfidence = configuration.minimumConfidence
            return detector

        case .pickleball:
            let detector = TennisPhaseDetector(sport: .pickleball, isLeftHanded: configuration.isLeftHanded)
            detector.minimumConfidence = configuration.minimumConfidence
            return detector

        case .baseball:
            let battingSide: BaseballPhaseDetector.BattingSide = configuration.isLeftHanded ? .left : .right
            let detector = BaseballPhaseDetector(sport: .baseball, battingSide: battingSide)
            detector.minimumConfidence = configuration.minimumConfidence
            return detector

        case .softball:
            let battingSide: BaseballPhaseDetector.BattingSide = configuration.isLeftHanded ? .left : .right
            let detector = BaseballPhaseDetector(sport: .softball, battingSide: battingSide)
            detector.minimumConfidence = configuration.minimumConfidence
            return detector
        }
    }
}

// MARK: - Configuration

/// Configuration for detector creation
struct DetectorConfiguration {
    var isLeftHanded: Bool = false
    var minimumConfidence: Float = 0.5

    // Golf-specific
    var golfClubType: GolfPhaseDetector.ClubType?

    init(
        isLeftHanded: Bool = false,
        minimumConfidence: Float = 0.5,
        golfClubType: GolfPhaseDetector.ClubType? = nil
    ) {
        self.isLeftHanded = isLeftHanded
        self.minimumConfidence = minimumConfidence
        self.golfClubType = golfClubType
    }
}
