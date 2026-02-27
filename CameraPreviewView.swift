import SwiftUI
import AVFoundation

// MARK: - LiveCameraPreview

struct LiveCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraHostView {
        let view = CameraHostView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.previewLayer = layer        // stored so layoutSubviews can update frame
        view.layer.addSublayer(layer)
        return view
    }

    func updateUIView(_ uiView: CameraHostView, context: Context) {
        // layout is handled purely inside layoutSubviews — nothing needed here
    }
}

// UIView subclass that keeps the preview layer pinned to its own bounds
// via layoutSubviews, which fires every time the SwiftUI-assigned frame changes.
final class CameraHostView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds        // always pixel-perfect, called after every layout pass
    }
}
