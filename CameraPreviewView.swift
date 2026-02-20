import SwiftUI
import AVFoundation

// UIViewRepresentable holding a hidden AVCaptureVideoPreviewLayer so the
// session stays alive. The preview is 1×1 pt and alpha 0.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        view.alpha = 0
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
//DEVA
