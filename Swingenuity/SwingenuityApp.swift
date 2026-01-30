import SwiftUI
import SwiftData

@main
struct SwingenuityApp: App {
    @State private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(coordinator)
        }
        .modelContainer(for: [
            SwingSession.self
        ])
    }
}
