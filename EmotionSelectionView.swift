import SwiftUI

struct EmotionSelectionView: View {
    @ObservedObject var viewModel: EmotionViewModel
    @State private var appeared = false
    @State private var selectedForAnim: Emotion? = nil

    var body: some View {
        ZStack {
            // Background
            RadialGradient(
                colors: [Color(red: 0.06, green: 0.04, blue: 0.14),
                         Color(red: 0.02, green: 0.02, blue: 0.06)],
                center: .center, startRadius: 0, endRadius: 500
            )
            .ignoresSafeArea()

            // Floating orbs
            FloatingOrbs()

            VStack(spacing: 0) {
                Spacer()

                // Header
                VStack(spacing: 12) {
                    Text("FeelinIt")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                        .kerning(4)

                    Text("How are you\nfeeling?")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(
                            LinearGradient(colors: [.white, .white.opacity(0.7)],
                                           startPoint: .top, endPoint: .bottom)
                        )

                    Text("Select your current emotional state")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : -20)
                .animation(.easeOut(duration: 0.7), value: appeared)

                Spacer().frame(height: 56)

                // Emotion Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(Array(Emotion.allCases.enumerated()), id: \.element.id) { idx, emotion in
                        EmotionCard(emotion: emotion, isSelected: selectedForAnim == emotion) {
                            selectedForAnim = emotion
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                viewModel.selectEmotion(emotion)
                            }
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 40)
                        .animation(.spring(response: 0.6, dampingFraction: 0.75)
                                    .delay(Double(idx) * 0.08 + 0.3), value: appeared)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Footer
                Text("An artistic neuroscience experience")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.25))
                    .padding(.bottom, 24)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.7).delay(0.8), value: appeared)
            }
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Emotion Card

struct EmotionCard: View {
    let emotion: Emotion
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false
    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                Text(emotion.emoji)
                    .font(.system(size: 44))
                    .scaleEffect(pulse ? 1.15 : 1.0)

                Text(emotion.rawValue)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text(emotion.tagline)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 12)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(emotion.color.opacity(isPressed ? 0.35 : 0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(
                                LinearGradient(colors: [emotion.color.opacity(0.8),
                                                        emotion.color.opacity(0.3)],
                                               startPoint: .topLeading,
                                               endPoint: .bottomTrailing),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .shadow(color: emotion.color.opacity(isPressed ? 0.6 : 0.25), radius: isPressed ? 20 : 8)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeIn(duration: 0.1)) { isPressed = true } }
                .onEnded   { _ in withAnimation(.spring())              { isPressed = false } }
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6 + Double.random(in: 0...0.6))
                            .repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Floating Orbs (background decoration)

struct FloatingOrbs: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.3, green: 0.1, blue: 0.6).opacity(0.18))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: animate ? -80 : -120, y: animate ? -200 : -160)
            Circle()
                .fill(Color(red: 0.1, green: 0.3, blue: 0.8).opacity(0.14))
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .offset(x: animate ? 100 : 80, y: animate ? 180 : 220)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}
