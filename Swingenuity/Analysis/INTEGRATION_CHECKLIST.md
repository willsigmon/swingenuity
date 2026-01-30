# Integration Checklist for Swingenuity Metrics System

## Prerequisites

- [x] SwiftData ModelContainer configured
- [x] JointPositionFrame model exists
- [x] SwingSession model exists
- [x] SwingMetrics structs defined
- [x] Sport enum with 5 sports
- [x] Vision framework pose detection working

## Files to Add to Xcode Project

Add all files from `Analysis/` folder to your Xcode project:

### Core Files (Required)
- [ ] `Analysis/MetricsCalculator.swift`
- [ ] `Analysis/ScoreGenerator.swift`
- [ ] `Analysis/SwingRepository.swift`

### Analyzer Files (Required)
- [ ] `Analysis/Analyzers/FormAnalyzer.swift`
- [ ] `Analysis/Analyzers/SpeedAnalyzer.swift`
- [ ] `Analysis/Analyzers/ConsistencyAnalyzer.swift`

### Model Files (Required)
- [ ] `Models/SwingPhase.swift` (add to Models group)

### Documentation (Optional)
- [ ] `Analysis/README.md`
- [ ] `Analysis/USAGE_EXAMPLE.swift` (exclude from compilation)

## Integration Steps

### 1. Add Files to Xcode
```bash
# In Xcode:
1. Right-click on "Analysis" folder (or create it)
2. Add Files to "Swingenuity"...
3. Select all .swift files from Analysis/ folder
4. Ensure "Copy items if needed" is checked
5. Add to target: Swingenuity
```

### 2. Initialize Repository
```swift
// In your App file or root view
@Environment(\.modelContext) private var modelContext

var swingRepository: SwingRepository {
    SwingRepository(modelContext: modelContext)
}
```

### 3. Create Metrics Calculator Instance
```swift
// In your analysis view or service
let calculator = MetricsCalculator(
    repository: swingRepository,
    decimationFactor: 2  // Adjust based on performance needs
)
```

### 4. Implement Post-Processing Analysis
```swift
// After recording completes
func analyzeRecordedSwing(_ session: SwingSession) async {
    do {
        // Calculate metrics
        let metrics = try await calculator.calculateMetrics(
            frames: session.jointFrames,
            sport: session.sport
        )

        // Generate score
        let generator = ScoreGenerator()
        let result = generator.generateScore(
            from: metrics,
            sport: session.sport
        )

        // Update session
        session.updateMetrics(metrics)

        // Navigate to results view
        showResults(result)

    } catch {
        showError(error)
    }
}
```

### 5. Implement Streaming Analysis (Optional)
```swift
// During recording
class RecordingViewModel: ObservableObject {
    @Published var currentMetrics: SwingMetrics?
    private var frames: [JointPositionFrame] = []

    func onFrameCaptured(_ frame: JointPositionFrame) {
        frames.append(frame)

        // Update every 10 frames
        if frames.count % 10 == 0 {
            currentMetrics = calculator.calculateStreamingMetrics(
                frames: frames,
                sport: selectedSport
            )
        }
    }
}
```

### 6. Create Results View
```swift
struct ResultsView: View {
    let result: ScoreResult

    var body: some View {
        VStack {
            // Overall score
            Text("\(Int(result.overallScore))")
                .font(.system(size: 72, weight: .bold))

            Text(result.grade.displayName)
                .font(.title)
                .foregroundStyle(gradeColor(result.grade))

            // Component scores
            HStack(spacing: 20) {
                ScoreCard(
                    title: "Form",
                    score: result.componentScores.form,
                    icon: "figure.stand"
                )

                ScoreCard(
                    title: "Speed",
                    score: result.componentScores.speed,
                    icon: "speedometer"
                )

                if let consistency = result.componentScores.consistency {
                    ScoreCard(
                        title: "Consistency",
                        score: consistency,
                        icon: "arrow.clockwise"
                    )
                }
            }

            // Suggestions
            SuggestionsListView(suggestions: result.suggestions)
        }
    }

    func gradeColor(_ grade: LetterGrade) -> Color {
        switch grade.color {
        case "green": return .green
        case "blue": return .blue
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        default: return .primary
        }
    }
}

struct ScoreCard: View {
    let title: String
    let score: Double
    let icon: String

    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.title)
            Text(title)
                .font(.caption)
            Text("\(Int(score))")
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}
```

