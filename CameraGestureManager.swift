import AVFoundation
import Vision
import SwiftUI

// MARK: - Gesture State

enum GestureState: String {
    case none       = "No Hand"
    case openPalm   = "Open Palm ✋"
    case closedFist = "Closed Fist ✊"
    case swipeLeft  = "Swipe Left ←"
    case swipeRight = "Swipe Right →"
}

// MARK: - CaptureDelegate
// Inherits from NSObject, lives on processingQueue, handles all Vision processing.
// @unchecked Sendable: all mutable state (centroidHistory) is only touched on processingQueue.

private final class CaptureDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {

    let onResult: @Sendable (GestureState, Bool) -> Void
    private var centroidHistory: [CGPoint] = []
    private let historySize = 10

    init(onResult: @escaping @Sendable (GestureState, Bool) -> Void) {
        self.onResult = onResult
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer,
                                            orientation: .leftMirrored, options: [:])
        try? handler.perform([request])
        guard let obs = request.results?.first else { onResult(.none, false); return }
        let (gesture, steady) = classify(obs)
        onResult(gesture, steady)
    }

    private func classify(_ obs: VNHumanHandPoseObservation) -> (GestureState, Bool) {
        guard let pts = try? obs.recognizedPoints(.all) else { return (.none, false) }
        func pt(_ j: VNHumanHandPoseObservation.JointName) -> CGPoint? {
            guard let p = pts[j], p.confidence > 0.3 else { return nil }
            return p.location
        }
        if let w = pt(.wrist) {
            centroidHistory.append(w)
            if centroidHistory.count > historySize { centroidHistory.removeFirst() }
        }
        let steady = centroidVariance() < 0.0004
        let tips: [VNHumanHandPoseObservation.JointName] = [.indexTip, .middleTip, .ringTip, .littleTip]
        let mcps: [VNHumanHandPoseObservation.JointName] = [.indexMCP, .middleMCP, .ringMCP, .littleMCP]
        var openCount = 0
        for (tip, mcp) in zip(tips, mcps) {
            if let t = pt(tip), let m = pt(mcp), t.y > m.y { openCount += 1 }
        }
        let gesture: GestureState = openCount >= 3 ? .openPalm : (openCount == 0 ? .closedFist : .none)
        return (gesture, steady)
    }

    private func centroidVariance() -> Double {
        guard centroidHistory.count > 1 else { return 1.0 }
        let n  = Double(centroidHistory.count)
        let mx = centroidHistory.map(\.x).reduce(0, +) / n
        let my = centroidHistory.map(\.y).reduce(0, +) / n
        return centroidHistory.map { ($0.x-mx)*($0.x-mx) + ($0.y-my)*($0.y-my) }.reduce(0,+) / n
    }
}

// MARK: - CameraGestureManager

@MainActor
final class CameraGestureManager: ObservableObject {

    @Published var gestureState: GestureState = .none
    @Published var isSteadyHand: Bool = false

    // nonisolated(unsafe): accessed from background threads (setupAndRun, stopSession, CameraPreviewView)
    nonisolated(unsafe) let captureSession = AVCaptureSession()
    private nonisolated(unsafe) var captureDelegate: CaptureDelegate?
    private let processingQueue = DispatchQueue(label: "com.feelinit.camera", qos: .userInteractive)

    // MARK: Control

    func startSession() {
        // Task.detached + nonisolated setupAndRun = truly stays off main thread
        Task.detached { [weak self] in
            await self?.setupAndRun()
        }
    }

    nonisolated func stopSession() {
        captureSession.stopRunning()
    }

    // MARK: Setup (nonisolated → runs on cooperative pool, NOT main thread)

    nonisolated private func setupAndRun() async {
        guard await requestCameraPermission() else { return }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input  = try? AVCaptureDeviceInput(device: device) else { return }

        let delegate = CaptureDelegate { [weak self] gesture, steady in
            Task { @MainActor [weak self] in
                self?.gestureState = gesture
                self?.isSteadyHand = steady
            }
        }
        captureDelegate = delegate   // nonisolated(unsafe) — safe: written once before startRunning

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(delegate, queue: processingQueue)

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .medium
        if captureSession.canAddInput(input)  { captureSession.addInput(input) }
        if captureSession.canAddOutput(output) { captureSession.addOutput(output) }
        captureSession.commitConfiguration()

        captureSession.startRunning()   // ← blocking, but off main thread ✓
    }

    nonisolated private func requestCameraPermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVCaptureDevice.requestAccess(for: .video) { cont.resume(returning: $0) }
        }
    }
}
