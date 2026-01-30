import Foundation
import SwiftData

/// Protocol for managing baseline swing storage and retrieval
@MainActor
protocol SwingRepositoryProtocol: Sendable {
    /// Get the ideal baseline swing for a specific sport
    func getIdealBaseline(for sport: Sport) async throws -> SwingSession?

    /// Save a swing session as the ideal baseline for a sport
    func saveAsIdealBaseline(_ session: SwingSession, for sport: Sport) async throws

    /// Get all swing sessions for a specific sport
    func getSwingSessions(for sport: Sport) async throws -> [SwingSession]

    /// Get recent swing sessions (for consistency analysis)
    func getRecentSwings(for sport: Sport, limit: Int) async throws -> [SwingSession]
}

/// SwiftData-backed implementation of SwingRepository
@MainActor
final class SwingRepository: SwingRepositoryProtocol {
    private let modelContext: ModelContext

    /// Key for storing ideal baseline session IDs in UserDefaults
    private let idealBaselineKey = "ideal_baseline_sessions"

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Baseline Management

    func getIdealBaseline(for sport: Sport) async throws -> SwingSession? {
        // Get stored baseline ID for this sport
        guard let baselineID = getStoredBaselineID(for: sport) else {
            return nil
        }

        // Fetch the session with this ID
        let descriptor = FetchDescriptor<SwingSession>(
            predicate: #Predicate { session in
                session.id == baselineID
            }
        )

        let sessions = try modelContext.fetch(descriptor)
        return sessions.first
    }

    func saveAsIdealBaseline(_ session: SwingSession, for sport: Sport) async throws {
        // Store the session ID as the baseline for this sport
        var baselines = UserDefaults.standard.dictionary(forKey: idealBaselineKey) as? [String: String] ?? [:]
        baselines[sport.rawValue] = session.id.uuidString
        UserDefaults.standard.set(baselines, forKey: idealBaselineKey)

        // Ensure session is saved in context
        modelContext.insert(session)
        try modelContext.save()
    }

    // MARK: - Session Queries

    func getSwingSessions(for sport: Sport) async throws -> [SwingSession] {
        let descriptor = FetchDescriptor<SwingSession>(
            predicate: SwingSession.predicateBySport(sport),
            sortBy: [SwingSession.sortByDateDescending]
        )

        return try modelContext.fetch(descriptor)
    }

    func getRecentSwings(for sport: Sport, limit: Int = 10) async throws -> [SwingSession] {
        var descriptor = FetchDescriptor<SwingSession>(
            predicate: SwingSession.predicateBySport(sport),
            sortBy: [SwingSession.sortByDateDescending]
        )
        descriptor.fetchLimit = limit

        return try modelContext.fetch(descriptor)
    }

    // MARK: - Private Helpers

    private func getStoredBaselineID(for sport: Sport) -> UUID? {
        guard let baselines = UserDefaults.standard.dictionary(forKey: idealBaselineKey) as? [String: String],
              let idString = baselines[sport.rawValue],
              let uuid = UUID(uuidString: idString) else {
            return nil
        }
        return uuid
    }
}

/// In-memory implementation for testing and previews
final class MockSwingRepository: SwingRepositoryProtocol {
    private var sessions: [SwingSession] = []
    private var baselines: [Sport: SwingSession] = [:]

    func getIdealBaseline(for sport: Sport) async throws -> SwingSession? {
        return baselines[sport]
    }

    func saveAsIdealBaseline(_ session: SwingSession, for sport: Sport) async throws {
        baselines[sport] = session
        if !sessions.contains(where: { $0.id == session.id }) {
            sessions.append(session)
        }
    }

    func getSwingSessions(for sport: Sport) async throws -> [SwingSession] {
        return sessions.filter { $0.sport == sport }
            .sorted { $0.dateRecorded > $1.dateRecorded }
    }

    func getRecentSwings(for sport: Sport, limit: Int = 10) async throws -> [SwingSession] {
        return Array(try await getSwingSessions(for: sport).prefix(limit))
    }

    /// Test helper to add sessions
    func addSession(_ session: SwingSession) {
        sessions.append(session)
    }
}
