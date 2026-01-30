# Camera Layer Integration Checklist

## 1. Add Files to Xcode Project

The following files have been created in `Swingenuity/Camera/`:

- [x] `CameraManager.swift` - Core camera session management
- [x] `CameraPreviewView.swift` - SwiftUI preview wrapper
- [x] `DepthProcessor.swift` - LiDAR depth processing
- [x] `VideoRecorder.swift` - Video + metadata recording
- [x] `CameraCoordinator.swift` - High-level coordinator
- [x] `CameraView.swift` - Example SwiftUI view

**Action Required:**
1. Open `Swingenuity.xcodeproj` in Xcode
2. Right-click on project navigator → Add Files to "Swingenuity"
3. Select all `.swift` files in the `Camera/` folder
4. Ensure "Copy items if needed" is UNCHECKED (files already in place)
5. Ensure "Add to targets: Swingenuity" is CHECKED

## 2. Configure Info.plist Permissions

Add these keys to your app's Info.plist:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required to record and analyze your golf swing with LiDAR depth tracking</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>Save swing recordings to your photo library for easy access and sharing</string>
```

**Action Required:**
1. Open Xcode project
2. Select `Swingenuity` target → Info tab
3. Click `+` to add new keys
4. Add both keys with the descriptions above

**OR** configure in Xcode UI:
1. Target → Info → Custom iOS Target Properties
2. Add "Privacy - Camera Usage Description"
3. Add "Privacy - Photo Library Additions Usage Description"

## 3. Set Minimum iOS Version

Camera layer requires iOS 16+ for:
- Swift Concurrency (async/await, actors)
- @Observable macro (iOS 17+ preferred)
- AVFoundation depth APIs

**Action Required:**
1. Select project in Xcode
2. General tab → Deployment Info
3. Set "iOS Deployment Target" to 16.0 or later (17.0 recommended)

## 4. Test Camera View

Quick test to verify everything works:

```swift
// In your App file or ContentView:
import SwiftUI

@main
struct SwingenuityApp: App {
    var body: some Scene {
        WindowGroup {
            CameraView() // Test camera layer
        }
    }
}
```

**Test on physical device:**
- Simulator does NOT support camera or LiDAR
- Use iPhone 12 Pro or later for LiDAR features
- Older iPhones will fallback to standard camera

## 5. Verify Build & Run

Expected behavior:
1. App requests camera permission on first launch
2. Camera preview appears full screen
3. LiDAR status shown at top (if supported)
4. Red record button at bottom
5. Tap to record → button becomes square stop button
6. Recording timer shows at top
7. Tap stop → saves to Photos + metadata JSON

**Check console logs:**
- Look for "Camera session configured successfully"
- Check "Depth support: true/false"
- Recording start/stop messages

## 6. Verify File Output

After recording:

```swift
// In terminal or Xcode console:
let sessions = VideoRecorder.getAllRecordedSessions()
print(sessions)
```

**Expected files in app Documents:**
- `swing_<timestamp>_<uuid>.mp4`
- `swing_<timestamp>_<uuid>.json`

**Inspect metadata:**
```bash
# Using Xcode → Devices & Simulators → Download Container
# Or use this Swift code:
let metadata = try VideoRecorder.loadMetadata(from: metadataURL)
print(metadata)
```

## 7. Next Integration Steps

### A. Add Vision Framework Skeleton Detection

In `CameraCoordinator.swift`, update `handleVideoFrame()`:

```swift
import Vision

@MainActor
private func handleVideoFrame(_ sampleBuffer: CMSampleBuffer) async {
    // Create body pose request
    let request = VNDetectHumanBodyPoseRequest()

    do {
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer)
        try handler.perform([request])

        guard let observation = request.results?.first else { return }

        // Extract joints
        let skeleton = try extractSkeletonData(from: observation)

        // Sample depth at joints
        let depthSamples = await sampleDepthAtJoints(skeleton.joints)

        // Record frame with metadata
        if isRecording {
            try await videoRecorder.appendFrame(
                sampleBuffer,
                skeletonData: skeleton,
                depthSamples: depthSamples
            )
        }

        // Notify listeners
        onSkeletonDetected?(skeleton)
        if let samples = depthSamples {
            onDepthSamplesReady?(samples)
        }
    } catch {
        logger.error("Skeleton detection failed: \(error)")
    }
}

private func extractSkeletonData(from observation: VNHumanBodyPoseObservation) throws -> VideoRecorder.SkeletonData {
    let recognizedPoints = try observation.recognizedPoints(.all)

    var joints: [String: CGPoint] = [:]
    for (key, point) in recognizedPoints where point.confidence > 0.3 {
        joints[key.rawValue] = point.location
    }

    return VideoRecorder.SkeletonData(
        joints: joints,
        confidence: observation.confidence
    )
}
```

### B. Add Skeleton Overlay to Preview

Create `SkeletonOverlayView.swift`:

```swift
struct SkeletonOverlayView: View {
    let skeleton: VideoRecorder.SkeletonData?

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                guard let skeleton = skeleton else { return }

                // Draw joints
                for (_, point) in skeleton.joints {
                    let screenPoint = CGPoint(
                        x: point.x * size.width,
                        y: (1 - point.y) * size.height // Flip Y
                    )
                    context.fill(
                        Circle().path(in: CGRect(
                            x: screenPoint.x - 5,
                            y: screenPoint.y - 5,
                            width: 10,
                            height: 10
                        )),
                        with: .color(.green)
                    )
                }

                // Draw connections (bones)
                // TODO: Add bone connections
            }
        }
    }
}
```

### C. Add Playback View

Create `PlaybackView.swift` to replay recordings with skeleton overlay.

### D. Add Cloud Sync

Sync videos + metadata to Firebase Storage or S3.

## 8. Troubleshooting

### Camera not working
- Check Info.plist permissions
- Verify physical device (not simulator)
- Check authorization status in logs

### No depth data
- Requires iPhone 12 Pro or later
- Check `hasDepthSupport` property
- System should fallback automatically

### Recording fails
- Check available disk space
- Verify Photos permission
- Check console for error messages

### Build errors
- Ensure iOS 16+ deployment target
- All Camera files added to target
- Check for import statement errors

## 9. Performance Tips

1. **Test on device, not simulator** - Camera and LiDAR require real hardware
2. **Monitor frame rate** - Should maintain 30 FPS minimum during recording
3. **Check depth confidence** - Values below 0.3 indicate unreliable depth
4. **Manage storage** - Each recording is ~50-100 MB, clean up old files
5. **Test in good lighting** - Better lighting = better skeleton detection

## 10. Common Gotchas

- **Actors**: DepthProcessor and VideoRecorder are actors, always use `await`
- **Main actor**: UI updates must happen on `@MainActor`
- **Coordinate spaces**: Vision uses (0,0) at bottom-left, UIKit uses top-left
- **Depth formats**: Can be disparity or depth, processor handles both
- **Recording state**: Always check `isRecording` before appending frames

## Done!

You now have a complete camera layer with:
- ✅ LiDAR depth support
- ✅ Video recording
- ✅ Metadata storage
- ✅ SwiftUI integration
- ✅ Photos library integration
- ✅ Clean architecture with actors

Ready for skeleton detection integration!
