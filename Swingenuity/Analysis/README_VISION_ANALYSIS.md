# Vision-Based Body Pose Analysis Layer

## Overview

This layer provides real-time and offline swing analysis using Apple's Vision framework with LiDAR support for 3D body pose detection. It automatically detects swing phases across multiple sports and tracks detailed joint positions in 3D space.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│           SwingAnalysisCoordinator                  │
│  (Orchestrates pose detection + phase analysis)    │
└───────────────┬─────────────────┬───────────────────┘
                │                 │
        ┌───────▼────────┐  ┌────▼──────────────────┐
        │ BodyPoseAnalyzer│  │ SwingPhaseDetector    │
        │  (Vision API)   │  │  (Sport-specific)     │
        └────────┬────────┘  └────┬──────────────────┘
                 │                │
          ┌──────▼──────┐    ┌───▼────────────────┐
          │ VNDetect... │    │ GolfPhaseDetector  │
          │  3D/2D Pose │    │ TennisPhaseDetector│
          └─────────────┘    │ BaseballPhaseDetect│
                             └────────────────────┘
```

## Core Components

### 1. BodyPoseAnalyzer (`BodyPoseAnalyzer.swift`)

Vision framework wrapper that processes video frames and extracts body joint positions.

**Features:**
- 3D pose detection (LiDAR) with 2D fallback
- 30 FPS real-time processing
- 17 joint tracking with confidence scores
- Automatic coordinate conversion to world space (meters)

**Detection Modes:**
- `.auto` - Try 3D, fallback to 2D (recommended)
- `.force3D` - 3D only (requires LiDAR)
- `.force2D` - 2D only (faster, less accurate)

**Usage:**
```swift
let analyzer = BodyPoseAnalyzer(mode: .auto)
let pose = try await analyzer.processFrame(sampleBuffer)

// Access joints
if let rightWrist = pose.joint(.rightWrist) {
    print("Position: \(rightWrist.position)") // meters in world coords
    print("Confidence: \(rightWrist.confidence)")
}

// Calculate angles
if let elbowAngle = pose.angle(joint1: .rightShoulder,
                               vertex: .rightElbow,
                               joint2: .rightWrist) {
    print("Elbow angle: \(elbowAngle * 180 / .pi) degrees")
}
```

### 2. SwingPhaseDetector (`SwingPhaseDetector.swift`)

Base protocol and implementation for detecting swing phases from pose data.

**Swing Phases:**
1. Setup - Ready position
2. Backswing - Loading/preparation
3. Transition - Peak of backswing
4. Downswing - Acceleration
5. Impact - Contact zone
6. Follow Through - Completion

**Base Class Utilities:**
- Hand position tracking
- Hip/shoulder rotation
- Movement velocity calculation
- Static position detection

### 3. Sport-Specific Detectors

#### GolfPhaseDetector (`Detectors/GolfPhaseDetector.swift`)
- Address position detection
- Club type customization (driver, iron, wedge, putter)
- Backswing peak tracking
- Tempo analysis (backswing:downswing ratio)
- Spine angle validation

**Golf-Specific:**
```swift
let detector = GolfPhaseDetector(isLeftHanded: false, clubType: .driver)
let analysis = detector.detectPhase(pose: pose, previousPoses: history)

if detector.isAtAddress(pose: pose) {
    print("Ready to swing!")
}

if let tempo = detector.swingTempo() {
    print("Tempo ratio: \(tempo):1")
}
```

#### TennisPhaseDetector (`Detectors/TennisPhaseDetector.swift`)
- Supports tennis and pickleball
- Automatic stroke type detection (forehand/backhand/serve)
- Contact zone validation
- Racquet speed estimation

**Tennis-Specific:**
```swift
let detector = TennisPhaseDetector(sport: .tennis, isLeftHanded: false)

// Detector automatically identifies stroke type
print("Stroke: \(detector.strokeType.displayName)")

if detector.isInReadyPosition(pose: pose) {
    print("Split step position")
}
```

#### BaseballPhaseDetector (`Detectors/BaseballPhaseDetector.swift`)
- Supports baseball and softball
- Batting stance validation
- Hip-shoulder separation (X-factor)
- Stride length calculation
- Front foot planting detection

**Baseball-Specific:**
```swift
let detector = BaseballPhaseDetector(sport: .baseball, battingSide: .right)

if let separation = detector.hipShoulderSeparation(pose: pose) {
    print("X-factor: \(separation * 180 / .pi) degrees")
}

if detector.hasProperStance(pose: pose) {
    print("Good batting stance")
}
```

### 4. SwingPhaseDetectorFactory (`SwingPhaseDetectorFactory.swift`)

Factory for creating sport-specific detectors.

**Simple Creation:**
```swift
let detector = SwingPhaseDetectorFactory.createDetector(
    for: .golf,
    isLeftHanded: false
)
```

**Advanced Configuration:**
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

### 5. SwingAnalysisCoordinator (`VisionAnalysisExample.swift`)

High-level coordinator that combines pose detection and phase analysis.

**Real-Time Analysis:**
```swift
let coordinator = SwingAnalysisCoordinator(
    sport: .golf,
    isLeftHanded: false
)

// In AVCaptureVideoDataOutputSampleBufferDelegate
func captureOutput(_ output: AVCaptureOutput,
                   didOutput sampleBuffer: CMSampleBuffer,
                   from connection: AVCaptureConnection) {
    Task {
        try await coordinator.processFrame(sampleBuffer)

        if let analysis = coordinator.currentAnalysis {
            print("Phase: \(analysis.currentPhase.displayName)")
            print("Confidence: \(analysis.confidence)")
        }
    }
}
```

**Video Analysis:**
```swift
let videoURL = URL(fileURLWithPath: "swing.mp4")
let result = try await coordinator.analyzeVideo(url: videoURL)

