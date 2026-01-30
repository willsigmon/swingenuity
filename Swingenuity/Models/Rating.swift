import Foundation
import SwiftUI

/// Letter grade representation for swing analysis
enum LetterGrade: String, Codable, CaseIterable {
    case aPlus = "A+"
    case a = "A"
    case aMinus = "A-"
    case bPlus = "B+"
    case b = "B"
    case bMinus = "B-"
    case cPlus = "C+"
    case c = "C"
    case cMinus = "C-"
    case dPlus = "D+"
    case d = "D"
    case dMinus = "D-"
    case f = "F"

    /// Color associated with the grade for UI display
    var color: Color {
        switch self {
        case .aPlus, .a:
            return .green
        case .aMinus, .bPlus:
            return Color(red: 0.5, green: 0.8, blue: 0.3)
        case .b, .bMinus:
            return .yellow
        case .cPlus, .c:
            return .orange
        case .cMinus, .dPlus, .d:
            return Color(red: 1.0, green: 0.5, blue: 0.0)
        case .dMinus, .f:
            return .red
        }
    }

    /// Numeric value for sorting and comparison
    var numericValue: Int {
        switch self {
        case .aPlus: return 13
        case .a: return 12
        case .aMinus: return 11
        case .bPlus: return 10
        case .b: return 9
        case .bMinus: return 8
        case .cPlus: return 7
        case .c: return 6
        case .cMinus: return 5
        case .dPlus: return 4
        case .d: return 3
        case .dMinus: return 2
        case .f: return 1
        }
    }
}

/// Rating structure combining numeric score and letter grade
struct Rating: Codable, Hashable {
    /// Numeric score from 0 to 100
    let score: Double

    /// Computed letter grade based on score
    var letterGrade: LetterGrade {
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

    /// Color for displaying the rating
    var color: Color {
        letterGrade.color
    }

    /// Initialize with a score (automatically computes letter grade)
    init(score: Double) {
        self.score = min(100, max(0, score)) // Clamp between 0 and 100
    }

    /// Convenience initializer from percentage (0.0 to 1.0)
    init(percentage: Double) {
        self.score = min(100, max(0, percentage * 100))
    }
}
