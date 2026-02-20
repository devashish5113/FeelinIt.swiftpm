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

            // Hidden camera preview (keeps session alive)
            CameraPreviewView(session: viewModel.cameraManager.captureSession)
                .frame(width: 1, height: 1)

            // HUD overlay
            VStack {
                // Top bar
                HStack(alignment: .top) {
                    // Back button
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

                // Regulation progress (only for Anxiety)
                if emotion == .anxiety {
                    RegulationProgressView(
                        progress: viewModel.regulationProgress,
                        isRegulating: viewModel.isRegulating
                    )
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // Bottom indicators
                HStack(spacing: 24) {
                    StatusPill(
                        icon: "hand.raised.fill",
                        label: viewModel.cameraManager.gestureState.rawValue,
                        active: viewModel.cameraManager.isSteadyHand,
                        color: .cyan
                    )
                    BreathingRing(intensity: viewModel.breathingManager.breathingIntensity,
                                  isCalmBreathing: viewModel.breathingManager.isCalmBreathing,
                                  emotionColor: emotion.color)
                    StatusPill(
                        icon: "lungs.fill",
                        label: viewModel.breathingManager.isCalmBreathing ? "Calm Breath" : "Breathing…",
                        active: viewModel.breathingManager.isCalmBreathing,
                        color: .green
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
            sceneManager.update(parameters: viewModel.displayParameters)
        }
        // iOS 16-compatible: observe via Combine publisher on displayParameters changes
        .onReceive(viewModel.$displayParameters) { params in
            sceneManager.update(parameters: params)
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

// MARK: - Regulation Progress View

struct RegulationProgressView: View {
    let progress: Double
    let isRegulating: Bool
    @State private var shimmer = false

    var body: some View {
        VStack(spacing: 8) {
            if isRegulating {
                Text("✨ Transitioning to Calm…")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            } else {
                Text(progress > 0 ? "Keep going… \(Int(progress * 100))%" : "Steady hand + calm breath → Calm")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule()
                        .fill(
                            LinearGradient(colors: [.cyan, .green],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: geo.size.width * progress)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 5)
            .padding(.horizontal, 40)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 24)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
}
