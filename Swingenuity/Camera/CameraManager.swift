//
//  CameraManager.swift
//  Swingenuity
//
//  Camera management with LiDAR depth support for golf swing analysis
//

@preconcurrency import AVFoundation
import Observation
import os.log

private let logger = Logger(subsystem: "com.swingenuity.camera", category: "CameraManager")

/// Errors that can occur during camera operations
enum CameraError: LocalizedError {
    case notAuthorized
    case configurationFailed
    case deviceNotFound
    case depthDataNotAvailable
    case sessionNotRunning

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Camera access not authorized. Please enable camera access in Settings."
        case .configurationFailed:
            return "Failed to configure camera session."
        case .deviceNotFound:
            return "No suitable camera device found."
        case .depthDataNotAvailable:
            return "Depth data not available on this device."
        case .sessionNotRunning:
            return "Camera session is not running."
        }
    }
}

/// Camera manager handling AVFoundation session, LiDAR depth, and video recording
@Observable
@MainActor
final class CameraManager: NSObject {

    // MARK: - Published State

    private(set) var isRunning = false
    private(set) var hasDepthSupport = false
    private(set) var authorizationStatus: AVAuthorizationStatus = .notDetermined
    private(set) var currentError: CameraError?

    // MARK: - Private Properties

    private let session = AVCaptureSession()
    private var videoDevice: AVCaptureDevice?
    private var videoInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var depthOutput: AVCaptureDepthDataOutput?

    private let sessionQueue = DispatchQueue(label: "com.swingenuity.camera.session")
    private let videoOutputQueue = DispatchQueue(label: "com.swingenuity.camera.video")
    private let depthOutputQueue = DispatchQueue(label: "com.swingenuity.camera.depth")

    // MARK: - Delegates (to be set by consumers)

    weak var videoDelegate: AVCaptureVideoDataOutputSampleBufferDelegate?
    weak var depthDelegate: AVCaptureDepthDataOutputDelegate?

    // MARK: - Initialization

    override init() {
        super.init()
        checkAuthorization()
    }

    // MARK: - Authorization

    private func checkAuthorization() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    /// Request camera authorization
    func requestAuthorization() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        await MainActor.run {
            self.authorizationStatus = granted ? .authorized : .denied
        }
        return granted
    }

    // MARK: - Session Configuration

    /// Configure and start the camera session
    func configure() async throws {
        guard authorizationStatus == .authorized else {
            throw CameraError.notAuthorized
        }

        try await MainActor.run {
            try self.configureSession()
        }

        await MainActor.run {
            self.isRunning = false
            self.currentError = nil
        }
    }

    private func configureSession() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // Set session preset for high quality video
        if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        }

        // Configure video device (back camera with depth support)
        try configureVideoDevice()

        // Configure video output
        try configureVideoOutput()

        // Configure depth output (if available)
        configureDepthOutput()

        logger.info("Camera session configured successfully. Depth support: \(self.hasDepthSupport)")
    }

    private func configureVideoDevice() throws {
        // Try to get back camera with depth support (LiDAR)
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInDualWideCamera,
                .builtInWideAngleCamera,
                .builtInTripleCamera
            ],
            mediaType: .video,
            position: .back
        )

        // Prefer device with depth support
        if let depthDevice = discoverySession.devices.first(where: { device in
            device.activeFormat.supportedDepthDataFormats.isEmpty == false
        }) {
            videoDevice = depthDevice
            hasDepthSupport = true
            logger.info("Found camera with depth support: \(depthDevice.localizedName)")
        } else if let fallbackDevice = discoverySession.devices.first {
            videoDevice = fallbackDevice
            hasDepthSupport = false
            logger.warning("No depth support available, using standard camera")
        } else {
            throw CameraError.deviceNotFound
        }

        guard let device = videoDevice else {
            throw CameraError.deviceNotFound
        }

        // Configure device for depth if available
        if hasDepthSupport {
            try configureDeviceForDepth(device)
        }

        // Add video input
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw CameraError.configurationFailed
        }
        session.addInput(input)
        videoInput = input
    }

    private func configureDeviceForDepth(_ device: AVCaptureDevice) throws {
        // Find best format with depth support
        let formats = device.formats.filter { format in
            !format.supportedDepthDataFormats.isEmpty
        }

        guard let selectedFormat = formats.first else {
            hasDepthSupport = false
            return
        }

        // Select depth format (prefer disparity float)
        let depthFormats = selectedFormat.supportedDepthDataFormats
        let depthFormat = depthFormats.first { format in
            let pixelFormat = CMFormatDescriptionGetMediaSubType(format.formatDescription)
            return pixelFormat == kCVPixelFormatType_DepthFloat32 ||
                   pixelFormat == kCVPixelFormatType_DisparityFloat32
        } ?? depthFormats.first

        try device.lockForConfiguration()
        device.activeFormat = selectedFormat
        if let depthFormat = depthFormat {
            device.activeDepthDataFormat = depthFormat
        }
        device.unlockForConfiguration()

        logger.info("Configured depth format: \(String(describing: depthFormat))")
    }

    private func configureVideoOutput() throws {
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true

        guard session.canAddOutput(output) else {
            throw CameraError.configurationFailed
        }

        session.addOutput(output)
        videoOutput = output

        // Configure connection
        if let connection = output.connection(with: .video) {
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .auto
            }
            connection.videoOrientation = .portrait
        }
    }

    private func configureDepthOutput() {
        guard hasDepthSupport else { return }

        let output = AVCaptureDepthDataOutput()
        output.isFilteringEnabled = true

        guard session.canAddOutput(output) else {
            logger.warning("Cannot add depth output")
            hasDepthSupport = false
            return
        }

        session.addOutput(output)
        depthOutput = output

        // Synchronize depth with video
        if let videoOutput = videoOutput,
           let depthConnection = output.connection(with: .depthData),
           let videoConnection = videoOutput.connection(with: .video) {
            depthConnection.videoOrientation = videoConnection.videoOrientation
        }

        logger.info("Depth output configured successfully")
    }

    // MARK: - Session Control

    /// Start the camera session
    func start() async {
        guard authorizationStatus == .authorized else {
            await MainActor.run {
                self.currentError = .notAuthorized
            }
            return
        }

        await MainActor.run {
            // Set delegates before starting
            if let videoOutput = self.videoOutput {
                videoOutput.setSampleBufferDelegate(self.videoDelegate, queue: self.videoOutputQueue)
            }

            if let depthOutput = self.depthOutput {
                depthOutput.setDelegate(self.depthDelegate, callbackQueue: self.depthOutputQueue)
            }

            if !self.session.isRunning {
                self.session.startRunning()
            }
        }

        await MainActor.run {
            self.isRunning = self.session.isRunning
        }

        logger.info("Camera session started")
    }

    /// Stop the camera session
    func stop() async {
        await MainActor.run {
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.isRunning = false
        }

        logger.info("Camera session stopped")
    }

    // MARK: - Session Access

    /// Get the capture session for preview layer
    func getCaptureSession() -> AVCaptureSession {
        return session
    }

    // MARK: - Cleanup

    nonisolated deinit {
        // Camera cleanup will happen automatically
        // Can't access session here due to Swift 6 concurrency
    }
}

// MARK: - DispatchQueue Extension

private extension DispatchQueue {
    func run<T>(_ block: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            self.async {
                do {
                    let result = try block()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func run(_ block: @escaping @Sendable () -> Void) async {
        await withCheckedContinuation { continuation in
            self.async {
                block()
                continuation.resume()
            }
        }
    }
}
