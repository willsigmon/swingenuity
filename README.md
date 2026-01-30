# Swingenuity

AI-powered swing analysis app for iOS supporting multiple sports (golf, tennis, pickleball, baseball, softball).

## Project Status

### ✅ Completed: Data Models Layer

The complete data persistence and analytics layer is implemented using SwiftData.

**Features:**
- 5 core model files (Sport, Rating, JointPositionFrame, SwingMetrics, SwingSession)
- Comprehensive utilities and helper functions
- Full documentation with examples
- SwiftData integration configured
- Production-ready code (~51 KB, 2,358 lines)

### 🚧 In Progress: None

### 📋 Planned

1. **Video Recording** (Phase 1)
2. **Vision Framework Integration** (Phase 2)
3. **Metrics Calculation Engine** (Phase 3)
4. **UI Views** (Phase 4)
5. **Advanced Features** (Phase 5)

## Quick Start

### View the Data Models

```bash
cd Swingenuity/Models/
```

**Start here:**
- `QUICK_REFERENCE.swift` - Copy-paste ready code snippets
- `ModelExamples.swift` - Full usage examples
- `README.md` - Architecture documentation

### Understanding the Architecture

**Root Documentation:**
- `IMPLEMENTATION_COMPLETE.md` - Complete status and overview
- `MODELS_SUMMARY.md` - Detailed implementation guide
- `DATA_MODEL_DIAGRAM.md` - Visual diagrams and relationships
- `NEXT_STEPS.md` - Roadmap for next phases

### Test the Models

Add this to `ContentView.swift`:

```swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query var sessions: [SwingSession]

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.golf")
                .imageScale(.large)
                .font(.system(size: 60))
                .foregroundStyle(.tint)

            Text("Swingenuity")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("\(sessions.count) sessions")
                .font(.headline)
                .foregroundStyle(.secondary)

            Button("Create Test Session") {
                createTestSession()
            }
            .buttonStyle(.borderedProminent)

            if !sessions.isEmpty {
                List(sessions) { session in
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: session.sport.symbolName)
                            Text(session.sport.displayName)
                                .font(.headline)
                        }

                        if let rating = session.rating {
                            Text("\(rating.letterGrade.rawValue) - \(Int(rating.score))")
                                .font(.subheadline)
                                .foregroundColor(rating.color)
                        }

                        Text(session.formattedDate())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
    }

    private func createTestSession() {
        let session = SwingSession(
            sport: .golf,
            notes: "Test session created \(Date())"
        )

        let metrics = SwingMetrics(
            formMetrics: FormMetrics(
                hipRotationAngle: Double.random(in: 50...80),
                shoulderRotationAngle: Double.random(in: 85...110),
                spineAngleAtAddress: 30,
                spineAngleAtImpact: 32,
                weightTransferPercentage: Double.random(in: 60...80),
                armExtensionScore: Double.random(in: 75...95)
            ),
            speedMetrics: SpeedMetrics(
                peakSpeed: Double.random(in: 95...115),
                peakAcceleration: Double.random(in: 1100...1400),
                averageSpeed: Double.random(in: 85...100),
                timeToPeakSpeed: Double.random(in: 0.25...0.35),
                impactSpeed: Double.random(in: 93...113)
            )
        )

        session.updateMetrics(metrics)
        modelContext.insert(session)

        do {
            try modelContext.save()
        } catch {
            print("Error saving session: \(error)")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [SwingSession.self])
}
```

Run the app and tap "Create Test Session" to verify SwiftData integration works.

## Architecture

```
SwingSession (@Model - Persisted)
├── Sport (enum): golf, tennis, pickleball, baseball, softball
├── [JointPositionFrame]: Array of pose data frames
│   ├── timestamp: Double
│   ├── jointPositions: [String: SIMD3<Float>]
│   └── confidenceScores: [String: Float]
├── SwingMetrics: Calculated performance metrics
│   ├── FormMetrics: angles, rotation, weight transfer
│   ├── SpeedMetrics: velocity, acceleration, timing
│   └── ConsistencyMetrics?: variance, repeatability
└── Rating: Letter grade (A+ to F) from 0-100 score
```

## Technology Stack

### Current
- **SwiftUI** - UI framework
- **SwiftData** - Data persistence
- **Foundation** - Base types
- **simd** - 3D vector math

### Planned
- **AVFoundation** - Video recording and playback
- **Vision** - Body pose detection
- **Charts** - Metrics visualization
- **AVKit** - Video player

