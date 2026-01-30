import SwiftUI

struct SportSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSport: Sport

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Select Your Sport")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)

                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(Sport.allCases, id: \.self) { sport in
                        SportOptionCard(
                            sport: sport,
                            isSelected: selectedSport == sport,
                            action: {
                                selectedSport = sport
                                dismiss()
                            }
                        )
                    }
                }
                .padding()

                Spacer()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Sport Option Card

struct SportOptionCard: View {
    let sport: Sport
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: sport.symbolName)
                    .font(.system(size: 50))
                    .foregroundStyle(isSelected ? .white : .primary)

                Text(sport.displayName)
                    .font(.headline)
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .background(
                isSelected ?
                    AnyShapeStyle(Color.accentColor) :
                    AnyShapeStyle(Color(.systemBackground))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.accentColor, lineWidth: 3)
                }
            }
            .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SportSelectorView(selectedSport: .constant(.golf))
}
