import Foundation
import SwiftData
import Observation

@Observable
final class SwingHistoryViewModel {
    // MARK: - State
    var selectedSport: Sport?
    var sortOption: SortOption = .dateDescending
    var searchText = ""
    var selectedSession: SwingSession?
    var showingDeleteConfirmation = false
    var sessionToDelete: SwingSession?

    // MARK: - Computed Properties

    var filterPredicate: Predicate<SwingSession>? {
        if let sport = selectedSport {
            return SwingSession.predicateBySport(sport)
        }
        return nil
    }

    var sortDescriptor: SortDescriptor<SwingSession> {
        switch sortOption {
        case .dateDescending:
            return SwingSession.sortByDateDescending
        case .dateAscending:
            return SwingSession.sortByDateAscending
        case .scoreHighToLow:
            return SwingSession.sortByDateDescending // Fallback - will need custom sort
        case .scoreLowToHigh:
            return SwingSession.sortByDateDescending // Fallback - will need custom sort
        }
    }

    // MARK: - Actions

    func selectSport(_ sport: Sport?) {
        selectedSport = sport
    }

    func changeSortOption(_ option: SortOption) {
        sortOption = option
    }

    func selectSession(_ session: SwingSession) {
        selectedSession = session
    }

    func requestDelete(_ session: SwingSession) {
        sessionToDelete = session
        showingDeleteConfirmation = true
    }

    func confirmDelete(from modelContext: ModelContext) {
        guard let session = sessionToDelete else { return }
        modelContext.delete(session)
        try? modelContext.save()
        sessionToDelete = nil
        showingDeleteConfirmation = false
    }

    func cancelDelete() {
        sessionToDelete = nil
        showingDeleteConfirmation = false
    }

    func toggleFavorite(_ session: SwingSession, in modelContext: ModelContext) {
        session.toggleFavorite()
        try? modelContext.save()
    }

    func sortedSessions(_ sessions: [SwingSession]) -> [SwingSession] {
        switch sortOption {
        case .dateDescending:
            return sessions.sorted { $0.dateRecorded > $1.dateRecorded }
        case .dateAscending:
            return sessions.sorted { $0.dateRecorded < $1.dateRecorded }
        case .scoreHighToLow:
            return sessions.sorted { ($0.rating?.score ?? 0) > ($1.rating?.score ?? 0) }
        case .scoreLowToHigh:
            return sessions.sorted { ($0.rating?.score ?? 0) < ($1.rating?.score ?? 0) }
        }
    }

    func filteredSessions(_ sessions: [SwingSession]) -> [SwingSession] {
        var filtered = sessions

        if let sport = selectedSport {
            filtered = filtered.filter { $0.sport == sport }
        }

        if !searchText.isEmpty {
            filtered = filtered.filter { session in
                session.sport.displayName.localizedCaseInsensitiveContains(searchText) ||
                session.notes.localizedCaseInsensitiveContains(searchText) ||
                session.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        return sortedSessions(filtered)
    }
}

// MARK: - Supporting Types

enum SortOption: String, CaseIterable {
    case dateDescending = "Newest First"
    case dateAscending = "Oldest First"
    case scoreHighToLow = "Highest Score"
    case scoreLowToHigh = "Lowest Score"

    var icon: String {
        switch self {
        case .dateDescending: return "arrow.down.circle"
        case .dateAscending: return "arrow.up.circle"
        case .scoreHighToLow: return "star.fill"
        case .scoreLowToHigh: return "star"
        }
    }
}
