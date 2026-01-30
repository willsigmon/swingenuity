//
//  CameraView.swift
//  Swingenuity
//
//  Example SwiftUI view showing camera integration
//

import SwiftUI

/// Main camera view for recording golf swings
struct CameraView: View {
    @State private var coordinator = CameraCoordinator()
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(session: coordinator.getCaptureSession())
                .ignoresSafeArea()

            // Overlay UI
            VStack {
                Spacer()

                // Recording indicator
                if coordinator.isRecording {
                    HStack {
                        Circle()
                            .fill(.red)
                            .frame(width: 12, height: 12)
                        Text(formatDuration(coordinator.recordingDuration))
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    .padding(12)
                    .background(.black.opacity(0.6))
                    .clipShape(Capsule())
                    .padding(.bottom, 20)
                }

                // Controls
                HStack(spacing: 40) {
                    // Cancel button (only when recording)
                    if coordinator.isRecording {
                        Button {
                            Task {
                                await coordinator.cancelRecording()
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 60, height: 60)
                                .background(.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                    }

                    // Record/Stop button
                    Button {
                        Task {
                            if coordinator.isRecording {
                                await coordinator.stopRecording(saveToPhotos: true)
                            } else {
                                do {
                                    try await coordinator.startRecording()
                                } catch {
                                    errorMessage = error.localizedDescription
                                    showError = true
                                }
                            }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .strokeBorder(.white, lineWidth: 4)
                                .frame(width: 80, height: 80)

                            if coordinator.isRecording {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.red)
                                    .frame(width: 40, height: 40)
                            } else {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 70, height: 70)
                            }
                        }
                    }

                    // Placeholder for future controls
                    if coordinator.isRecording {
                        Color.clear
                            .frame(width: 60, height: 60)
                    }
                }
                .padding(.bottom, 40)
            }

            // Status overlay
            if !coordinator.cameraManager.hasDepthSupport {
                VStack {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.yellow)
                        Text("LiDAR not available on this device")
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                    .padding(12)
                    .background(.black.opacity(0.6))
                    .clipShape(Capsule())
                    .padding(.top, 60)

                    Spacer()
                }
            }
        }
        .task {
            await setupCamera()
        }
        .onDisappear {
            Task {
                await coordinator.shutdown()
            }
        }
        .alert("Camera Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Private Methods

    private func setupCamera() async {
        do {
            // Request authorization if needed
            if coordinator.cameraManager.authorizationStatus == .notDetermined {
                let granted = await coordinator.cameraManager.requestAuthorization()
                guard granted else {
                    errorMessage = "Camera access is required to record swings"
                    showError = true
                    return
                }
            }

            // Setup coordinator
            try await coordinator.setup()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let milliseconds = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, milliseconds)
    }
}

// MARK: - Preview

#Preview {
    CameraView()
}