print("Duration: \(result.duration)s")
print("Avg Confidence: \(result.averageConfidence)")

// Get phase transitions
for transition in result.phaseTransitions {
    print("\(transition.toPhase.displayName) at \(transition.timestamp)s")
}

// Convert to SwingSession
let session = SwingSession(
    sport: .golf,
    videoFileURL: videoURL,
    jointFrames: result.toJointFrames()
)
```

## Data Flow

### Real-Time Camera Analysis
```
Camera Frame (CMSampleBuffer)
    ↓
BodyPoseAnalyzer.processFrame()
    ↓
BodyPose (17 joints with 3D positions)
    ↓
SwingPhaseDetector.detectPhase()
    ↓
SwingAnalysis (current phase + transitions)
```

### Offline Video Analysis
```
Video File URL
    ↓
AVAssetReader (extract frames)
    ↓
For each frame:
    BodyPoseAnalyzer → BodyPose
    SwingPhaseDetector → SwingAnalysis
    ↓
VideoAnalysisResult
    ↓
Convert to JointPositionFrame[]
    ↓
Store in SwingSession (SwiftData)
```

## Integration with Existing Models

The Vision layer seamlessly integrates with existing Swingenuity models:

```swift
// 1. Analyze video
let coordinator = SwingAnalysisCoordinator(sport: .golf)
let result = try await coordinator.analyzeVideo(url: videoURL)

// 2. Convert to existing model format
let jointFrames = result.toJointFrames() // → [JointPositionFrame]

// 3. Create SwingSession
let session = SwingSession(
    sport: .golf,
    videoFileURL: videoURL,
    jointFrames: jointFrames
)

// 4. Pass to existing analyzers
let formAnalyzer = FormAnalyzer()
let metrics = formAnalyzer.analyze(session: session)

// 5. Store in repository
let repository = SwingRepository(modelContext: context)
try await repository.saveAsIdealBaseline(session, for: .golf)
```

## Performance Considerations

**Frame Rate Throttling:**
- Target: 30 FPS (configurable)
- Automatic frame skipping when processing is slow
- Maintains smooth UI updates

**Memory Management:**
- Pose history limited to 60 frames (~2 seconds)
- Automatic cleanup of old frames
- Efficient SIMD operations for geometry

**3D vs 2D Tradeoffs:**
- 3D (LiDAR): More accurate, depth info, requires iPhone 12 Pro+
- 2D: Faster, broader device support, no depth
- Auto mode intelligently switches based on hardware

## Geometry Helpers

Built-in geometric calculations on BodyPose:

```swift
// Distance between joints
let armLength = pose.distance(from: .rightShoulder, to: .rightWrist)

// Angle at joint
let elbowAngle = pose.angle(
    joint1: .rightShoulder,
    vertex: .rightElbow,
    joint2: .rightWrist
)

// Velocity (requires previous pose)
let handVelocity = pose.velocity(of: .rightWrist, from: previousPose)
let speed = simd_length(handVelocity)
```

## Testing Strategy

**Unit Tests:**
- Test phase detection with synthetic pose data
- Verify geometry calculations
- Validate phase transition logic

**Integration Tests:**
- Process sample videos for each sport
- Verify phase detection accuracy
- Test 3D/2D fallback behavior

**Mock Data:**
```swift
// Create test pose
let testPose = BodyPose(
    timestamp: 1.0,
    joints: [
        .rightWrist: BodyJoint(
            name: .rightWrist,
            position: simd_float3(0.5, 1.2, 0.3),
            confidence: 0.95
        )
    ],
    is3D: true,
    overallConfidence: 0.9
)
```

## Future Enhancements

1. **Machine Learning Integration**
   - Train ML models on detected phases
   - Improve phase detection accuracy
   - Personalized swing profiles

2. **Advanced Metrics**
   - Club/bat/racquet speed (using hand velocity × lever arm)
   - Swing plane angle
   - Weight transfer patterns
   - Power generation analysis

3. **Real-Time Feedback**
   - Haptic feedback on phase transitions
   - Audio cues for timing
   - AR overlays showing ideal form

4. **Multi-Person Support**
   - Track multiple players simultaneously
   - Coach-athlete comparison mode
   - Group training sessions

## Troubleshooting

**Low Confidence Scores:**
- Ensure good lighting
- Check camera angle (side view best)
- Verify full body is in frame
- Use 3D mode on supported devices

**Missed Phase Transitions:**
- Increase pose history length
- Lower minimum confidence threshold
- Adjust sport-specific speed thresholds
- Ensure smooth camera motion

**Performance Issues:**
- Use .force2D for older devices
- Reduce frame rate target
- Limit pose history length
- Process videos offline instead of real-time

## Files Reference

| File | Purpose | Lines |
|------|---------|-------|
| `BodyPoseAnalyzer.swift` | Vision API wrapper, 3D/2D pose extraction | ~400 |
| `SwingPhaseDetector.swift` | Base protocol + utilities | ~300 |
| `Detectors/GolfPhaseDetector.swift` | Golf swing detection | ~350 |
| `Detectors/TennisPhaseDetector.swift` | Tennis/pickleball detection | ~350 |
| `Detectors/BaseballPhaseDetector.swift` | Baseball/softball detection | ~350 |
| `SwingPhaseDetectorFactory.swift` | Detector instantiation | ~100 |
| `VisionAnalysisExample.swift` | Integration examples | ~250 |

**Total:** ~2,100 lines of production-ready Swift code

## Dependencies

- iOS 18.0+
- Vision framework
- AVFoundation
- CoreMedia
- simd (built-in)

No external packages required.
