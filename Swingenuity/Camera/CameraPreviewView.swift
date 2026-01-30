//
//  CameraPreviewView.swift
//  Swingenuity
//
//  SwiftUI wrapper for AVCaptureVideoPreviewLayer
//

import SwiftUI
import AVFoundation

/// SwiftUI view that displays the camera preview
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.session = session
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.session = session
    }

    // MARK: - PreviewView

    /// UIView wrapper for AVCaptureVideoPreviewLayer
    class PreviewView: UIView {
        var session: AVCaptureSession? {
            didSet {
                previewLayer.session = session
            }
        }

        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        private var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            setupLayer()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setupLayer()
        }

        private func setupLayer() {
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.connection?.videoOrientation = .portrait
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.frame = bounds
        }
    }
}

// MARK: - Preview Provider

#Preview {
    CameraPreviewView(session: AVCaptureSession())
        .ignoresSafeArea()
}
