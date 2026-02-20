import SwiftUI
import Combine

@MainActor
final class EmotionViewModel: ObservableObject {

    @Published var selectedEmotion: Emotion? = nil
    @Published var displayParameters: EmotionParameters = EmotionParameters.make(for: .calm)
    @Published var isRegulating: Bool = false
    @Published var regulationProgress: Double = 0   // 0–1 over 3 seconds

    let breathingManager = BreathingManager()
    let cameraManager   = CameraGestureManager()

    private var srcParams: EmotionParameters = EmotionParameters.make(for: .calm)
    private var dstParams: EmotionParameters = EmotionParameters.make(for: .calm)
    private var lerpT: Float = 1.0
    private var lerpTimer: Timer?
    private var regulationAccum: Double = 0
    private var regulationTimer: Timer?

    init() { startRegulationMonitor() }

    // Timers use [weak self] so no retain cycle; no deinit needed in Swift 6
    // (nonisolated deinit cannot touch @MainActor-isolated Timer properties)

    // MARK: Public

    func selectEmotion(_ emotion: Emotion) {
        selectedEmotion = emotion
        regulationAccum = 0; isRegulating = false; regulationProgress = 0
        transition(to: EmotionParameters.make(for: emotion), duration: 1.2)
        breathingManager.start()
        cameraManager.startSession()
    }

    func clearEmotion() {
        selectedEmotion = nil
        breathingManager.stop()
        cameraManager.stopSession()
        regulationAccum = 0; isRegulating = false; regulationProgress = 0
    }

    // MARK: Parameter Transition

    func transition(to target: EmotionParameters, duration: Double = 1.5) {
        srcParams = displayParameters
        dstParams = target
        lerpT = 0
        lerpTimer?.invalidate()
        let step = Float(0.016 / duration)
        lerpTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            // Do not capture 'timer' — not Sendable across actor boundaries
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.lerpT = min(1.0, self.lerpT + step)
                self.displayParameters = EmotionParameters.lerp(self.srcParams, self.dstParams, t: self.lerpT)
                if self.lerpT >= 1.0 { self.lerpTimer?.invalidate() }
            }
        }
    }

    // MARK: Anxiety Regulation Monitor

    private func startRegulationMonitor() {
        regulationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.checkRegulation() }
        }
    }

    private func checkRegulation() {
        guard selectedEmotion == .anxiety, !isRegulating else {
            if selectedEmotion != .anxiety { regulationAccum = 0; regulationProgress = 0 }
            return
        }
        if cameraManager.isSteadyHand && breathingManager.isCalmBreathing {
            regulationAccum += 0.1
            regulationProgress = min(1.0, regulationAccum / 3.0)
            if regulationAccum >= 3.0 { triggerRegulation() }
        } else {
            regulationAccum = max(0, regulationAccum - 0.15)
            regulationProgress = max(0, regulationAccum / 3.0)
        }
    }

    private func triggerRegulation() {
        isRegulating = true
        transition(to: EmotionParameters.make(for: .calm), duration: 3.0)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.5))
            self.selectedEmotion = .calm
            self.isRegulating = false
            self.regulationAccum = 0
            self.regulationProgress = 0
        }
    }
}
