import SwiftUI
import AVFoundation

/// Fifth step - camera permission request
struct PermissionsStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Spacer()

            // Camera icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: cameraIconName)
                    .font(.system(size: 50))
                    .foregroundStyle(.white)
            }

            // Title and description
            VStack(spacing: DesignTokens.Spacing.md) {
                Text(titleText)
                    .font(DesignTokens.Typography.title)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(descriptionText)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.Spacing.md)
            }

            Spacer()

            // Permission button
            if viewModel.cameraPermissionStatus != .authorized {
                Button {
                    Task {
                        await viewModel.requestCameraPermission()
                    }
                } label: {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        if viewModel.isRequestingPermission {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "camera.fill")
                        }
                        Text(buttonText)
                    }
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                            .fill(Color.white.opacity(0.2))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                            .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
                    )
                }
                .disabled(viewModel.isRequestingPermission)
                .padding(.horizontal, DesignTokens.Spacing.xl)
            }

            Spacer()
        }
        .onAppear {
            viewModel.checkCameraPermission()
        }
    }

    private var cameraIconName: String {
        switch viewModel.cameraPermissionStatus {
        case .authorized:
            return "checkmark.circle.fill"
        case .denied, .restricted:
            return "camera.fill"
        default:
            return "camera.fill"
        }
    }

    private var titleText: String {
        switch viewModel.cameraPermissionStatus {
        case .authorized:
            return "Camera Ready!"
        case .denied, .restricted:
            return "Camera Access Needed"
        default:
            return "Enable Camera"
        }
    }

    private var descriptionText: String {
        switch viewModel.cameraPermissionStatus {
        case .authorized:
            return "You're all set! Tap 'Get Started' to begin analyzing your swings."
        case .denied, .restricted:
            return "Camera access was denied. Please enable it in Settings to use Swingenuity."
        default:
            return "Swingenuity needs camera access to record and analyze your swing using advanced body tracking."
        }
    }

    private var buttonText: String {
        switch viewModel.cameraPermissionStatus {
        case .denied, .restricted:
            return "Open Settings"
        default:
            return "Allow Camera Access"
        }
    }
}

#Preview {
    ZStack {
        OnboardingBackground()
        PermissionsStepView(viewModel: OnboardingViewModel())
    }
}
