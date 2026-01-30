# Swingenuity Metrics & Scoring System

Complete swing analysis and scoring system for iOS using Vision framework pose detection and SIMD vector mathematics.

## Architecture Overview

```
Analysis/
├── MetricsCalculator.swift       # Main coordinator - orchestrates all analyzers
├── ScoreGenerator.swift          # Final scoring and grading (0-100, A+ to F)
├── SwingRepository.swift         # Baseline storage and retrieval
├── Analyzers/
│   ├── FormAnalyzer.swift        # Body mechanics (angles, rotation, posture)
│   ├── SpeedAnalyzer.swift       # Velocity and acceleration analysis
│   └── ConsistencyAnalyzer.swift # Baseline comparison and repeatability
└── USAGE_EXAMPLE.swift           # Integration examples and documentation
```

## Core Components

### 1. MetricsCalculator
**Main coordinator for all analysis**

- Aggregates metrics from all analyzers
- Handles frame decimation for performance (process every Nth frame)
- Supports dual modes:
  - **Streaming**: Real-time during recording
  - **Post-processing**: Complete video after capture
- Auto-detects swing phases if not provided
- Coordinates parallel metric calculation

**Usage:**
```swift
let calculator = MetricsCalculator(repository: repository, decimationFactor: 2)
let metrics = try await calculator.calculateMetrics(
    frames: session.jointFrames,
    sport: .golf
)
```

### 2. FormAnalyzer
**Analyzes body mechanics and technique**

Calculates:
- **Joint angles** at key swing phases using SIMD
- **Hip rotation** (optimal: 45-90°)
- **Shoulder rotation** (optimal: 90-110°)
- **X-Factor** (hip-shoulder separation, optimal: 20-40°)
- **Spine angle** maintenance (setup vs impact)
- **Weight transfer** via hip/shoulder position shifts (optimal: 60-80%)
- **Arm extension** at key phases (optimal: 80-100%)

**Returns:** `FormMetrics` with composite score (0-100)

### 3. SpeedAnalyzer
**Analyzes velocity and acceleration**

Calculates:
- **Hand velocity** from position deltas (mph)
- **Peak speed** throughout swing
- **Peak acceleration** (mph/s)
- **Impact speed** (should be 90-100% of peak)
- **Time to peak speed** (optimal: 0.2-0.4s)
- **Kinetic chain** sequencing (hips → shoulders → hands)
- **Average power phase speed**

**Returns:** `SpeedMetrics` with composite score (0-100)

### 4. ConsistencyAnalyzer
**Compares to ideal baseline swing**

Requires:
- Stored baseline swing for the sport
- Minimum 2 swings (current + baseline)

Calculates:
- **Speed variance** (optimal: <5 mph)
- **Position variance** (optimal: <0.1 units)
- **Repeatability score** (0-100)
- **Form consistency** across key metrics

**Returns:** `ConsistencyMetrics` with composite score (0-100)

### 5. ScoreGenerator
**Generates overall score and recommendations**

Features:
- **Sport-specific weighting** (golf emphasizes form, baseball emphasizes speed)
- **0-100 overall score** calculation
- **Letter grade** assignment:
  - 90-100: A range
  - 80-89: B range
  - 70-79: C range
  - 60-69: D range
  - Below 60: F
- **Improvement suggestions** with priorities
- **Component breakdown** (form, speed, consistency)

**Returns:** `ScoreResult` with grade, scores, and suggestions

### 6. SwingRepository
**Baseline storage and retrieval**

Protocol-based design with two implementations:
- **SwingRepository**: SwiftData-backed persistence
- **MockSwingRepository**: In-memory for testing

Features:
- Store ideal baseline per sport
- Retrieve recent swings for comparison
- Query swings by sport, date, quality

## Supporting Models

### SwingPhase (Models/SwingPhase.swift)
Defines canonical swing phases:
1. **Setup** - Starting position
2. **Backswing** - Loading phase (~35% of swing)
3. **Transition** - Top of backswing (~10%)
4. **Downswing** - Acceleration phase (~30%)
5. **Impact** - Contact point (~5%)
6. **Follow Through** - Completion (~20%)

