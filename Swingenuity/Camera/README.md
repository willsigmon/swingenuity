# Camera Layer - Swingenuity

Complete AVFoundation camera system with LiDAR depth support for golf swing analysis.

## Architecture

### Core Components

1. **CameraManager.swift** - Low-level camera session management
   - AVCaptureSession configuration
   - LiDAR depth camera discovery
   - Video + depth output streams
   - Permission handling with async/await
   - Falls back to standard camera if no LiDAR

2. **DepthProcessor.swift** - Depth data extraction
   - Processes AVDepthData frames
   - Point sampling at joint positions (not full depth maps)
   - Confidence calculation based on surrounding pixels
   - Actor-isolated for thread safety

3. **VideoRecorder.swift** - Video recording with metadata
   - Records video using AVAssetWriter
   - Saves overlay metadata separately (JSON)
   - Metadata includes skeleton joints + depth samples per frame
   - Photos library integration
   - Session management utilities

4. **CameraCoordinator.swift** - High-level coordinator
   - Ties together camera, depth, and recording
   - Handles video/depth delegate callbacks
   - Coordinates skeleton detection → depth sampling → recording
   - SwiftUI-friendly with @Observable

5. **CameraPreviewView.swift** - SwiftUI preview wrapper
   - UIViewRepresentable for AVCaptureVideoPreviewLayer
   - Proper aspect ratio handling
   - Portrait orientation

6. **CameraView.swift** - Example SwiftUI view
   - Complete camera UI with recording controls
   - Shows how to wire everything together
   - Error handling and permission flow

## Usage

### Basic Setup

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        CameraView()
    }
}
```

### Advanced Integration

```swift
@State private var coordinator = CameraCoordinator()

// Setup camera
try await coordinator.setup()

// Start recording
try await coordinator.startRecording()

// When skeleton is detected (from Vision framework)
let joints = [
    "leftWrist": CGPoint(x: 0.4, y: 0.6),
    "rightWrist": CGPoint(x: 0.6, y: 0.5),
    // ... other joints
]

// Sample depth at joints
let depthSamples = await coordinator.sampleDepthAtJoints(joints)

// Stop recording (saves to Photos + metadata JSON)
await coordinator.stopRecording(saveToPhotos: true)
```

### Metadata Format

Recordings produce two files:
- `swing_<timestamp>_<sessionId>.mp4` - Video file
- `swing_<timestamp>_<sessionId>.json` - Metadata file

```json
{
  "sessionId": "UUID",
  "startTime": "2026-01-29T...",
  "duration": 5.3,
  "frames": [
    {
      "timestamp": 0.033,
      "skeletonData": {
        "joints": {
          "leftWrist": {"x": 0.4, "y": 0.6},
          "rightWrist": {"x": 0.6, "y": 0.5}
        },
        "confidence": 0.95
      },
      "depthSamples": [
        {
          "jointName": "leftWrist",
          "depth": 2.5,
          "confidence": 0.87
        }
      ]
    }
  ]
}
```

## Camera Configuration

### LiDAR Detection
- Targets back camera with depth support
- Looks for `.builtInDualWideCamera`, `.builtInTripleCamera`, `.builtInWideAngleCamera`
- Configures `activeDepthDataFormat` to `DisparityFloat32` or `DepthFloat32`
- Falls back gracefully if no depth support

### Video Settings
- Default: 1080p H.264
- 6 Mbps bitrate
- Real-time capture optimized
- Portrait orientation

### Depth Processing
- Point sampling only (not full depth maps)
- 3x3 confidence calculation around each point
- Handles both disparity and depth formats
- Float16/Float32 support

## Integration Points

### TODO: Vision Framework Integration
Add skeleton detection in `CameraCoordinator.handleVideoFrame()`:

```swift
// In handleVideoFrame()
let request = VNDetectHumanBodyPoseRequest()
let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer)
try? handler.perform([request])

if let observation = request.results?.first {
    let skeleton = extractSkeleton(from: observation)
    let depthSamples = await sampleDepthAtJoints(skeleton.joints)

    if isRecording {
        try await videoRecorder.appendFrame(
            sampleBuffer,
            skeletonData: skeleton,
            depthSamples: depthSamples
        )
    }
}
```

## Permissions Required

Add to `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required to record and analyze your golf swing</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>Save swing recordings to your photo library</string>
```

## Device Requirements

- **LiDAR Support**: iPhone 12 Pro and later, iPad Pro (2020+)
- **Fallback**: Works on all devices with camera, depth features disabled
- **iOS Version**: iOS 16+

## Performance Considerations

1. **Actors**: DepthProcessor and VideoRecorder use actors for thread safety
2. **Queue Management**: Separate queues for video/depth processing
3. **Frame Dropping**: `alwaysDiscardsLateVideoFrames = true` prevents backup
4. **Depth Caching**: Single depth map cached for multi-point sampling
5. **Real-time**: All operations optimized for 30-60 FPS capture

## Error Handling

All async operations throw typed errors:
- `CameraError` - Camera configuration/permission issues
- `DepthProcessor.DepthError` - Depth data processing issues
- `VideoRecorder.RecordingError` - Recording/saving issues

## File Management

```swift
// Get all recorded sessions
let sessions = VideoRecorder.getAllRecordedSessions()

// Load metadata
let metadata = try VideoRecorder.loadMetadata(from: metadataURL)

// Delete session
try VideoRecorder.deleteSession(videoURL: videoURL)
```

## Testing Notes

- Test on physical device with LiDAR (simulators don't support depth)
- Verify fallback behavior on older devices
- Check metadata file creation after each recording
- Validate depth confidence values (should be 0.3+)

## Next Steps

1. Integrate Vision framework for skeleton detection
2. Add overlay rendering (skeleton drawn on preview)
3. Implement playback view with metadata replay
4. Add slow-motion analysis features
5. Cloud sync for recordings + metadata
