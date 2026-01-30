//
//  CameraCoordinator.swift
//  Swingenuity
//
//  Coordinates camera, depth processing, and recording
//

@preconcurrency import AVFoundation
import Observation
import os.log

private let logger = Logger(subsystem: "com.swingenuity.camera", category: "CameraCoordinator")

/// High-level coordinator that ties together camera, depth, and recording
@Observable
@MainActor
final class CameraCoordinator: NSObject {

    // MARK: - Published State

    private(set) var cameraManager: CameraManager
    private(set) var isRecording = false
    private(set) var recordingDuration: TimeInterval = 0
    private(set) var currentSessionId: String?

    // MARK: - Private Properties

    private let depthProcessor = DepthProcessor()
    private let videoRecorder = VideoRecorder()
    private var recordingTimer: Timer?

    // MARK: - Callbacks

    var onSkeletonDetected: ((VideoRecorder.SkeletonData) -> Void)?
    var onDepthSamplesReady: (([VideoRecorder.DepthSample]) -> Void)?

    // MARK: - Initialization

    override init() {
        self.cameraManager = CameraManager()
        super.init()
    }

    // MARK: - Setup

    /// Initialize camera with delegates
    func setup() async throws {
        // Set delegates
        cameraManager.videoDelegate = self
        if cameraManager.hasDepthSupport {
            cameraManager.depthDelegate = self
        }

        // Configure and start camera
        try await cameraManager.configure()
        await cameraManager.start()

        logger.info("CameraCoordinator setup complete")
    }

    /// Shutdown camera
    func shutdown() async {
        if isRecording {
            await stopRecording()
        }
        await cameraManager.stop()
    }

    // MARK: - Recording Control

    /// Start recording a golf swing
    func startRecording() async throws {
        guard !isRecording else { return }

        let sessionId = try await videoRecorder.startRecording()
        currentSessionId = sessionId
        isRecording = true
        recordingDuration = 0

        // Start duration timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingDuration += 0.1
            }
        }

        logger.info("Started recording session: \(sessionId)")
    }

    /// Stop recording and save
    func stopRecording(saveToPhotos: Bool = true) async {
        guard isRecording else { return }

        recordingTimer?.invalidate()
        recordingTimer = nil

        do {
            let (videoURL, metadataURL) = try await videoRecorder.stopRecording(saveToPhotos: saveToPhotos)
            logger.info("Recording saved - Video: \(videoURL.lastPathComponent), Metadata: \(metadataURL.lastPathComponent)")
        } catch {
            logger.error("Failed to stop recording: \(error.localizedDescription)")
        }

        isRecording = false
        currentSessionId = nil
        recordingDuration = 0
    }

    /// Cancel current recording
    func cancelRecording() async {
        guard isRecording else { return }

        recordingTimer?.invalidate()
        recordingTimer = nil

        await videoRecorder.cancelRecording()

        isRecording = false
        currentSessionId = nil
        recordingDuration = 0

        logger.info("Recording cancelled")
    }

    // MARK: - Depth Sampling

    /// Sample depth at joint positions (call this when you have skeleton joints)
    func sampleDepthAtJoints(_ joints: [String: CGPoint]) async -> [VideoRecorder.DepthSample]? {
        guard cameraManager.hasDepthSupport else { return nil }

        do {
            let points = Array(joints.values)
            let depthSamples = try await depthProcessor.depthAt(normalizedPoints: points)

            // Convert to recorder format with joint names
            let jointNames = Array(joints.keys)
            let samples = zip(jointNames, depthSamples).map { name, sample in
                VideoRecorder.DepthSample(
                    jointName: name,
                    depth: sample.depth,
                    confidence: sample.confidence
                )
            }

            return samples
        } catch {
            logger.error("Failed to sample depth: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraCoordinator: AVCaptureVideoDataOutputSampleBufferDelegate {

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // This is called on the video output queue
        // Forward to main actor for processing
        Task { @MainActor in
            await handleVideoFrame(sampleBuffer)
        }
    }

    @MainActor
    private func handleVideoFrame(_ sampleBuffer: CMSampleBuffer) async {
        // Here you would:
        // 1. Run skeleton detection on the frame (Vision framework)
        // 2. Get skeleton data
        // 3. Sample depth at joint positions
        // 4. Append frame to recorder if recording

        // Example skeleton detection would happen here
        // For now, just record the frame if recording
        if isRecording {
            do {
                // In real implementation, pass actual skeleton and depth data
                try await videoRecorder.appendFrame(sampleBuffer)
            } catch {
                logger.error("Failed to append frame: \(error.localizedDescription)")
            }
        }

        // TODO: Integrate with Vision framework for skeleton detection
        // TODO: Call sampleDepthAtJoints() when skeleton is detected
    }
}

// MARK: - AVCaptureDepthDataOutputDelegate

extension CameraCoordinator: AVCaptureDepthDataOutputDelegate {

    nonisolated func depthDataOutput(
        _ output: AVCaptureDepthDataOutput,
        didOutput depthData: AVDepthData,
        timestamp: CMTime,
        connection: AVCaptureConnection
    ) {
        // Process depth data
        Task {
            do {
                try await depthProcessor.processDepthData(depthData)
            } catch {
                logger.error("Failed to process depth data: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Preview Helper

extension CameraCoordinator {
    /// Get the capture session for preview view
    func getCaptureSession() -> AVCaptureSession {
        cameraManager.getCaptureSession()
    }
}