### 7. Implement Baseline Management
```swift
// Set baseline
func setAsBaseline(_ session: SwingSession) async {
    do {
        try await swingRepository.saveAsIdealBaseline(
            session,
            for: session.sport
        )
        showSuccessMessage("Set as baseline for \(session.sport.displayName)")
    } catch {
        showError(error)
    }
}

// Check if baseline exists
func checkBaseline(for sport: Sport) async -> Bool {
    do {
        let baseline = try await swingRepository.getIdealBaseline(for: sport)
        return baseline != nil
    } catch {
        return false
    }
}
```

## Testing Checklist

### Unit Tests
- [ ] Test FormAnalyzer with sample frames
- [ ] Test SpeedAnalyzer calculations
- [ ] Test ConsistencyAnalyzer with baseline
- [ ] Test ScoreGenerator with various metrics
- [ ] Test MetricsCalculator decimation
- [ ] Test SwingRepository storage/retrieval

### Integration Tests
- [ ] Test complete analysis flow
- [ ] Test streaming mode performance
- [ ] Test baseline comparison
- [ ] Test sport-specific weighting
- [ ] Test grade calculation accuracy
- [ ] Test suggestion generation

### UI Tests
- [ ] Results view displays correctly
- [ ] Suggestions list is interactive
- [ ] Baseline management works
- [ ] Real-time metrics update
- [ ] Score animations work
- [ ] Export/share functionality

## Performance Optimization

### Frame Decimation Strategy
```swift
// Adjust based on device and frame count
let decimationFactor: Int = {
    if frames.count < 60 {
        return 1  // Process all frames
    } else if frames.count < 120 {
        return 2  // Every 2nd frame
    } else {
        return 3  // Every 3rd frame
    }
}()
```

### Background Processing
```swift
// Use Task for heavy calculations
Task {
    let metrics = try await calculator.calculateMetrics(...)
    await MainActor.run {
        updateUI(with: metrics)
    }
}
```

## Common Issues & Solutions

### Issue: Metrics are all zero
**Solution:** Check that JointPositionFrame has valid joint positions with proper keys
```swift
// Verify joint position keys match
print(frame.jointPositions.keys)
// Should include: "left_shoulder", "right_hip", etc.
```

### Issue: Consistency metrics always nil
**Solution:** Ensure baseline is set for the sport
```swift
let hasBaseline = try? await repository.getIdealBaseline(for: sport) != nil
if !hasBaseline {
    // Prompt user to set baseline
}
```

### Issue: Performance is slow
**Solution:** Increase decimation factor or reduce frame count
```swift
// Option 1: Increase decimation
let calculator = MetricsCalculator(repository: repo, decimationFactor: 3)

// Option 2: Sample frames before analysis
let sampledFrames = stride(from: 0, to: frames.count, by: 2).map { frames[$0] }
```

### Issue: Angles seem incorrect
**Solution:** Verify Vision framework joint names match analyzer expectations
```swift
// Standard Vision joint names:
// head, neck, left_shoulder, right_shoulder, left_elbow, right_elbow,
// left_wrist, right_wrist, left_hip, right_hip, left_knee, right_knee,
// left_ankle, right_ankle, root
```

## Next Steps After Integration

1. **Calibration**: Test with real swings and adjust optimal ranges if needed
2. **UI Polish**: Design beautiful results screens with animations
3. **Data Export**: Add export to CSV, PDF, or video overlay
4. **Social Features**: Share results with friends or coaches
5. **Progress Tracking**: Build charts showing improvement over time
6. **Drills**: Add targeted practice recommendations
7. **Video Overlay**: Render metrics on top of video playback
8. **Comparison View**: Side-by-side comparison of multiple swings

## Support

- See `README.md` for architecture details
- See `USAGE_EXAMPLE.swift` for code examples
- Check inline documentation in each file
- Review existing models in `Models/` folder

## Verification Commands

```bash
# Count lines of code
find Swingenuity/Analysis -name "*.swift" -exec wc -l {} +

# List all files
find Swingenuity/Analysis -name "*.swift" | sort

# Check for TODOs
grep -r "TODO" Swingenuity/Analysis/

# Verify imports
grep -r "import" Swingenuity/Analysis/*.swift
```

---

**Status**: System ready for integration. All files created and documented.

**Total Code**: ~3,800 lines across 8 Swift files

**Last Updated**: 2026-01-29
