# Vision Analysis Layer - Quick Reference Card

## 🚀 One-Minute Setup

```swift
// 1. Create coordinator
let coordinator = SwingAnalysisCoordinator(
    sport: .golf,
    isLeftHanded: false
)

// 2. Process frames
try await coordinator.processFrame(sampleBuffer)

// 3. Get results
if let analysis = coordinator.currentAnalysis {
    print(analysis.currentPhase.displayName)
}
```

## 📦 Core Classes

| Class | Purpose | Usage |
|-------|---------|-------|
| `BodyPoseAnalyzer` | Extract joints from video | `analyzer.processFrame(buffer)` |
| `SwingPhaseDetector` | Detect swing phases | `detector.detectPhase(pose, history)` |
| `SwingAnalysisCoordinator` | Tie it all together | `coordinator.processFrame(buffer)` |

## 🏌️ Sport Detectors

```swift
// Golf
let golf = GolfPhaseDetector(isLeftHanded: false, clubType: .driver)

// Tennis
let tennis = TennisPhaseDetector(sport: .tennis, isLeftHanded: false)

// Baseball
let baseball = BaseballPhaseDetector(sport: .baseball, battingSide: .right)

// Factory (recommended)
let detector = SwingPhaseDetectorFactory.createDetector(for: .golf)
```

## 📊 Swing Phases

1. **Setup** - Ready position
2. **Backswing** - Loading phase
3. **Transition** - Peak of backswing
4. **Downswing** - Acceleration
5. **Impact** - Contact zone
6. **Follow Through** - Completion

## 🎯 Common Tasks

### Analyze Live Camera
```swift
extension ViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                      didOutput sampleBuffer: CMSampleBuffer) {
        Task {
            try await coordinator.processFrame(sampleBuffer)
        }
    }
}
```

### Analyze Recorded Video
```swift
let result = try await coordinator.analyzeVideo(url: videoURL)
let session = SwingSession(
    sport: .golf,
    videoFileURL: videoURL,
    jointFrames: result.toJointFrames()
)
```

### Get Phase Transitions
```swift
let analysis = coordinator.currentAnalysis
for transition in analysis.transitions {
    print("\(transition.toPhase.displayName) at \(transition.timestamp)s")
}
```

### Check Joint Positions
```swift
if let rightWrist = pose.joint(.rightWrist) {
    print("Position: \(rightWrist.position)") // simd_float3 in meters
    print("Confidence: \(rightWrist.confidence)")
}
```

### Calculate Angles
```swift
let elbowAngle = pose.angle(
    joint1: .rightShoulder,
    vertex: .rightElbow,
    joint2: .rightWrist
)
```

### Calculate Speed
```swift
if let velocity = pose.velocity(of: .rightWrist, from: previousPose) {
    let speed = simd_length(velocity) // meters/second
}
```

## ⚙️ Configuration

### Detection Mode
```swift
let analyzer = BodyPoseAnalyzer(mode: .auto)  // Try 3D, fallback to 2D
// .force3D - LiDAR only
// .force2D - Faster, less accurate
```

### Custom Settings
```swift
let config = DetectorConfiguration(
    isLeftHanded: true,
    minimumConfidence: 0.7,
    golfClubType: .putter
)
let detector = SwingPhaseDetectorFactory.createDetector(
    for: .golf,
    configuration: config
)
```

## 🎨 SwiftUI Integration

```swift
struct CameraView: View {
    @State private var coordinator: SwingAnalysisCoordinator

    var body: some View {
        VStack {
            // Camera preview
            CameraPreview()

            // Phase overlay
            if let analysis = coordinator.currentAnalysis {
                Text(analysis.currentPhase.displayName)
                    .font(.headline)
            }
        }
    }
}
```

## 🔍 Debugging

### Check Pose Confidence
```swift
print("Pose confidence: \(pose.overallConfidence)")
print("Is 3D: \(pose.is3D)")
```

### Check Phase Confidence
```swift
print("Phase confidence: \(analysis.confidence)")
print("Current phase: \(analysis.currentPhase)")
```

### Check Joint Tracking
```swift
for (name, joint) in pose.joints {
    if joint.isTracked {
        print("\(name): \(joint.position)")
    }
}
```

## ⚡ Performance Tips

1. **Use .force2D on older devices**
   ```swift
   let analyzer = BodyPoseAnalyzer(mode: .force2D)
   ```

2. **Lower confidence threshold if missing phases**
   ```swift
   detector.minimumConfidence = 0.3
   ```

3. **Process on background queue**
   ```swift
   let queue = DispatchQueue(label: "pose", qos: .userInitiated)
   videoOutput.setSampleBufferDelegate(self, queue: queue)
   ```

## 🐛 Common Issues

| Issue | Solution |
|-------|----------|
| Low FPS | Use `.force2D` mode |
| Missing phases | Lower `minimumConfidence` |
| No pose detected | Check lighting, camera angle |
| Inaccurate 3D | Ensure LiDAR device, good lighting |

## 📏 Geometry Helpers

```swift
// Distance
let distance = pose.distance(from: .leftShoulder, to: .rightShoulder)

// Angle
let angle = pose.angle(joint1: .a, vertex: .b, joint2: .c)

// Velocity
let velocity = pose.velocity(of: .rightWrist, from: previousPose)
let speed = simd_length(velocity)
```

## 🎾 Sport-Specific APIs

### Golf
```swift
let golf = detector as? GolfPhaseDetector
if golf.isAtAddress(pose: pose) { ... }
if let tempo = golf.swingTempo() { ... }
```

### Tennis
```swift
let tennis = detector as? TennisPhaseDetector
print("Stroke: \(tennis.strokeType.displayName)")
if tennis.isInReadyPosition(pose: pose) { ... }
```

### Baseball
```swift
let baseball = detector as? BaseballPhaseDetector
if let xFactor = baseball.hipShoulderSeparation(pose: pose) { ... }
if baseball.hasProperStance(pose: pose) { ... }
```

## 📖 Full Documentation

- **Architecture:** `README_VISION_ANALYSIS.md`
- **Integration:** `INTEGRATION_GUIDE.md`
- **Examples:** `VisionAnalysisExample.swift`
- **Summary:** `../VISION_LAYER_SUMMARY.md`

## 🆘 Getting Help

1. Check the comprehensive docs above
2. Review example code in `VisionAnalysisExample.swift`
3. Follow integration guide step-by-step
4. Test with sample videos before live camera

---

**Quick Links:**
- [Architecture](README_VISION_ANALYSIS.md)
- [Integration](INTEGRATION_GUIDE.md)
- [Summary](../VISION_LAYER_SUMMARY.md)
