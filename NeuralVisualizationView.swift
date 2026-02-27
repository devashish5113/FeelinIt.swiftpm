import SwiftUI
import Combine

struct NeuralVisualizationView: View {
    @ObservedObject var viewModel: EmotionViewModel
    @StateObject private var sceneManager = NeuralSceneManager()
    @State private var appeared = false

    var emotion: Emotion { viewModel.selectedEmotion ?? .calm }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 3D Neural Sphere
            NeuralSceneView(manager: sceneManager)
                .ignoresSafeArea()

            // HUD overlay
            VStack(spacing: 0) {
                // ── Top bar ──────────────────────────────────────────────────
                HStack(alignment: .top) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            viewModel.clearEmotion()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.12), in: Capsule())
                    }

                    Spacer()

                    // Emotion badge
                    HStack(spacing: 6) {
                        Text(emotion.emoji)
                        Text(emotion.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(emotion.color.opacity(0.3), in: Capsule())
                    .overlay(Capsule().strokeBorder(emotion.color.opacity(0.6), lineWidth: 1))
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)

                Spacer()

                // ── Camera preview: right-aligned, above the message bubble ──
                // Must come FIRST in VStack so it renders above the messages below it.
                if viewModel.guidedPhase == .stabilizing
                    || viewModel.guidedPhase == .restored
                    || viewModel.guidedPhase == .cameraFading
                {
                    HStack {
                        Spacer()
                        LiveCameraPreview(session: viewModel.cameraManager.captureSession)
                            .frame(width: 100, height: 134)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(.white.opacity(0.30), lineWidth: 1.5)
                            )
                            .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 3)
                            .opacity(viewModel.cameraPreviewOpacity)
                            .padding(.trailing, 20)
                    }
                    .transition(.opacity)
                    .padding(.bottom, 8)
                }

                // ── Guided phase overlays (always at the very bottom) ─────────

                // Caption bubble (phase: .caption)
                if viewModel.guidedPhase == .caption {
                    NeuralCaptionBubble(text: emotion.neuralCaption, color: emotion.color)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity.combined(with: .move(edge: .bottom))
                        ))
                }

                // Restore Balance button (phase: .restoreButton)
                if viewModel.guidedPhase == .restoreButton {
                    RestoreBalanceButton(color: emotion.color) {
                        viewModel.restoreBalance()
                    }
                    .padding(.bottom, 16)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 60)),
                        removal: .opacity.combined(with: .offset(y: 20))
                    ))
                }

                // Stabilizing guidance (phase: .stabilizing)
                if viewModel.guidedPhase == .stabilizing {
                    StabilizingGuidanceView(progress: viewModel.regulationProgress)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // Restored calm message (phase: .restored or .cameraFading)
                if viewModel.guidedPhase == .restored || viewModel.guidedPhase == .cameraFading {
                    RestoredMessageBubble()
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        ))
                }
            }
            .opacity(appeared ? 1 : 0)
            .animation(.easeInOut(duration: 0.35), value: viewModel.guidedPhase)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
            sceneManager.update(parameters: viewModel.displayParameters)
        }
        .onReceive(viewModel.$displayParameters) { params in
            sceneManager.update(parameters: params)
        }
    }
}

// MARK: - Neural Caption Bubble

struct NeuralCaptionBubble: View {
    let text: String
    let color: Color
    @State private var glow = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "brain")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .scaleEffect(glow ? 1.12 : 1.0)

            Text(text)
                .font(.system(size: 13.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(color.opacity(0.08))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [color.opacity(0.7), color.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: color.opacity(0.25), radius: 16, x: 0, y: 4)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}

// MARK: - Restore Balance Button

struct RestoreBalanceButton: View {
    let color: Color
    let action: () -> Void
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 8) {
            Text("Ready to return to balance?")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))

            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Restore Balance")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    ZStack {
                        Capsule().fill(color.opacity(0.25))
                        Capsule().fill(.ultraThinMaterial.opacity(0.5))
                    }
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [color.opacity(0.9), color.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: color.opacity(pulse ? 0.55 : 0.25), radius: pulse ? 22 : 10)
                .scaleEffect(pulse ? 1.02 : 1.0)
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 24)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Stabilizing Guidance View

struct StabilizingGuidanceView: View {
    let progress: Double
    @State private var dotPhase = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "hand.raised")
                    .font(.system(size: 13))
                    .foregroundStyle(.cyan)
                Text("Hold your hand steady")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))

                Text("·")
                    .foregroundStyle(.white.opacity(0.3))

                Image(systemName: "lungs")
                    .font(.system(size: 13))
                    .foregroundStyle(.green)
                Text("breathe slowly")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.10))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.cyan, .green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .padding(.bottom, 8)
    }
}

// MARK: - Restored Message Bubble

struct RestoredMessageBubble: View {
    @State private var shimmer = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(
                    LinearGradient(colors: [.cyan, .green],
                                   startPoint: .top, endPoint: .bottom)
                )
                .scaleEffect(shimmer ? 1.1 : 1.0)

            Text("Physical stillness and slow breathing help calm neural activation.")
                .font(.system(size: 13.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.cyan.opacity(0.07))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.6), Color.green.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.cyan.opacity(0.2), radius: 14, x: 0, y: 4)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }
}

// MARK: - Status Pill

struct StatusPill: View {
    let icon: String
    let label: String
    let active: Bool
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(active ? color : .white.opacity(0.4))
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(active ? .white : .white.opacity(0.4))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.white.opacity(active ? 0.15 : 0.07), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(active ? 0.6 : 0.2), lineWidth: 1))
        .animation(.easeInOut(duration: 0.3), value: active)
    }
}

// MARK: - Breathing Ring

struct BreathingRing: View {
    let intensity: Float
    let isCalmBreathing: Bool
    let emotionColor: Color
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(.white.opacity(0.1), lineWidth: 2)
                .frame(width: 52, height: 52)
            Circle()
                .trim(from: 0, to: CGFloat(intensity))
                .stroke(
                    isCalmBreathing ? Color.green : emotionColor,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 52, height: 52)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: intensity)
            Image(systemName: "wind")
                .font(.system(size: 14))
                .foregroundStyle(isCalmBreathing ? .green : .white.opacity(0.6))
                .scaleEffect(pulse ? 1.1 : 0.9)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