### Metrics Structs (Models/SwingMetrics.swift)
- `SwingMetrics` - Container for all metrics
- `FormMetrics` - Body mechanics measurements
- `SpeedMetrics` - Velocity/acceleration data
- `ConsistencyMetrics` - Repeatability scores

## Sport-Specific Weights

### Golf
- Form: 45% (technique critical)
- Speed: 30%
- Consistency: 25%

### Baseball/Softball
- Speed: 45% (bat speed is king)
- Form: 35%
- Consistency: 20%

### Tennis
- Form: 40% (technique critical)
- Speed: 35%
- Consistency: 25%

### Pickleball
- Consistency: 35% (control over power)
- Form: 35%
- Speed: 30%

## Performance Optimization

### Frame Decimation
Process every Nth frame to reduce computational load:
- **Decimation factor 1**: All frames (highest accuracy)
- **Decimation factor 2**: Every 2nd frame (recommended for most cases)
- **Decimation factor 3**: Every 3rd frame (real-time on older devices)

### SIMD Acceleration
All vector math uses SIMD for performance:
- Joint position calculations
- Angle measurements
- Distance computations
- Rotation analysis

### Async/Await
Modern concurrency for smooth UI:
- Parallel metric calculation
- Non-blocking database access
- Background processing support

## Integration Examples

### Post-Processing Analysis
```swift
func analyzeCompletedSwing(session: SwingSession) async throws {
    let calculator = MetricsCalculator(repository: repository)
    let metrics = try await calculator.calculateMetrics(
        frames: session.jointFrames,
        sport: session.sport
    )

    let generator = ScoreGenerator()
    let result = generator.generateScore(from: metrics, sport: session.sport)

    session.updateMetrics(metrics)
    displayResults(result)
}
```

### Streaming Analysis
```swift
func onNewFrameCaptured(_ frame: JointPositionFrame) {
    accumulatedFrames.append(frame)

    if accumulatedFrames.count % 10 == 0 {
        if let metrics = calculator.calculateStreamingMetrics(
            frames: accumulatedFrames,
            sport: currentSport
        ) {
            updateRealtimeUI(with: metrics)
        }
    }
}
```

### Setting Baseline
```swift
func setCurrentSwingAsBaseline(session: SwingSession) async throws {
    try await repository.saveAsIdealBaseline(session, for: session.sport)
}
```

## Key Measurements

### Form Metrics
- Hip rotation: 45-90° optimal
- Shoulder rotation: 90-110° optimal
- X-factor: 20-40° optimal
- Weight transfer: 60-80% optimal
- Spine deviation: <10° optimal
- Arm extension: 80-100% optimal

### Speed Metrics (Golf)
- Peak speed: 80-120 mph optimal
- Impact efficiency: 90-100% of peak
- Acceleration: 800-1500 mph/s optimal
- Time to peak: 0.2-0.4s optimal

### Consistency Metrics
- Speed variance: <5 mph optimal
- Position variance: <0.1 units optimal
- Repeatability: >70 for good consistency

## Testing

Use `MockSwingRepository` for unit tests:
```swift
let mockRepo = MockSwingRepository()
mockRepo.addSession(testSession)
try await mockRepo.saveAsIdealBaseline(baseline, for: .golf)

let calculator = MetricsCalculator(repository: mockRepo)
// Test your analysis code
```

## Future Enhancements

1. **ML-based phase detection** - Replace heuristic detection
2. **Multi-baseline comparison** - Compare to multiple ideal swings
3. **Trend analysis** - Track improvement over time
4. **3D visualization** - Integrate with RealityKit
5. **Export formats** - Industry-standard swing data formats
6. **Advanced kinetic chain** - More detailed sequencing analysis
7. **Sport-specific drills** - Targeted practice recommendations

## Dependencies

- **Foundation** - Core Swift functionality
- **simd** - Vector mathematics acceleration
- **SwiftData** - Persistence layer (via SwingRepository)

## Notes

- All joint names use Vision framework identifiers (e.g., "left_shoulder", "right_hip")
- Coordinates are in Vision's normalized 3D space
- Timestamps are in seconds from video/session start
- All angles in degrees (converted from radians internally)
- Speeds in miles per hour (converted from m/s internally)

## Credits

Built for Swingenuity iOS app - AI-powered swing analysis for golf, baseball, softball, tennis, and pickleball.
