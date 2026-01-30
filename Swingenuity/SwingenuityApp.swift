import SwiftUI
import SwiftData

@main
struct SwingenuityApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            SwingSession.self
        ])
    }
}
