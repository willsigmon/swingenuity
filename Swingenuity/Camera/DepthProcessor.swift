//
//  DepthProcessor.swift
//  Swingenuity
//
//  Process LiDAR depth data for joint position tracking
//

import AVFoundation
import CoreVideo
import Accelerate
import os.log

private let logger = Logger(subsystem: "com.swingenuity.camera", category: "DepthProcessor")

/// Processor for extracting depth information at specific points
actor DepthProcessor {

    // MARK: - Types

    struct DepthSample {
        let timestamp: CMTime
        let depth: Float // meters
        let confidence: Float // 0.0 - 1.0
        let point: CGPoint // normalized (0-1)
    }

    enum DepthError: LocalizedError {
        case invalidDepthData
        case pointOutOfBounds
        case conversionFailed
        case lowConfidence

        var errorDescription: String? {
            switch self {
            case .invalidDepthData:
                return "Invalid depth data format"
            case .pointOutOfBounds:
                return "Point coordinates out of bounds"
            case .conversionFailed:
                return "Failed to convert depth data"
            case .lowConfidence:
                return "Depth confidence too low"
            }
        }
    }

    // MARK: - Properties

    private var depthMapCache: (data: CVPixelBuffer, timestamp: CMTime)?
    private let minimumConfidence: Float = 0.3

    // MARK: - Public Methods

    /// Process depth data and cache it for point sampling
    func processDepthData(_ depthData: AVDepthData) async throws {
        let timestamp = CMTime(seconds: CACurrentMediaTime(), preferredTimescale: 600)

        // Convert to disparity if needed (more accurate for close range)
        let processedDepth: AVDepthData
        if depthData.depthDataType == kCVPixelFormatType_DisparityFloat32 ||
           depthData.depthDataType == kCVPixelFormatType_DisparityFloat16 {
            processedDepth = depthData
        } else {
            processedDepth = depthData.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32)
        }

        // Cache the depth map
        depthMapCache = (processedDepth.depthDataMap, timestamp)

        logger.debug("Processed depth data at \(timestamp.seconds)s")
    }

    /// Get depth at a specific normalized point (0-1 coordinate space)
    func depthAt(normalizedPoint point: CGPoint) async throws -> DepthSample {
        guard let (depthMap, timestamp) = depthMapCache else {
            throw DepthError.invalidDepthData
        }

        // Validate point
        guard point.x >= 0 && point.x <= 1 && point.y >= 0 && point.y <= 1 else {
            throw DepthError.pointOutOfBounds
        }

        // Convert to pixel coordinates
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let pixelX = Int(point.x * CGFloat(width - 1))
        let pixelY = Int(point.y * CGFloat(height - 1))

        // Extract depth value
        let depth = try extractDepthValue(from: depthMap, x: pixelX, y: pixelY)

        // Calculate confidence based on surrounding pixels
        let confidence = try calculateConfidence(depthMap: depthMap, x: pixelX, y: pixelY)

        return DepthSample(
            timestamp: timestamp,
            depth: depth,
            confidence: confidence,
            point: point
        )
    }

    /// Get depth at multiple points efficiently
    func depthAt(normalizedPoints points: [CGPoint]) async throws -> [DepthSample] {
        guard let (depthMap, timestamp) = depthMapCache else {
            throw DepthError.invalidDepthData
        }

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        var samples: [DepthSample] = []

        for point in points {
            guard point.x >= 0 && point.x <= 1 && point.y >= 0 && point.y <= 1 else {
                logger.warning("Skipping out of bounds point: (\(point.x), \(point.y))")
                continue
            }

            let pixelX = Int(point.x * CGFloat(width - 1))
            let pixelY = Int(point.y * CGFloat(height - 1))

            do {
                let depth = try extractDepthValue(from: depthMap, x: pixelX, y: pixelY)
                let confidence = try calculateConfidence(depthMap: depthMap, x: pixelX, y: pixelY)

                samples.append(DepthSample(
                    timestamp: timestamp,
                    depth: depth,
                    confidence: confidence,
                    point: point
                ))
            } catch {
                logger.error("Failed to extract depth at (\(point.x), \(point.y)): \(error.localizedDescription)")
            }
        }

        return samples
    }

    /// Clear cached depth data
    func clearCache() {
        depthMapCache = nil
    }

    // MARK: - Private Methods

    private func extractDepthValue(from depthMap: CVPixelBuffer, x: Int, y: Int) throws -> Float {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        guard x >= 0 && x < width && y >= 0 && y < height else {
            throw DepthError.pointOutOfBounds
        }

        let pixelFormat = CVPixelBufferGetPixelFormatType(depthMap)

        switch pixelFormat {
        case kCVPixelFormatType_DisparityFloat32, kCVPixelFormatType_DepthFloat32:
            guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
                throw DepthError.conversionFailed
            }

            let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
            let floatBuffer = baseAddress.assumingMemoryBound(to: Float.self)
            let index = y * (bytesPerRow / MemoryLayout<Float>.stride) + x
            let value = floatBuffer[index]

            // Convert disparity to depth if needed
            if pixelFormat == kCVPixelFormatType_DisparityFloat32 {
                guard value != 0 else { return Float.infinity }
                return 1.0 / value
            } else {
                return value
            }

        case kCVPixelFormatType_DisparityFloat16, kCVPixelFormatType_DepthFloat16:
            // Handle 16-bit formats
            guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
                throw DepthError.conversionFailed
            }

            let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
            let uint16Buffer = baseAddress.assumingMemoryBound(to: UInt16.self)
            let index = y * (bytesPerRow / MemoryLayout<UInt16>.stride) + x
            let uint16Value = uint16Buffer[index]

            // Convert Float16 to Float32
            var float32Value: Float = 0
            var uint16Var = uint16Value
            // Convert 16-bit float to 32-bit float
            // Simple conversion for depth data
            float32Value = Float(uint16Var)

            if pixelFormat == kCVPixelFormatType_DisparityFloat16 {
                guard float32Value != 0 else { return Float.infinity }
                return 1.0 / float32Value
            } else {
                return float32Value
            }

        default:
            throw DepthError.invalidDepthData
        }
    }

    private func calculateConfidence(depthMap: CVPixelBuffer, x: Int, y: Int) throws -> Float {
        // Sample 3x3 grid around point
        let sampleRadius = 1
        var validSamples: [Float] = []

        for dy in -sampleRadius...sampleRadius {
            for dx in -sampleRadius...sampleRadius {
                let sampleX = x + dx
                let sampleY = y + dy

                let width = CVPixelBufferGetWidth(depthMap)
                let height = CVPixelBufferGetHeight(depthMap)

                guard sampleX >= 0 && sampleX < width &&
                      sampleY >= 0 && sampleY < height else {
                    continue
                }

                if let depth = try? extractDepthValue(from: depthMap, x: sampleX, y: sampleY),
                   depth.isFinite && depth > 0 {
                    validSamples.append(depth)
                }
            }
        }

        guard !validSamples.isEmpty else {
            return 0.0
        }

        // Calculate confidence based on consistency (low standard deviation = high confidence)
        let mean = validSamples.reduce(0, +) / Float(validSamples.count)
        let variance = validSamples.map { pow($0 - mean, 2) }.reduce(0, +) / Float(validSamples.count)
        let stdDev = sqrt(variance)

        // Normalize confidence (lower std dev = higher confidence)
        // Assume std dev > 0.1m means low confidence
        let normalizedStdDev = min(stdDev / 0.1, 1.0)
        let confidence = 1.0 - normalizedStdDev

        return confidence
    }

    /// Get average depth in a region (useful for debugging)
    func averageDepthInRegion(normalizedRect rect: CGRect) async throws -> Float {
        guard let (depthMap, _) = depthMapCache else {
            throw DepthError.invalidDepthData
        }

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        let pixelRect = CGRect(
            x: rect.origin.x * CGFloat(width),
            y: rect.origin.y * CGFloat(height),
            width: rect.width * CGFloat(width),
            height: rect.height * CGFloat(height)
        )

        var depths: [Float] = []

        for y in Int(pixelRect.minY)...Int(pixelRect.maxY) {
            for x in Int(pixelRect.minX)...Int(pixelRect.maxX) {
                if let depth = try? extractDepthValue(from: depthMap, x: x, y: y),
                   depth.isFinite && depth > 0 {
                    depths.append(depth)
                }
            }
        }

        guard !depths.isEmpty else {
            throw DepthError.invalidDepthData
        }

        return depths.reduce(0, +) / Float(depths.count)
    }
}
