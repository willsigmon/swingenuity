import SwiftUI

struct SettingsView: View {
    @AppStorage("showMetricsByDefault") private var showMetricsByDefault = false
    @AppStorage("recordingQuality") private var recordingQuality = RecordingQuality.high.rawValue
    @AppStorage("enableHaptics") private var enableHaptics = true
    @AppStorage("autoSaveRecordings") private var autoSaveRecordings = true

    var body: some View {
        NavigationStack {
            Form {
                // Recording Settings
                Section("Recording") {
                    Toggle("Show Metrics by Default", isOn: $showMetricsByDefault)

                    Picker("Recording Quality", selection: $recordingQuality) {
                        ForEach(RecordingQuality.allCases, id: \.self) { quality in
                            Text(quality.displayName).tag(quality.rawValue)
                        }
                    }

                    Toggle("Auto-Save Recordings", isOn: $autoSaveRecordings)
                }

                // App Settings
                Section("App") {
                    Toggle("Haptic Feedback", isOn: $enableHaptics)
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://swingenuity.app/privacy")!) {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.forward")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Link(destination: URL(string: "https://swingenuity.app/terms")!) {
                        HStack {
                            Text("Terms of Service")
                            Spacer()
                            Image(systemName: "arrow.up.forward")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Support
                Section("Support") {
                    Link(destination: URL(string: "mailto:support@swingenuity.app")!) {
                        HStack {
                            Text("Contact Support")
                            Spacer()
                            Image(systemName: "envelope")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button(action: shareApp) {
                        HStack {
                            Text("Share Swingenuity")
                            Spacer()
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func shareApp() {
        // TODO: Implement share sheet
    }
}

// MARK: - Supporting Types

enum RecordingQuality: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

#Preview {
    SettingsView()
}
