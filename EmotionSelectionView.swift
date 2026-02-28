import SwiftUI


struct RoundedHexagonShape: Shape {
    var cornerRadius: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY
        let r  = min(rect.width / sqrt(3.0), rect.height / 2.0)

        // Raw vertices (pointy-top, starting from top)
        let verts: [CGPoint] = (0..<6).map { i in
            let a = CGFloat(i) * .pi / 3 - .pi / 2
            return CGPoint(x: cx + r * cos(a), y: cy + r * sin(a))
        }

        var path = Path()
        let n = verts.count
        for i in 0..<n {
            let prev = verts[(i + n - 1) % n]
            let curr = verts[i]
            let next = verts[(i + 1) % n]

            // Unit vectors from curr vertex toward each neighbour
            func unit(_ from: CGPoint, _ to: CGPoint) -> CGPoint {
                let dx = to.x - from.x; let dy = to.y - from.y
                let len = sqrt(dx*dx + dy*dy)
                return len > 0 ? CGPoint(x: dx/len, y: dy/len) : .zero
            }
            let d1 = unit(curr, prev)
            let d2 = unit(curr, next)

            // Arc start/end at cornerRadius distance from vertex along each edge
            let p1 = CGPoint(x: curr.x + d1.x * cornerRadius, y: curr.y + d1.y * cornerRadius)
            let p2 = CGPoint(x: curr.x + d2.x * cornerRadius, y: curr.y + d2.y * cornerRadius)

            if i == 0 { path.move(to: p1) } else { path.addLine(to: p1) }
            // Quadratic bezier: original vertex is the control point → smooth rounded corner
            path.addQuadCurve(to: p2, control: curr)
        }
        path.closeSubpath()
        return path
    }
}



struct EmotionSelectionView: View {
    @ObservedObject var viewModel: EmotionViewModel
    @State private var appeared = false
    @State private var selectedForAnim: Emotion? = nil


    private let ringEmotions: [(emotion: Emotion, idx: Int)] = [
        (.calm,    0), (.anxiety, 1), (.sadness, 2),
        (.love,    3), (.happy,   4), (.angry,   5),
    ]

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color(red: 0.06, green: 0.04, blue: 0.14),
                         Color(red: 0.02, green: 0.02, blue: 0.06)],
                center: .center, startRadius: 0, endRadius: 500
            )
            .ignoresSafeArea()
            StarField()
            FloatingOrbs()
            GeometryReader { geo in
                contentLayout(geo: geo)
            }
        }
        .onAppear { appeared = true }
    }




    private var header: some View {
        VStack(spacing: 8) {
            Text("FeelinIt")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.38))
                .kerning(4)

            Text("How are you\nfeeling?")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(
                    LinearGradient(colors: [.white, .white.opacity(0.75)],
                                   startPoint: .top, endPoint: .bottom)
                )

            Text("Select your current emotional state")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(0.42))
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? -10 : -26)
        .animation(.easeOut(duration: 0.65), value: appeared)
    }


    private func contentLayout(geo: GeometryProxy) -> some View {
        let margin = CGFloat(24)
        let hGap   = CGFloat(10)
        let cardW  = (geo.size.width - margin * 2 - hGap * 2) / 3
        let cardH  = cardW * 2.0 / sqrt(3.0)
        let hPitch = cardW + hGap
        let vPitch = hPitch * 0.88
        let gridH  = vPitch * 2 + cardH

        return VStack(spacing: 0) {
            Spacer()

            header

            Spacer().frame(height: 38)

            // ── Hex ring grid ────────────────────────────────────────────
            // ZStack children default to center; .offset moves each card
            // from that center → no manual coordinate math needed.
            ZStack {
                ForEach(ringEmotions, id: \.emotion.id) { item in
                    let pos = hexOffset(for: item.idx, hPitch: hPitch, vPitch: vPitch)
                    EmotionCard(emotion: item.emotion,
                                isSelected: selectedForAnim == item.emotion) {
                        selectedForAnim = item.emotion
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                            viewModel.selectEmotion(item.emotion)
                        }
                    }
                    .frame(width: cardW, height: cardH)
                    .offset(x: pos.x, y: pos.y)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 26)
                    .animation(
                        .spring(response: 0.55, dampingFraction: 0.72)
                        .delay(Double(item.idx) * 0.07 + 0.25),
                        value: appeared
                    )
                }

                NeuralCenterBadge()
                    .frame(width: cardW, height: cardH)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(0.5), value: appeared)
            }
            .frame(height: gridH)
            .frame(maxWidth: .infinity)

            Spacer()

            Text("An artistic neuroscience experience")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.white.opacity(0.22))
                .padding(.bottom, 20)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.7).delay(0.9), value: appeared)
        }
        .frame(width: geo.size.width, height: geo.size.height)
    }

    //       [0] [1]
    // [5]  ctr  [2]
    //       [4] [3]
    private func hexOffset(for idx: Int, hPitch: CGFloat, vPitch: CGFloat) -> CGPoint {
        switch idx {
        case 0: return CGPoint(x: -hPitch / 2, y: -vPitch)
        case 1: return CGPoint(x:  hPitch / 2, y: -vPitch)
        case 2: return CGPoint(x:  hPitch,     y: 0)
        case 3: return CGPoint(x:  hPitch / 2, y:  vPitch)
        case 4: return CGPoint(x: -hPitch / 2, y:  vPitch)
        case 5: return CGPoint(x: -hPitch,     y: 0)
        default: return .zero
        }
    }
}



