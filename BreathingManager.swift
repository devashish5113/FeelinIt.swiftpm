import AVFoundation

@MainActor
final class BreathingManager: ObservableObject {

    @Published var breathingIntensity: Float = 0   // 0–1 smoothed amplitude
    @Published var isCalmBreathing: Bool = false

    private var audioEngine: AVAudioEngine?
    private var ampHistory:  [Float] = []
    private var calmBuffer:  [Float] = []
    private let smoothWindow = 20
    private let calmWindow   = 60   // ~3 s

    func start() {
        // Task.detached + nonisolated configureAndStart = stays off main thread
        Task.detached { [weak self] in
            await self?.configureAndStart()
        }
    }

    func stop() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
    }

    // MARK: - nonisolated so Task.detached doesn't hop back to @MainActor

    nonisolated private func configureAndStart() async {
        guard await requestMicPermission() else { return }

        do {
            // ── 1. Activate audio session FIRST so hardware initialises ──
            // Querying inputNode.outputFormat before session activation returns
            // 0 Hz, which makes AVAudioEngine crash on installTap.
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .mixWithOthers)
            try session.setActive(true)

            // ── 2. NOW the format is valid (real sample-rate from hardware) ──
            let engine = AVAudioEngine()
            let bus: AVAudioNodeBus = 0
            let fmt = engine.inputNode.outputFormat(forBus: bus)

            guard fmt.sampleRate > 0 else {
                print("BreathingManager: invalid input format (sampleRate == 0)")
                return
            }

            // ── 3. Install tap and start engine ──────────────────────────
            engine.inputNode.installTap(onBus: bus, bufferSize: 1024, format: fmt) { [weak self] buf, _ in
                let rms = BreathingManager.rms(buf)
                Task { @MainActor [weak self] in self?.process(rms) }
            }
            try engine.start()

            await MainActor.run { [weak self] in self?.audioEngine = engine }
        } catch {
            print("BreathingManager: \(error)")
        }
    }

    // MARK: - Main-actor processing

    private func process(_ rms: Float) {
        let norm = min(1.0, rms / 0.05)
        ampHistory.append(norm)
        if ampHistory.count > smoothWindow { ampHistory.removeFirst() }
        breathingIntensity = ampHistory.reduce(0, +) / Float(ampHistory.count)

        calmBuffer.append(breathingIntensity)
        if calmBuffer.count > calmWindow { calmBuffer.removeFirst() }
        guard calmBuffer.count == calmWindow else { return }
        let avg = calmBuffer.reduce(0, +) / Float(calmWindow)
        let variance = calmBuffer.map { ($0-avg)*($0-avg) }.reduce(0,+) / Float(calmWindow)
        isCalmBreathing = avg < 0.3 && variance < 0.02
    }

    nonisolated private static func rms(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        let n = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<n { sum += data[i] * data[i] }
        return sqrt(sum / Float(n))
    }

    nonisolated private func requestMicPermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
        }
    }
}
