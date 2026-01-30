import SwiftUI
import simd

struct SkeletonOverlayView: View {
    let frame: JointPositionFrame
    let showConfidence: Bool

    init(frame: JointPositionFrame, showConfidence: Bool = true) {
        self.frame = frame
        self.showConfidence = showConfidence
    }

    var body: some View {
        Canvas { context, size in
            // Draw connections first (lines)
            drawConnections(in: context, size: size)

            // Draw joints on top (circles)
            drawJoints(in: context, size: size)
        }
    }

    // MARK: - Drawing

    private func drawConnections(in context: GraphicsContext, size: CGSize) {
        let connections = BodyTopology.connections

        for connection in connections {
            guard let startPos = frame.jointPositions[connection.from],
                  let endPos = frame.jointPositions[connection.to] else {
                continue
            }

            let startConfidence = frame.confidenceScores[connection.from] ?? 0
            let endConfidence = frame.confidenceScores[connection.to] ?? 0
            let avgConfidence = (startConfidence + endConfidence) / 2

            let startPoint = normalizedToScreen(startPos, size: size)
            let endPoint = normalizedToScreen(endPos, size: size)

            var path = Path()
            path.move(to: startPoint)
            path.addLine(to: endPoint)

            let color = colorForConfidence(avgConfidence)
            context.stroke(
                path,
                with: .color(color),
                lineWidth: 3
            )
        }
    }

    private func drawJoints(in context: GraphicsContext, size: CGSize) {
        for (joint, position) in frame.jointPositions {
            let confidence = frame.confidenceScores[joint] ?? 0
            let screenPoint = normalizedToScreen(position, size: size)
            let color = colorForConfidence(confidence)

            let radius: CGFloat = 8
            let circle = Path(ellipseIn: CGRect(
                x: screenPoint.x - radius,
                y: screenPoint.y - radius,
                width: radius * 2,
                height: radius * 2
            ))

            // Draw outer glow
            context.fill(circle, with: .color(color.opacity(0.3)))

            // Draw main circle
            let innerCircle = Path(ellipseIn: CGRect(
                x: screenPoint.x - radius * 0.6,
                y: screenPoint.y - radius * 0.6,
                width: radius * 1.2,
                height: radius * 1.2
            ))
            context.fill(innerCircle, with: .color(color))

            // Draw white center
            let centerCircle = Path(ellipseIn: CGRect(
                x: screenPoint.x - radius * 0.3,
                y: screenPoint.y - radius * 0.3,
                width: radius * 0.6,
                height: radius * 0.6
            ))
            context.fill(centerCircle, with: .color(.white))
        }
    }

    // MARK: - Helpers

    /// Convert normalized 3D position to screen coordinates
    private func normalizedToScreen(_ position: SIMD3<Float>, size: CGSize) -> CGPoint {
        // Assuming x and y are normalized (0-1), z is depth
        let x = CGFloat(position.x) * size.width
        let y = CGFloat(position.y) * size.height
        return CGPoint(x: x, y: y)
    }

    /// Get color based on confidence level
    private func colorForConfidence(_ confidence: Float) -> Color {
        switch confidence {
        case 0.8...1.0:
            return .green
        case 0.6..<0.8:
            return .yellow
        case 0.4..<0.6:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - Body Topology

struct BodyTopology {
    static let connections: [JointConnection] = [
        // Head to Neck
        JointConnection(from: "head", to: "neck"),

        // Neck to Shoulders
        JointConnection(from: "neck", to: "leftShoulder"),
        JointConnection(from: "neck", to: "rightShoulder"),

        // Shoulders to Elbows
        JointConnection(from: "leftShoulder", to: "leftElbow"),
        JointConnection(from: "rightShoulder", to: "rightElbow"),

        // Elbows to Wrists
        JointConnection(from: "leftElbow", to: "leftWrist"),
        JointConnection(from: "rightElbow", to: "rightWrist"),

        // Torso
        JointConnection(from: "neck", to: "root"),
        JointConnection(from: "root", to: "leftHip"),
        JointConnection(from: "root", to: "rightHip"),

        // Hips to Knees
        JointConnection(from: "leftHip", to: "leftKnee"),
        JointConnection(from: "rightHip", to: "rightKnee"),

        // Knees to Ankles
        JointConnection(from: "leftKnee", to: "leftAnkle"),
        JointConnection(from: "rightKnee", to: "rightAnkle"),

        // Hip connection
        JointConnection(from: "leftHip", to: "rightHip"),

        // Shoulder connection
        JointConnection(from: "leftShoulder", to: "rightShoulder")
    ]

    struct JointConnection {
        let from: String
        let to: String
    }
}

#Preview {
    let mockFrame = JointPositionFrame(
        timestamp: 0.0,
        jointPositions: [
            "head": SIMD3<Float>(0.5, 0.1, 0),
            "neck": SIMD3<Float>(0.5, 0.2, 0),
            "leftShoulder": SIMD3<Float>(0.4, 0.25, 0),
            "rightShoulder": SIMD3<Float>(0.6, 0.25, 0),
            "leftElbow": SIMD3<Float>(0.35, 0.4, 0),
            "rightElbow": SIMD3<Float>(0.65, 0.4, 0),
            "leftWrist": SIMD3<Float>(0.3, 0.55, 0),
            "rightWrist": SIMD3<Float>(0.7, 0.55, 0),
            "root": SIMD3<Float>(0.5, 0.5, 0),
            "leftHip": SIMD3<Float>(0.45, 0.5, 0),
            "rightHip": SIMD3<Float>(0.55, 0.5, 0),
            "leftKnee": SIMD3<Float>(0.44, 0.7, 0),
            "rightKnee": SIMD3<Float>(0.56, 0.7, 0),
            "leftAnkle": SIMD3<Float>(0.43, 0.9, 0),
            "rightAnkle": SIMD3<Float>(0.57, 0.9, 0)
        ],
        confidenceScores: [
            "head": 0.95,
            "neck": 0.9,
            "leftShoulder": 0.88,
            "rightShoulder": 0.87,
            "leftElbow": 0.82,
            "rightElbow": 0.85,
            "leftWrist": 0.75,
            "rightWrist": 0.78,
            "root": 0.92,
            "leftHip": 0.89,
            "rightHip": 0.88,
            "leftKnee": 0.84,
            "rightKnee": 0.83,
            "leftAnkle": 0.80,
            "rightAnkle": 0.79
        ]
    )

    return ZStack {
        Color.black
        SkeletonOverlayView(frame: mockFrame)
    }
    .frame(width: 300, height: 500)
}
