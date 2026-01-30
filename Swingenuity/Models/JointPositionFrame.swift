import Foundation
import simd

/// Represents a single frame of joint position data from Vision framework analysis
struct JointPositionFrame: Codable, Identifiable {
    /// Unique identifier for the frame
    let id: UUID

    /// Timestamp in seconds from start of video
    let timestamp: Double

    /// Dictionary mapping joint names to their 3D positions
    /// Keys are Vision framework joint identifiers (e.g., "head", "leftShoulder", "rightHip")
    let jointPositions: [String: SIMD3<Float>]

    /// Confidence scores for each joint detection (0.0 to 1.0)
    /// Keys match jointPositions keys
    let confidenceScores: [String: Float]

    /// Initialize a new joint position frame
    init(
        id: UUID = UUID(),
        timestamp: Double,
        jointPositions: [String: SIMD3<Float>],
        confidenceScores: [String: Float]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.jointPositions = jointPositions
        self.confidenceScores = confidenceScores
    }

    // MARK: - Computed Properties

    /// Average confidence across all detected joints
    var averageConfidence: Float {
        guard !confidenceScores.isEmpty else { return 0.0 }
        let sum = confidenceScores.values.reduce(0.0, +)
        return sum / Float(confidenceScores.count)
    }

    /// Check if frame has minimum quality threshold
    func hasMinimumQuality(threshold: Float = 0.5) -> Bool {
        return averageConfidence >= threshold
    }

    /// Get position for a specific joint if available
    func position(for joint: String) -> SIMD3<Float>? {
        return jointPositions[joint]
    }

    /// Get confidence for a specific joint if available
    func confidence(for joint: String) -> Float? {
        return confidenceScores[joint]
    }
}

// MARK: - SIMD3 Codable Extension
// SwiftData requires Codable conformance, but SIMD3 doesn't conform by default
extension SIMD3: Codable where Scalar: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let x = try container.decode(Scalar.self)
        let y = try container.decode(Scalar.self)
        let z = try container.decode(Scalar.self)
        self.init(x: x, y: y, z: z)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(x)
        try container.encode(y)
        try container.encode(z)
    }
}
