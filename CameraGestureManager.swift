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

    nonisolated(unsafe) let captureSession = AVCaptureSession()
    private nonisolated(unsafe) var captureDelegate: CaptureDelegate?
    // Track whether we have already configured the session inputs/outputs once.
    // The session is reused across stop/start cycles — only the delegate changes.
    private nonisolated(unsafe) var sessionConfigured = false
    private let processingQueue = DispatchQueue(label: "com.feelinit.camera", qos: .userInteractive)

    // MARK: Control

    func startSession() {
        Task.detached { [weak self] in
            await self?.setupAndRun()
        }
    }

    nonisolated func stopSession() {
        captureSession.stopRunning()
        // Reset published state on main actor
        Task { @MainActor [weak self] in
            self?.gestureState = .none
            self?.isSteadyHand = false
        }
    }

    // MARK: Setup (nonisolated — stays off main thread)

    nonisolated private func setupAndRun() async {
        guard await requestCameraPermission() else { return }

        // ── Fresh delegate every time so callbacks arrive on the live output ──
        let delegate = CaptureDelegate { [weak self] gesture, steady in
            Task { @MainActor [weak self] in
                self?.gestureState = gesture
                self?.isSteadyHand = steady
            }
        }
        captureDelegate = delegate   // strong reference keeps it alive

        if !sessionConfigured {
            // First-time setup: add input + output to the session
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let input  = try? AVCaptureDeviceInput(device: device) else { return }

            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            ]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(delegate, queue: processingQueue)

            captureSession.beginConfiguration()
            captureSession.sessionPreset = .medium
            if captureSession.canAddInput(input)   { captureSession.addInput(input) }
            if captureSession.canAddOutput(output)  { captureSession.addOutput(output) }
            captureSession.commitConfiguration()

            sessionConfigured = true
        } else {
            // Session already has hardware inputs/outputs wired up.
            // We only need to swap the sample-buffer delegate on the existing output
            // so frames reach the fresh CaptureDelegate.
            if let existingOutput = captureSession.outputs.first(where: { $0 is AVCaptureVideoDataOutput })
                as? AVCaptureVideoDataOutput {
                existingOutput.setSampleBufferDelegate(delegate, queue: processingQueue)
            }
        }

        // startRunning is idempotent when already running, safe to call again.
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }

    nonisolated private func requestCameraPermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVCaptureDevice.requestAccess(for: .video) { cont.resume(returning: $0) }
        }
    }
}
