//
//  VideoRecorder.swift
//  Swingenuity
//
//  Record video with separate metadata for skeleton overlay replay
//

import AVFoundation
import CoreVideo
import Photos
import os.log

private let logger = Logger(subsystem: "com.swingenuity.camera", category: "VideoRecorder")

/// Video recorder that captures video frames and saves metadata separately
actor VideoRecorder {

    // MARK: - Types

    enum RecordingError: LocalizedError {
        case notRecording
        case alreadyRecording
        case writerCreationFailed
        case inputSetupFailed
        case appendFailed
        case finalizationFailed
        case photoLibraryAccessDenied

        var errorDescription: String? {
            switch self {
            case .notRecording:
                return "No active recording session"
            case .alreadyRecording:
                return "Recording already in progress"
            case .writerCreationFailed:
                return "Failed to create video writer"
            case .inputSetupFailed:
                return "Failed to setup video input"
            case .appendFailed:
                return "Failed to append video frame"
            case .finalizationFailed:
                return "Failed to finalize video"
            case .photoLibraryAccessDenied:
                return "Photo library access denied"
            }
        }
    }

    struct RecordingMetadata: Codable {
        let sessionId: String
        let startTime: Date
        var duration: TimeInterval
        var frames: [FrameMetadata]
    }

    struct FrameMetadata: Codable {
        let timestamp: TimeInterval // relative to recording start
        let skeletonData: SkeletonData?
        let depthSamples: [DepthSample]?
    }

    struct SkeletonData: Codable {
        let joints: [String: CGPoint] // joint name -> normalized position
        let confidence: Float
    }

    struct DepthSample: Codable {
        let jointName: String
        let depth: Float
        let confidence: Float
    }

    // MARK: - State

    private var isRecording = false
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    private var currentVideoURL: URL?
    private var currentMetadataURL: URL?
    private var sessionId: String?
    private var recordingStartTime: Date?
    private var metadata: RecordingMetadata?

    private let videoSettings: [String: Any]

    // MARK: - Initialization

    init(videoSettings: [String: Any]? = nil) {
        // Default to 1080p H.264
        self.videoSettings = videoSettings ?? [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 1920,
            AVVideoHeightKey: 1080,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 6_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ]
        ]
    }

    // MARK: - Recording Control

    /// Start a new recording session
    func startRecording() async throws -> String {
        guard !isRecording else {
            throw RecordingError.alreadyRecording
        }

        // Generate session ID and file paths
        let sessionId = UUID().uuidString
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let fileName = "swing_\(timestamp)_\(sessionId)"

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videoURL = documentsPath.appendingPathComponent("\(fileName).mp4")
        let metadataURL = documentsPath.appendingPathComponent("\(fileName).json")

        // Create asset writer
        guard let writer = try? AVAssetWriter(outputURL: videoURL, fileType: .mp4) else {
            throw RecordingError.writerCreationFailed
        }

        // Create video input
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = true

        guard writer.canAdd(input) else {
            throw RecordingError.inputSetupFailed
        }
        writer.add(input)

        // Create pixel buffer adaptor
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: videoSettings[AVVideoWidthKey] as! Int,
            kCVPixelBufferHeightKey as String: videoSettings[AVVideoHeightKey] as! Int,
        ]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )

        // Start writing
        guard writer.startWriting() else {
            throw RecordingError.writerCreationFailed
        }
        writer.startSession(atSourceTime: .zero)

        // Update state
        self.assetWriter = writer
        self.videoInput = input
        self.pixelBufferAdaptor = adaptor
        self.currentVideoURL = videoURL
        self.currentMetadataURL = metadataURL
        self.sessionId = sessionId
        self.recordingStartTime = Date()
        self.isRecording = true

        // Initialize metadata
        self.metadata = RecordingMetadata(
            sessionId: sessionId,
            startTime: Date(),
            duration: 0,
            frames: []
        )

        logger.info("Started recording session: \(sessionId)")
        return sessionId
    }

    /// Append a video frame to the recording
    func appendFrame(
        _ sampleBuffer: CMSampleBuffer,
        skeletonData: SkeletonData? = nil,
        depthSamples: [DepthSample]? = nil
    ) async throws {
        guard isRecording else {
            throw RecordingError.notRecording
        }

        guard let input = videoInput,
              let adaptor = pixelBufferAdaptor,
              let startTime = recordingStartTime else {
            throw RecordingError.notRecording
        }

        // Wait for input to be ready
        guard input.isReadyForMoreMediaData else {
            logger.warning("Video input not ready, dropping frame")
            return
        }

        // Get pixel buffer from sample buffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            throw RecordingError.appendFailed
        }

        // Calculate presentation time
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        // Append pixel buffer
        guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
            logger.error("Failed to append pixel buffer: \(String(describing: self.assetWriter?.error))")
            throw RecordingError.appendFailed
        }

        // Store metadata if provided
        if skeletonData != nil || depthSamples != nil {
            let timestamp = Date().timeIntervalSince(startTime)
            let frameMetadata = FrameMetadata(
                timestamp: timestamp,
                skeletonData: skeletonData,
                depthSamples: depthSamples
            )
            metadata?.frames.append(frameMetadata)
        }
    }

    /// Stop recording and finalize the video
    func stopRecording(saveToPhotos: Bool = true) async throws -> (videoURL: URL, metadataURL: URL) {
        guard isRecording else {
            throw RecordingError.notRecording
        }

        guard let writer = assetWriter,
              let input = videoInput,
              let videoURL = currentVideoURL,
              let metadataURL = currentMetadataURL,
              let startTime = recordingStartTime else {
            throw RecordingError.notRecording
        }

        // Mark input as finished
        input.markAsFinished()

        // Finalize metadata
        metadata?.duration = Date().timeIntervalSince(startTime)

        // Save metadata to JSON
        if let metadata = metadata {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            do {
                let jsonData = try encoder.encode(metadata)
                try jsonData.write(to: metadataURL)
                logger.info("Saved metadata with \(metadata.frames.count) frames")
            } catch {
                logger.error("Failed to save metadata: \(error.localizedDescription)")
            }
        }

        // Finalize video
        await writer.finishWriting()

        guard writer.status == .completed else {
            logger.error("Writer failed with error: \(String(describing: writer.error))")
            throw RecordingError.finalizationFailed
        }

        logger.info("Recording completed: \(videoURL.lastPathComponent)")

        // Save to Photos if requested
        if saveToPhotos {
            try await saveToPhotoLibrary(videoURL: videoURL)
        }

        // Cleanup
        cleanup()

        return (videoURL, metadataURL)
    }

    /// Cancel current recording
    func cancelRecording() async {
        guard isRecording else { return }

        if let writer = assetWriter {
            videoInput?.markAsFinished()
            await writer.finishWriting()
        }

        // Delete files
        if let videoURL = currentVideoURL {
            try? FileManager.default.removeItem(at: videoURL)
        }
        if let metadataURL = currentMetadataURL {
            try? FileManager.default.removeItem(at: metadataURL)
        }

        cleanup()
        logger.info("Recording cancelled")
    }

    // MARK: - Private Methods

    private func cleanup() {
        assetWriter = nil
        videoInput = nil
        pixelBufferAdaptor = nil
        currentVideoURL = nil
        currentMetadataURL = nil
        sessionId = nil
        recordingStartTime = nil
        metadata = nil
        isRecording = false
    }

    private func saveToPhotoLibrary(videoURL: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized else {
            throw RecordingError.photoLibraryAccessDenied
        }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
        }

        logger.info("Video saved to Photos library")
    }

    // MARK: - State Access

    func isCurrentlyRecording() -> Bool {
        // Return current recording state
        return isRecording
    }
}

