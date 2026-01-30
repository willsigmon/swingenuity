//
//  BodyPoseAnalyzer.swift
//  Swingenuity
//
//  Vision framework wrapper for body pose detection
//  Supports both 3D (LiDAR) and 2D fallback detection
//

import Foundation
@preconcurrency import Vision
import CoreMedia
import simd
import Observation
import QuartzCore

/// Represents a single body joint with 3D position and confidence
@Observable
final class BodyJoint {
    let name: VNHumanBodyPose3DObservation.JointName
    var position: simd_float3  // meters in world coordinates
    var confidence: Float
    var isTracked: Bool

    init(name: VNHumanBodyPose3DObservation.JointName,
                position: simd_float3 = .zero,
                confidence: Float = 0.0) {
        self.name = name
        self.position = position
        self.confidence = confidence
        self.isTracked = confidence > 0.3
    }
}

/// Complete body pose with all detected joints
@Observable
final class BodyPose: @unchecked Sendable {
    var timestamp: TimeInterval
    var joints: [VNHumanBodyPose3DObservation.JointName: BodyJoint]
    var is3D: Bool
    var overallConfidence: Float

    init(timestamp: TimeInterval = 0,
                joints: [VNHumanBodyPose3DObservation.JointName: BodyJoint] = [:],
                is3D: Bool = false,
                overallConfidence: Float = 0) {
        self.timestamp = timestamp
        self.joints = joints
        self.is3D = is3D
        self.overallConfidence = overallConfidence
    }

    /// Get joint by name
    func joint(_ name: VNHumanBodyPose3DObservation.JointName) -> BodyJoint? {
        return joints[name]
    }

    /// Check if joint is reliably tracked
    func isJointTracked(_ name: VNHumanBodyPose3DObservation.JointName) -> Bool {
        guard let joint = joints[name] else { return false }
        return joint.isTracked
    }
}

/// Body pose analyzer using Vision framework
@Observable
final class BodyPoseAnalyzer {

    // MARK: - Published State
    var currentPose: BodyPose?
    var isProcessing: Bool = false
    var lastError: Error?
    var detectionMode: DetectionMode = .auto

    // MARK: - Configuration
    enum DetectionMode {
        case auto           // Try 3D, fallback to 2D
        case force3D        // 3D only (fail if unavailable)
        case force2D        // 2D only (faster, less accurate)
    }

    // MARK: - Private Properties
    private var request3D: VNDetectHumanBodyPose3DRequest?
    private var request2D: VNDetectHumanBodyPoseRequest?
    private let processingQueue = DispatchQueue(label: "com.swingenuity.pose.processing", qos: .userInitiated)

    // Performance tracking
    private var frameCount: Int = 0
    private var lastFrameTime: TimeInterval = 0
    private let targetFrameInterval: TimeInterval = 1.0 / 30.0  // 30 FPS

    // MARK: - Initialization
    init(mode: DetectionMode = .auto) {
        self.detectionMode = mode
        setupRequests()
    }

    private func setupRequests() {
        // Setup 3D request
        if detectionMode != .force2D {
            request3D = VNDetectHumanBodyPose3DRequest { [weak self] request, error in
                self?.handle3DResult(request: request, error: error)
            }
        }

        // Setup 2D fallback request
        if detectionMode != .force3D {
            request2D = VNDetectHumanBodyPoseRequest { [weak self] request, error in
                self?.handle2DResult(request: request, error: error)
            }
        }
    }

    // MARK: - Public API

