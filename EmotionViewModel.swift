import SwiftUI
import Combine

// MARK: - GuidedPhase

enum GuidedPhase: Equatable {
    case hidden          // No emotion selected
    case caption         // Show educational caption bubble (5s)
    case restoreButton   // Caption gone, "Restore Balance" button floats in
    case stabilizing     // User tapped Restore Balance; camera active; guidance shown
    case restored        // Balance achieved; show calm message
    case cameraFading    // 2s camera fade-out before returning to hidden
}

// MARK: - EmotionViewModel

@MainActor
final class EmotionViewModel: ObservableObject {

    @Published var selectedEmotion: Emotion? = nil
    @Published var displayParameters: EmotionParameters = EmotionParameters.make(for: .calm)
    @Published var guidedPhase: GuidedPhase = .hidden
    @Published var cameraPreviewOpacity: Double = 0.0
    @Published var sessions: [EmotionSession] = []   // journey history

    // Legacy — kept for the status pills in the HUD
    @Published var isRegulating: Bool = false
    @Published var regulationProgress: Double = 0

    let breathingManager = BreathingManager()
    let cameraManager   = CameraGestureManager()

    private var srcParams: EmotionParameters = EmotionParameters.make(for: .calm)
    private var dstParams: EmotionParameters = EmotionParameters.make(for: .calm)
    private var lerpT: Float = 1.0
    private var lerpTimer: Timer?

    private var captionTimer: Timer?
    private var stabilizeAccum: Double = 0
    private var stabilizeTimer: Timer?
    private var stabilizationStartTime: Date?

    init() { startStabilizeMonitor() }

    // MARK: - Public API

    func selectEmotion(_ emotion: Emotion) {
        selectedEmotion  = emotion
        guidedPhase      = .caption
        isRegulating     = false
        regulationProgress = 0
        stabilizeAccum   = 0

        // Neuron transitions to detected emotion
        transition(to: EmotionParameters.make(for: emotion), duration: 1.2)

        // Breathing detection starts immediately (silent background)
        breathingManager.start()

        // Camera stays OFF until user taps Restore Balance

        // After 5s, caption fades — restore button floats in
        captionTimer?.invalidate()
        captionTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard self?.guidedPhase == .caption else { return }
                withAnimation(.easeInOut(duration: 0.5)) {
                    self?.guidedPhase = .restoreButton
                }
            }
        }
    }

    func clearEmotion() {
        selectedEmotion = nil
        guidedPhase     = .hidden
        cameraPreviewOpacity = 0
        captionTimer?.invalidate()
        breathingManager.stop()
        cameraManager.stopSession()
        stabilizeAccum = 0
        isRegulating = false
        regulationProgress = 0
    }

    /// Called when user taps "Restore Balance"
    func restoreBalance() {
        guard guidedPhase == .restoreButton else { return }

        // Start camera session (async background task)
        cameraManager.startSession()
        stabilizeAccum = 0
        stabilizationStartTime = Date()    // begin timing

        withAnimation(.easeInOut(duration: 0.4)) {
            guidedPhase          = .stabilizing
            cameraPreviewOpacity = 1.0
        }
    }

    // MARK: - Parameter Transition

    func transition(to target: EmotionParameters, duration: Double = 1.5) {
        srcParams = displayParameters
        dstParams = target
        lerpT = 0
        lerpTimer?.invalidate()
        let step = Float(0.016 / duration)
        lerpTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.lerpT = min(1.0, self.lerpT + step)
                self.displayParameters = EmotionParameters.lerp(self.srcParams, self.dstParams, t: self.lerpT)
                if self.lerpT >= 1.0 { self.lerpTimer?.invalidate() }
            }
        }
    }

    // MARK: - Stabilization Monitor (all emotions when in .stabilizing)

    private func startStabilizeMonitor() {
        stabilizeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.checkStabilization() }
        }
    }

    private func checkStabilization() {
        guard guidedPhase == .stabilizing else {
            stabilizeAccum     = 0
            regulationProgress = 0
            return
        }

        let steady = cameraManager.isSteadyHand
        let calm   = breathingManager.isCalmBreathing

        if steady && calm {
            stabilizeAccum  += 0.1
            regulationProgress = min(1.0, stabilizeAccum / 3.0)
            if stabilizeAccum >= 3.0 { triggerBalanceRestored() }
        } else {
            stabilizeAccum  = max(0, stabilizeAccum - 0.15)
            regulationProgress = max(0, stabilizeAccum / 3.0)
        }
    }

    private func triggerBalanceRestored() {
        // Record session data
        let elapsed = stabilizationStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let quality = breathingManager.isCalmBreathing ? "Calm" : "Elevated"
        if let emotion = selectedEmotion {
            // Only record if not already explored this emotion in this session
            if !sessions.contains(where: { $0.emotion == emotion }) {
                sessions.append(EmotionSession(
                    emotion: emotion,
                    date: Date(),
                    stabilizationTime: elapsed,
                    breathingQuality: quality
                ))
            }
        }
        isRegulating = true
        guidedPhase  = .restored
        transition(to: EmotionParameters.make(for: .calm), duration: 3.0)

        Task { @MainActor in
            // Wait for user to read the restored message
            try? await Task.sleep(for: .seconds(3.0))
            guard self.guidedPhase == .restored else { return }

            // Fade camera out over 2s
            withAnimation(.easeInOut(duration: 2.0)) {
                self.cameraPreviewOpacity = 0
                self.guidedPhase = .cameraFading
            }

            try? await Task.sleep(for: .seconds(2.2))
            guard self.guidedPhase == .cameraFading else { return }

            self.cameraManager.stopSession()
            self.selectedEmotion   = .calm
            self.isRegulating      = false
            self.stabilizeAccum    = 0
            self.regulationProgress = 0
            // Restart the guided flow at caption for calm
            withAnimation(.easeInOut(duration: 0.4)) { self.guidedPhase = .hidden }
        }
    }
}
