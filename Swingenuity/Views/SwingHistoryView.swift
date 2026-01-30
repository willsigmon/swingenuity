import SwiftUI
import SwiftData

struct SwingHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [SwingSession]
    @State private var viewModel = SwingHistoryViewModel()
    @State private var showingFilterSheet = false

    var filteredAndSortedSessions: [SwingSession] {
        viewModel.filteredSessions(sessions)
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    emptyStateView
                } else {
                    sessionListView
                }
            }
            .navigationTitle("History")
            .searchable(text: $viewModel.searchText, prompt: "Search swings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        // Sport Filter
                        Menu {
                            Button("All Sports") {
                                viewModel.selectSport(nil)
                            }

                            Divider()

                            ForEach(Sport.allCases, id: \.self) { sport in
                                Button(action: {
                                    viewModel.selectSport(sport)
                                }) {
                                    Label(sport.displayName, systemImage: sport.symbolName)
                                }
                            }
                        } label: {
                            Label("Filter by Sport", systemImage: "line.3.horizontal.decrease.circle")
                        }

                        Divider()

                        // Sort Options
                        Menu {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Button(action: {
                                    viewModel.changeSortOption(option)
                                }) {
                                    Label(option.rawValue, systemImage: option.icon)
                                }
                            }
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $viewModel.selectedSession) { session in
                AnalysisResultView(session: session)
            }
            .alert("Delete Swing?", isPresented: $viewModel.showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    viewModel.cancelDelete()
                }
                Button("Delete", role: .destructive) {
                    viewModel.confirmDelete(from: modelContext)
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }

    // MARK: - Session List View

    private var sessionListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Active Filter Display
                if viewModel.selectedSport != nil {
                    FilterChip(
                        text: viewModel.selectedSport?.displayName ?? "",
                        onRemove: { viewModel.selectSport(nil) }
                    )
                    .padding(.horizontal)
                }

                ForEach(filteredAndSortedSessions) { session in
                    SwingSessionCard(
                        session: session,
                        onTap: { viewModel.selectSession(session) },
                        onFavorite: { viewModel.toggleFavorite(session, in: modelContext) },
                        onDelete: { viewModel.requestDelete(session) }
                    )
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.slash")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Swings Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Record your first swing to start analyzing your form")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Swing Session Card

struct SwingSessionCard: View {
    let session: SwingSession
    let onTap: () -> Void
    let onFavorite: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Thumbnail
                thumbnailView
                    .frame(width: 100, height: 75)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: session.sport.symbolName)
                            .foregroundStyle(.secondary)

                        Text(session.sport.displayName)
                            .font(.headline)

                        Spacer()

                        if let rating = session.rating {
                            Text(rating.letterGrade.rawValue)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(rating.color)
                        }
                    }

                    Text(session.formattedDate())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let rating = session.rating {
                        HStack {
                            ProgressBar(value: rating.score / 100.0, color: rating.color)
                                .frame(height: 6)

                            Text("\(Int(rating.score))")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Favorite Star
                Button(action: onFavorite) {
                    Image(systemName: session.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(session.isFavorite ? .yellow : .secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: onFavorite) {
                Label(
                    session.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: session.isFavorite ? "star.slash" : "star"
                )
            }

            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var thumbnailView: some View {
        Group {
            if let thumbnailData = session.thumbnailData,
               let uiImage = UIImage(data: thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay {
                        Image(systemName: session.sport.symbolName)
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let text: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.subheadline)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.subheadline)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.2))
        .foregroundStyle(Color.accentColor)
        .clipShape(Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: SwingSession.self, configurations: config)

    // Add sample sessions
    let context = container.mainContext

    for i in 0..<5 {
        let metrics = SwingMetrics(
            formMetrics: FormMetrics(
                hipRotationAngle: 70 + Double(i * 5),
                shoulderRotationAngle: 90 + Double(i * 3),
                spineAngleAtAddress: 35,
                spineAngleAtImpact: 37,
                weightTransferPercentage: 70,
                armExtensionScore: 80
            ),
            speedMetrics: SpeedMetrics(
                peakSpeed: 100 + Double(i * 2),
                peakAcceleration: 1200,
                averageSpeed: 95,
                timeToPeakSpeed: 0.3,
                impactSpeed: 98
            )
        )

        let session = SwingSession(
            dateRecorded: Date().addingTimeInterval(-Double(i * 86400)),
            sport: Sport.allCases[i % Sport.allCases.count],
            metrics: metrics,
            rating: Rating(score: 85 + Double(i * 2))
        )

        context.insert(session)
    }

    return SwingHistoryView()
        .modelContainer(container)
}