// MARK: - Utility Extensions

extension VideoRecorder {
    /// Load metadata from a saved recording
    static func loadMetadata(from url: URL) throws -> RecordingMetadata {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(RecordingMetadata.self, from: data)
    }

    /// Get all recorded sessions in documents directory
    static func getAllRecordedSessions() -> [(videoURL: URL, metadataURL: URL)] {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: documentsPath,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        let videoFiles = files.filter { $0.pathExtension == "mp4" && $0.lastPathComponent.hasPrefix("swing_") }

        var sessions: [(URL, URL)] = []
        for videoURL in videoFiles {
            let metadataURL = videoURL.deletingPathExtension().appendingPathExtension("json")
            if FileManager.default.fileExists(atPath: metadataURL.path) {
                sessions.append((videoURL, metadataURL))
            }
        }

        return sessions.sorted(by: { $0.0.lastPathComponent > $1.0.lastPathComponent })
    }

    /// Delete a recorded session (video + metadata)
    static func deleteSession(videoURL: URL) throws {
        let metadataURL = videoURL.deletingPathExtension().appendingPathExtension("json")

        try? FileManager.default.removeItem(at: videoURL)
        try? FileManager.default.removeItem(at: metadataURL)

        logger.info("Deleted session: \(videoURL.lastPathComponent)")
    }
}