    /// Process a video frame from camera or file
    func processFrame(_ sampleBuffer: CMSampleBuffer) async throws -> BodyPose {
        // Throttle to target FPS
        let currentTime = CACurrentMediaTime()
        if currentTime - lastFrameTime < targetFrameInterval {
            if let pose = currentPose {
                return pose
            }
        }
        lastFrameTime = currentTime

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            throw AnalysisError.invalidFrame
        }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds

        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: AnalysisError.analyzerDeallocated)
                    return
                }

                self.isProcessing = true
                defer { self.isProcessing = false }

                do {
                    let pose = try self.processPixelBuffer(pixelBuffer, timestamp: timestamp)
                    self.currentPose = pose
                    continuation.resume(returning: pose)
                } catch {
                    self.lastError = error
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Processing

    private func processPixelBuffer(_ pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) throws -> BodyPose {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        // Try 3D first
        if detectionMode != .force2D, let request = request3D {
            do {
                try handler.perform([request])
                if let observation = request.results?.first {
                    return try extract3DPose(from: observation, timestamp: timestamp)
                }
            } catch {
                if detectionMode == .force3D {
                    throw error
                }
                // Fall through to 2D
            }
        }

        // Try 2D fallback
        if detectionMode != .force3D, let request = request2D {
            try handler.perform([request])
            if let observation = request.results?.first {
                return try extract2DPose(from: observation, timestamp: timestamp)
            }
        }

        throw AnalysisError.noPoseDetected
    }

    private func extract3DPose(from observation: VNHumanBodyPose3DObservation,
                                timestamp: TimeInterval) throws -> BodyPose {
        var joints: [VNHumanBodyPose3DObservation.JointName: BodyJoint] = [:]
        var totalConfidence: Float = 0
        var jointCount = 0

        // Extract all available 3D joints
        let allJoints = try observation.recognizedPoints(.all)

        for (jointName, recognizedPoint) in allJoints {
            // Extract position from transform matrix
            let transform = recognizedPoint.position
            let position = simd_float3(
                transform.columns.3.x,
                transform.columns.3.y,
                transform.columns.3.z
            )

            // 3D points don't have a simple confidence value, use 1.0
            let joint = BodyJoint(
                name: jointName,
                position: position,
                confidence: 1.0
            )

            joints[jointName] = joint
            totalConfidence += 1.0
            jointCount += 1
        }

        let avgConfidence = jointCount > 0 ? totalConfidence / Float(jointCount) : 0

        return BodyPose(
            timestamp: timestamp,
            joints: joints,
            is3D: true,
            overallConfidence: avgConfidence
        )
    }

    private func extract2DPose(from observation: VNHumanBodyPoseObservation,
                                timestamp: TimeInterval) throws -> BodyPose {
        var joints: [VNHumanBodyPose3DObservation.JointName: BodyJoint] = [:]
        var totalConfidence: Float = 0
        var jointCount = 0

        // Map 2D joints to 3D joint names (z=0)
        // Only map joints that exist in both 2D and 3D APIs
        let jointMapping: [VNHumanBodyPoseObservation.JointName: VNHumanBodyPose3DObservation.JointName] = [
            .leftShoulder: .leftShoulder,
            .rightShoulder: .rightShoulder,
            .leftElbow: .leftElbow,
            .rightElbow: .rightElbow,
            .leftWrist: .leftWrist,
            .rightWrist: .rightWrist,
            .leftHip: .leftHip,
            .rightHip: .rightHip,
            .leftKnee: .leftKnee,
            .rightKnee: .rightKnee,
            .leftAnkle: .leftAnkle,
            .rightAnkle: .rightAnkle
        ]

        let allPoints = try observation.recognizedPoints(.all)

        for (point2D, point3D) in jointMapping {
            if let recognizedPoint = allPoints[point2D] {
                let position = simd_float3(
                    Float(recognizedPoint.location.x),
                    Float(recognizedPoint.location.y),
                    0  // No depth in 2D mode
                )

                let joint = BodyJoint(
                    name: point3D,
                    position: position,
                    confidence: recognizedPoint.confidence
                )

                joints[point3D] = joint
                totalConfidence += recognizedPoint.confidence
                jointCount += 1
            }
        }

        let avgConfidence = jointCount > 0 ? totalConfidence / Float(jointCount) : 0

        return BodyPose(
            timestamp: timestamp,
            joints: joints,
            is3D: false,
            overallConfidence: avgConfidence
        )
    }

    private func handle3DResult(request: VNRequest, error: Error?) {
        if let error = error {
            self.lastError = error
        }
    }

    private func handle2DResult(request: VNRequest, error: Error?) {
        if let error = error {
            self.lastError = error
        }
    }
}

// MARK: - Errors

enum AnalysisError: LocalizedError {
    case invalidFrame
    case noPoseDetected
    case analyzerDeallocated
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .invalidFrame: return "Invalid video frame"
        case .noPoseDetected: return "No body pose detected in frame"
        case .analyzerDeallocated: return "Analyzer was deallocated"
        case .unsupportedFormat: return "Unsupported video format"
        }
    }
}

// MARK: - Geometry Helpers

extension BodyPose {
    /// Calculate distance between two joints
    func distance(from: VNHumanBodyPose3DObservation.JointName,
                        to: VNHumanBodyPose3DObservation.JointName) -> Float? {
        guard let joint1 = joints[from], let joint2 = joints[to],
              joint1.isTracked, joint2.isTracked else {
            return nil
        }
        return simd_distance(joint1.position, joint2.position)
    }

    /// Calculate angle between three joints (middle joint is vertex)
    func angle(joint1: VNHumanBodyPose3DObservation.JointName,
                     vertex: VNHumanBodyPose3DObservation.JointName,
                     joint2: VNHumanBodyPose3DObservation.JointName) -> Float? {
        guard let j1 = joints[joint1], let v = joints[vertex], let j2 = joints[joint2],
              j1.isTracked, v.isTracked, j2.isTracked else {
            return nil
        }

        let vec1 = j1.position - v.position
        let vec2 = j2.position - v.position

        let dot = simd_dot(vec1, vec2)
        let mag1 = simd_length(vec1)
        let mag2 = simd_length(vec2)

        guard mag1 > 0, mag2 > 0 else { return nil }

        let cosAngle = dot / (mag1 * mag2)
        return acos(simd_clamp(cosAngle, -1.0, 1.0))
    }

    /// Get velocity of a joint (requires previous pose)
    func velocity(of jointName: VNHumanBodyPose3DObservation.JointName,
                        from previousPose: BodyPose) -> simd_float3? {
        guard let current = joints[jointName], let previous = previousPose.joints[jointName],
              current.isTracked, previous.isTracked else {
            return nil
        }

        let deltaTime = Float(timestamp - previousPose.timestamp)
        guard deltaTime > 0 else { return nil }

        return (current.position - previous.position) / deltaTime
    }
}