## Requirements

- **iOS**: 17.0+ (SwiftData requirement)
- **Xcode**: 15.0+
- **Swift**: 5.9+

## Project Structure

```
swingenuity/
├── IMPLEMENTATION_COMPLETE.md    Status report
├── MODELS_SUMMARY.md             Implementation overview
├── DATA_MODEL_DIAGRAM.md         Visual diagrams
├── NEXT_STEPS.md                 Roadmap
│
└── Swingenuity/
    ├── SwingenuityApp.swift      App entry point
    ├── ContentView.swift         Main view
    │
    └── Models/                   ⭐️ COMPLETE
        ├── Sport.swift
        ├── Rating.swift
        ├── JointPositionFrame.swift
        ├── SwingMetrics.swift
        ├── SwingSession.swift
        ├── ModelUtilities.swift
        ├── ModelExamples.swift
        ├── QUICK_REFERENCE.swift
        └── README.md
```

## Features

### Completed ✅

- **Multi-Sport Support**: Golf, Tennis, Pickleball, Baseball, Softball
- **Grading System**: 13-level letter grades (A+ through F)
- **Pose Data Storage**: Frame-by-frame joint positions with confidence scores
- **Performance Metrics**:
  - Form analysis (rotation, spine angle, weight transfer)
  - Speed analysis (peak speed, acceleration, timing)
  - Consistency tracking (variance, repeatability)
- **Session Management**:
  - SwiftData persistence
  - Video and thumbnail storage
  - Notes and tags
  - Favorites
- **Query System**: Sport, date, quality, favorite filters
- **Utilities**: Geometry calculations, statistics, validation, export
- **Documentation**: Comprehensive docs with examples

### Planned 📋

- Video recording and capture
- Vision Framework pose detection
- Real-time swing analysis
- Metrics visualization
- Progress tracking
- Session comparison
- Export and sharing
- Cloud sync

## Development Roadmap

### Phase 1: Video Recording (Next)
- Camera service with AVFoundation
- Video capture UI
- Thumbnail generation
- **ETA**: 3-5 days

### Phase 2: Vision Integration
- Body pose detection
- Frame extraction
- Joint position mapping
- **ETA**: 3-5 days

### Phase 3: Metrics Engine
- Angle calculations from pose data
- Speed and acceleration analysis
- Form scoring algorithms
- **ETA**: 4-6 days

### Phase 4: UI Views
- Session list with filtering
- Session detail with video playback
- Metrics visualization
- **ETA**: 5-7 days

### Phase 5: Advanced Features
- Progress tracking over time
- Side-by-side comparison
- Export and sharing
- **ETA**: 4-6 days

**Total to MVP**: 3-4 weeks
**Total to v1.0**: 5-6 weeks

## Documentation

### For Developers
- [QUICK_REFERENCE.swift](Swingenuity/Models/QUICK_REFERENCE.swift) - Copy-paste snippets
- [ModelExamples.swift](Swingenuity/Models/ModelExamples.swift) - Full examples
- [ModelUtilities.swift](Swingenuity/Models/ModelUtilities.swift) - Helper functions
- [Models/README.md](Swingenuity/Models/README.md) - Architecture guide

### For Planning
- [IMPLEMENTATION_COMPLETE.md](IMPLEMENTATION_COMPLETE.md) - Status report
- [MODELS_SUMMARY.md](MODELS_SUMMARY.md) - Implementation details
- [DATA_MODEL_DIAGRAM.md](DATA_MODEL_DIAGRAM.md) - Visual diagrams
- [NEXT_STEPS.md](NEXT_STEPS.md) - Implementation roadmap

## Resources

### Apple Documentation
- [SwiftData](https://developer.apple.com/documentation/swiftdata)
- [Vision Framework](https://developer.apple.com/documentation/vision)
- [AVFoundation](https://developer.apple.com/documentation/avfoundation)
- [Charts](https://developer.apple.com/documentation/charts)

### Key Sample Code
- [Detecting Human Body Poses](https://developer.apple.com/documentation/vision/detecting_human_body_poses_in_images)
- [Building a Camera App](https://developer.apple.com/documentation/avfoundation/capture_setup/avcam_building_a_camera_app)

## License

Copyright © 2026 - All rights reserved

---

## Current Status

**Phase**: Data Models Complete ✅
**Next**: Video Recording (Phase 1)
**Ready**: Production-ready data layer with full documentation

---

**Built with SwiftUI and SwiftData for iOS 17+**
