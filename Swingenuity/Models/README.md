# Swingenuity Data Models

This directory contains the core data models for the Swingenuity iOS app, built using SwiftData for persistence.

## Model Architecture

### Core Models

#### `SwingSession.swift` - SwiftData Model
The primary persisted entity representing a complete swing analysis session.

**Key Properties:**
- `id: UUID` - Unique identifier
- `dateRecorded: Date` - When the session was captured
- `sport: Sport` - Type of sport (golf, tennis, etc.)
- `videoFileURL: URL?` - Local file path to stored video
- `jointFrames: [JointPositionFrame]` - All captured pose data
- `metrics: SwingMetrics?` - Calculated performance metrics
- `rating: Rating?` - Overall grade
- `notes: String` - User annotations
- `thumbnailData: Data?` - Preview image (stored externally)
- `isFavorite: Bool` - Favorite flag
- `tags: [String]` - Custom categorization

**Query Helpers:**
- `predicateBySport(_:)` - Filter by sport type
- `predicateFavorites` - Get favorite sessions
- `predicateByDateRange(from:to:)` - Date range filtering
- `predicateByMinimumQuality(_:)` - Quality threshold filtering

**Sort Descriptors:**
- `sortByDateDescending` - Newest first
- `sortByDateAscending` - Oldest first
- `sortBySport` - Alphabetical by sport

#### `Sport.swift` - Enum
Supported sports with display metadata.

**Cases:**
- `golf` - Golf swing analysis
- `tennis` - Tennis stroke analysis
- `pickleball` - Pickleball swing analysis
- `baseball` - Baseball batting analysis
- `softball` - Softball batting analysis

**Properties:**
- `displayName` - Human-readable name
- `symbolName` - SF Symbol icon identifier
- `defaultMetricWeights` - Sport-specific scoring weights

#### `Rating.swift` - Value Types
Rating system for swing evaluation.

**LetterGrade Enum:**
- A+ through F grading scale (13 grades)
- Associated colors for UI display
- Numeric values for sorting

**Rating Struct:**
- `score: Double` - 0-100 numeric score
- `letterGrade` - Computed letter grade
- `color` - UI display color

#### `JointPositionFrame.swift` - Value Type
Single frame of joint position data from Vision framework.

**Properties:**
- `id: UUID` - Frame identifier
- `timestamp: Double` - Time in seconds from video start
- `jointPositions: [String: SIMD3<Float>]` - 3D joint positions
- `confidenceScores: [String: Float]` - Detection confidence per joint

**Helpers:**
- `averageConfidence` - Overall frame quality
- `hasMinimumQuality(threshold:)` - Quality check
- `position(for:)` - Get specific joint position
- `confidence(for:)` - Get specific joint confidence

#### `SwingMetrics.swift` - Calculated Analytics
Comprehensive swing analysis metrics.

**FormMetrics:**
- Hip and shoulder rotation angles
- Spine angle measurements
- Weight transfer percentage
- Arm extension score
- X-factor (shoulder-hip separation)
- Composite form score (0-100)

**SpeedMetrics:**
- Peak speed
- Peak acceleration
- Average speed during power phase
- Time to peak speed
- Impact speed
- Composite speed score (0-100)

**ConsistencyMetrics:** (requires multiple swings)
- Speed variance across swings
- Position variance
- Repeatability score
- Swing count
- Composite consistency score (0-100)

**SwingMetrics:**
- Combines all metric types
- `overallScore` - Weighted composite (0-100)

## Data Flow

```
Video Recording
    ↓
Vision Framework Analysis
    ↓
JointPositionFrame[] (raw pose data)
    ↓
Metrics Calculation
    ↓
SwingMetrics (analyzed performance)
    ↓
Rating (grade assignment)
    ↓
SwingSession (persisted via SwiftData)
```

## Usage Examples

### Creating a New Session

```swift
let session = SwingSession(
    sport: .golf,
    videoFileURL: localVideoURL,
    jointFrames: analyzedFrames,
    metrics: calculatedMetrics,
    rating: Rating(score: 85.5),
    notes: "Good rotation, work on follow-through"
)
```

### Querying Sessions

```swift
@Query(
    filter: SwingSession.predicateBySport(.golf),
    sort: [SwingSession.sortByDateDescending]
)
var golfSessions: [SwingSession]
```

### Calculating Metrics

```swift
let formMetrics = FormMetrics(
    hipRotationAngle: 60.0,
    shoulderRotationAngle: 95.0,
    spineAngleAtAddress: 30.0,
    spineAngleAtImpact: 32.0,
    weightTransferPercentage: 70.0,
    armExtensionScore: 85.0
)

let speedMetrics = SpeedMetrics(
    peakSpeed: 105.0,
    peakAcceleration: 1200.0,
    averageSpeed: 95.0,
    timeToPeakSpeed: 0.3,
    impactSpeed: 103.0
)

let metrics = SwingMetrics(
    formMetrics: formMetrics,
    speedMetrics: speedMetrics
)

// metrics.overallScore provides 0-100 composite score
```

## SwiftData Configuration

The app's model container is configured in `SwingenuityApp.swift`:

```swift
.modelContainer(for: [
    SwingSession.self
])
```

## Design Notes

1. **Single Source of Truth**: `SwingSession` is the only SwiftData `@Model`. All other types are value types (structs/enums) that compose into it.

2. **Codable Throughout**: All types conform to `Codable` for seamless SwiftData persistence and potential future data export.

3. **Type Safety**: Strongly typed enums and structs prevent invalid states.

4. **Computed Metrics**: Scoring logic is embedded in the model layer with clear algorithms for transparency and adjustability.

5. **External Storage**: Video files stored separately via URLs; thumbnails use SwiftData's `@Attribute(.externalStorage)` for efficient memory usage.

6. **Query Optimization**: Static predicates and sort descriptors provide reusable, type-safe queries.

## Future Enhancements

- Comparison sessions (side-by-side analysis)
- Goal tracking and progress over time
- Export to common formats (CSV, JSON)
- Cloud sync via CloudKit
- Shared sessions for coaching
