import Foundation
import SwiftData

/// SwiftData model representing a single swing analysis session
@Model
final class SwingSession {
    /// Unique identifier
    var id: UUID

    /// Date and time when the session was recorded
    var dateRecorded: Date

    /// Sport type for this swing
    var sport: Sport

    /// URL to the locally stored video file
    var videoFileURL: URL?

    /// Array of joint position frames captured from video analysis
    var jointFrames: [JointPositionFrame]

    /// Calculated metrics from the swing analysis
    var metrics: SwingMetrics?

    /// Overall rating for the swing
    var rating: Rating?

    /// User-added notes about the session
    var notes: String

    /// Thumbnail image data for quick preview
    @Attribute(.externalStorage)
    var thumbnailData: Data?

    /// Flag to mark favorite sessions
    var isFavorite: Bool

    /// Tags for categorizing sessions
    var tags: [String]

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        dateRecorded: Date = Date(),
        sport: Sport,
        videoFileURL: URL? = nil,
        jointFrames: [JointPositionFrame] = [],
        metrics: SwingMetrics? = nil,
        rating: Rating? = nil,
        notes: String = "",
        thumbnailData: Data? = nil,
        isFavorite: Bool = false,
        tags: [String] = []
    ) {
        self.id = id
        self.dateRecorded = dateRecorded
        self.sport = sport
        self.videoFileURL = videoFileURL
        self.jointFrames = jointFrames
        self.metrics = metrics
        self.rating = rating
        self.notes = notes
        self.thumbnailData = thumbnailData
        self.isFavorite = isFavorite
        self.tags = tags
    }

    // MARK: - Computed Properties

    /// Duration of the swing in seconds (based on joint frames)
    var duration: Double {
        guard let firstFrame = jointFrames.first,
              let lastFrame = jointFrames.last else {
            return 0
        }
        return lastFrame.timestamp - firstFrame.timestamp
    }

    /// Number of frames in the analysis
    var frameCount: Int {
        jointFrames.count
    }

    /// Average frame confidence across all frames
    var averageFrameConfidence: Float {
        guard !jointFrames.isEmpty else { return 0 }
        let totalConfidence = jointFrames.reduce(0.0) { $0 + $1.averageConfidence }
        return totalConfidence / Float(jointFrames.count)
    }

    /// Whether the session has valid analysis data
    var hasValidAnalysis: Bool {
        return !jointFrames.isEmpty && metrics != nil
    }

    /// Quality indicator for the session (0-100)
    var qualityScore: Double {
        guard hasValidAnalysis else { return 0 }

        var score = 0.0

        // Frame confidence contributes 40%
        score += Double(averageFrameConfidence) * 40

        // Frame count adequacy contributes 30% (at least 30 frames is good)
        let frameQuality = min(Double(frameCount) / 30.0, 1.0)
        score += frameQuality * 30

        // Having a rating contributes 30%
        if rating != nil {
            score += 30
        }

        return score
    }

    // MARK: - Methods

    /// Add a new joint frame to the session
    func addFrame(_ frame: JointPositionFrame) {
        jointFrames.append(frame)
    }

    /// Update metrics for the session
    func updateMetrics(_ newMetrics: SwingMetrics) {
        self.metrics = newMetrics

        // Auto-update rating based on overall score
        if let overallScore = metrics?.overallScore {
            self.rating = Rating(score: overallScore)
        }
    }

    /// Add a tag to the session
    func addTag(_ tag: String) {
        if !tags.contains(tag) {
            tags.append(tag)
        }
    }

    /// Remove a tag from the session
    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }

    /// Toggle favorite status
    func toggleFavorite() {
        isFavorite.toggle()
    }

    /// Get formatted date string
    func formattedDate(style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .short
        return formatter.string(from: dateRecorded)
    }
}

// MARK: - Query Helpers

extension SwingSession {
    /// Predicate to filter sessions by sport
    static func predicateBySport(_ sport: Sport) -> Predicate<SwingSession> {
        #Predicate<SwingSession> { session in
            session.sport == sport
        }
    }

    /// Predicate to filter favorite sessions
    static var predicateFavorites: Predicate<SwingSession> {
        #Predicate<SwingSession> { session in
            session.isFavorite == true
        }
    }

    /// Predicate to filter sessions by date range
    static func predicateByDateRange(from startDate: Date, to endDate: Date) -> Predicate<SwingSession> {
        #Predicate<SwingSession> { session in
            session.dateRecorded >= startDate && session.dateRecorded <= endDate
        }
    }

    /// Predicate to filter sessions by minimum quality score
    static func predicateByMinimumQuality(_ minScore: Double) -> Predicate<SwingSession> {
        let minConfidence = Float(minScore / 100.0)
        return #Predicate<SwingSession> { session in
            session.averageFrameConfidence >= minConfidence
        }
    }
}

// MARK: - Sort Descriptors

extension SwingSession {
    /// Sort by date (newest first)
    static var sortByDateDescending: SortDescriptor<SwingSession> {
        SortDescriptor(\.dateRecorded, order: .reverse)
    }

    /// Sort by date (oldest first)
    static var sortByDateAscending: SortDescriptor<SwingSession> {
        SortDescriptor(\.dateRecorded, order: .forward)
    }

    /// Sort by sport (using date as a fallback since Sport enum isn't directly sortable)
    static var sortBySport: SortDescriptor<SwingSession> {
        SortDescriptor(\.dateRecorded)
    }
}
