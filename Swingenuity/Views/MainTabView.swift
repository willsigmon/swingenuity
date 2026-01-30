import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Record Tab
            CameraRecordView()
                .tabItem {
                    Label("Record", systemImage: "video.circle.fill")
                }
                .tag(0)

            // History Tab
            SwingHistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(1)

            // Settings Tab
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .tint(.accentColor)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [SwingSession.self], inMemory: true)
}
