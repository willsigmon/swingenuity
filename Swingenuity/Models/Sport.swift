import Foundation

/// Supported sports for swing analysis
enum Sport: String, Codable, CaseIterable {
    case golf
    case tennis
    case pickleball
    case baseball
    case softball

    /// Human-readable display name for the sport
    var displayName: String {
        switch self {
        case .golf:
            return "Golf"
        case .tennis:
            return "Tennis"
        case .pickleball:
            return "Pickleball"
        case .baseball:
            return "Baseball"
        case .softball:
            return "Softball"
        }
    }

    /// SF Symbol icon name for the sport
    var symbolName: String {
        switch self {
        case .golf:
            return "figure.golf"
        case .tennis:
            return "figure.tennis"
        case .pickleball:
            return "figure.pickleball"
        case .baseball:
            return "figure.baseball"
        case .softball:
            return "figure.softball"
        }
    }

    /// Default weights for scoring metrics specific to each sport
    /// Returns dictionary with metric keys and their importance weights (0.0-1.0)
    var defaultMetricWeights: [String: Double] {
        switch self {
        case .golf:
            return [
                "rotation": 0.25,
                "spineAngle": 0.20,
                "weightTransfer": 0.25,
                "armExtension": 0.15,
                "tempo": 0.15
            ]
        case .tennis:
            return [
                "rotation": 0.20,
                "followThrough": 0.25,
                "footwork": 0.20,
                "racketPath": 0.20,
                "timing": 0.15
            ]
        case .pickleball:
            return [
                "rotation": 0.15,
                "paddleFace": 0.25,
                "footwork": 0.20,
                "followThrough": 0.20,
                "consistency": 0.20
            ]
        case .baseball, .softball:
            return [
                "rotation": 0.30,
                "hipTorque": 0.25,
                "batPath": 0.20,
                "weightTransfer": 0.15,
                "handSpeed": 0.10
            ]
        }
    }
}