struct NeuralCenterBadge: View {
    @State private var pulse  = false
    @State private var rotate = false
    @State private var innerPulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Glow halo
            RoundedHexagonShape()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.45, green: 0.20, blue: 0.90).opacity(0.30), .clear],
                        center: .center, startRadius: 8, endRadius: 50
                    )
                )
                .scaleEffect(pulse ? 1.14 : 0.92)

            // Hex fill
            RoundedHexagonShape()
                .fill(Color.white.opacity(0.05))
            RoundedHexagonShape()
                .stroke(
                    LinearGradient(
                        colors: [Color(red: 0.60, green: 0.35, blue: 1.0).opacity(0.65),
                                 Color(red: 0.35, green: 0.15, blue: 0.70).opacity(0.25)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )

            // Orbiting dots
            ForEach(0..<6) { i in
                Circle()
                    .fill(Color(red: 0.68, green: 0.45, blue: 1.0)
                        .opacity(innerPulse ? 0.9 : 0.5))
                    .frame(width: 4.5, height: 4.5)
                    .offset(y: -16)
                    .rotationEffect(.degrees(Double(i) * 60 + (rotate ? 360 : 0)))
            }
            // Center dot
            Circle()
                .fill(Color(red: 0.75, green: 0.50, blue: 1.0))
                .frame(width: 8, height: 8)
                .scaleEffect(innerPulse ? 1.25 : 0.85)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { pulse = true }
            withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) { rotate = true }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { innerPulse = true }
        }
    }
}



struct EmotionCard: View {
    let emotion: Emotion
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            cardContent
        }
        .buttonStyle(.plain)
        .accessibilityLabel(emotion.rawValue)
        .accessibilityHint("Double tap to explore \(emotion.rawValue)")
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeIn(duration: 0.1)) { isPressed = true } }
                .onEnded   { _ in withAnimation(.spring())              { isPressed = false } }
        )
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6 + Double.random(in: 0...0.6))
                            .repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private var cardContent: some View {
        VStack(spacing: 8) {
            Text(emotion.emoji)
                .font(.system(size: 34))
                .scaleEffect(pulse ? 1.12 : 1.0)
            Text(emotion.rawValue)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cardBackground)
        .clipShape(RoundedHexagonShape())
        .scaleEffect(isPressed ? 0.94 : 1.0)
        .shadow(color: emotion.color.opacity(isPressed ? 0.70 : 0.30), radius: isPressed ? 20 : 9)
    }

    private var cardBackground: some View {
        ZStack {
            RoundedHexagonShape()
                .fill(emotion.color.opacity(isPressed ? 0.38 : 0.18))
            RoundedHexagonShape()
                .stroke(
                    LinearGradient(
                        colors: [emotion.color.opacity(0.90), emotion.color.opacity(0.30)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: isSelected ? 2.5 : 1.2
                )
        }
    }
}



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
