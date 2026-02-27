import SwiftUI

// MARK: - Constellation Layout

struct ConstellationLayout: Identifiable {
    let id: Int
    let name: String
    let positions: [CGPoint]   // 6 normalized positions (0–1)
    let lines: [(Int, Int)]
}

// MARK: - JourneyView

struct JourneyView: View {
    @ObservedObject var viewModel: EmotionViewModel

    @State private var layoutIndex: Int   = 0
    @State private var placedEmotions: Set<Emotion> = []
    @State private var lineParticles: [LineParticle] = []

    // Expansion + sheet state
    @State private var expandingSession: EmotionSession? = nil
    @State private var expandOrigin: CGPoint   = .zero
    @State private var isExpanded:  Bool       = false
    @State private var detailSession: EmotionSession? = nil   // drives the sheet

    static let layouts: [ConstellationLayout] = [

        ConstellationLayout(id: 0, name: "The Twins",
            positions: [
                CGPoint(x: 0.28, y: 0.20), CGPoint(x: 0.70, y: 0.22),
                CGPoint(x: 0.20, y: 0.46), CGPoint(x: 0.78, y: 0.46),
                CGPoint(x: 0.25, y: 0.74), CGPoint(x: 0.73, y: 0.74),
            ],
            lines: [(0,2),(2,4),(1,3),(3,5),(0,1),(4,5)]
        ),

        ConstellationLayout(id: 1, name: "The Hunter",
            positions: [
                CGPoint(x: 0.28, y: 0.22), CGPoint(x: 0.68, y: 0.24),
                CGPoint(x: 0.38, y: 0.48), CGPoint(x: 0.60, y: 0.48),
                CGPoint(x: 0.30, y: 0.74), CGPoint(x: 0.68, y: 0.72),
            ],
            lines: [(0,1),(0,2),(1,3),(2,3),(2,4),(3,5),(4,5)]
        ),

        ConstellationLayout(id: 2, name: "The Crown",
            positions: [
                CGPoint(x: 0.18, y: 0.60), CGPoint(x: 0.30, y: 0.36),
                CGPoint(x: 0.45, y: 0.23), CGPoint(x: 0.60, y: 0.27),
                CGPoint(x: 0.73, y: 0.42), CGPoint(x: 0.80, y: 0.64),
            ],
            lines: [(0,1),(1,2),(2,3),(3,4),(4,5)]
        ),

        ConstellationLayout(id: 3, name: "The Archer",
            positions: [
                CGPoint(x: 0.24, y: 0.62), CGPoint(x: 0.30, y: 0.38),
                CGPoint(x: 0.46, y: 0.22), CGPoint(x: 0.63, y: 0.30),
                CGPoint(x: 0.72, y: 0.50), CGPoint(x: 0.52, y: 0.65),
            ],
            lines: [(0,1),(1,2),(2,3),(3,4),(4,5),(5,0),(1,5),(2,4)]
        ),
    ]

    var layout: ConstellationLayout { Self.layouts[layoutIndex] }
    private let emotionOrder: [Emotion] = Emotion.allCases

    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.02, blue: 0.08).ignoresSafeArea()
            StarField()

            GeometryReader { geo in
                ZStack {
                    ConstellationCanvas(
                        layout: layout,
                        exploredSlots: exploredSlots(),
                        particles: lineParticles,
                        geo: geo
                    )

                    // Ghost rings
                    ForEach(0..<6) { slot in
                        let emotion = emotionOrder[slot]
                        if !viewModel.sessions.contains(where: { $0.emotion == emotion }) {
                            let pos = screenPos(slot: slot, geo: geo)
                            ZStack {
                                Circle().fill(emotion.color.opacity(0.08)).frame(width: 46, height: 46)
                                Circle().strokeBorder(emotion.color.opacity(0.30), lineWidth: 1.2).frame(width: 46, height: 46)
                            }
                            .position(pos)
                        }
                    }

                    // Orbs
                    ForEach(viewModel.sessions) { session in
                        let slot   = emotionOrder.firstIndex(of: session.emotion) ?? 0
                        let target = screenPos(slot: slot, geo: geo)
                        let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                        let placed = placedEmotions.contains(session.emotion)
                        let isExpanding = expandingSession?.id == session.id

                        EmotionOrbView(emotion: session.emotion, size: 80)
                            .onTapGesture { handleTap(session: session, at: target, geo: geo) }
                            .position(target)
                            .offset(x: placed ? 0 : center.x - target.x,
                                    y: placed ? 0 : center.y - target.y)
                            .scaleEffect(placed ? 1 : 0.08)
                            // Hide the source orb once expansion begins
                            .opacity(isExpanding
                                     ? 0
                                     : (expandingSession != nil ? 0 : (placed ? 1 : 0)))
                            .animation(.spring(response: 0.80, dampingFraction: 0.58)
                                        .delay(Double(slot) * 0.12), value: placed)
                            .animation(.easeOut(duration: 0.25), value: expandingSession?.id)
                    }
                }
                .contentShape(Rectangle())
                .onAppear { lineParticles = makeLineParticles(geo: geo) }
            }

            // Header
            VStack {
                VStack(spacing: 4) {
                    Text(layout.name)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35)).kerning(3)
                    Text("Journey")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("\(viewModel.sessions.count) of 6 emotions explored")
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.40))
                }
                .padding(.top, 56)
                Spacer()
            }
            .opacity(expandingSession == nil ? 1 : 0)
            .animation(.easeOut(duration: 0.3), value: expandingSession == nil)

            // ── Hologram expansion overlay ─────────────────────────────────
            if let exp = expandingSession {
                GeometryReader { geo in
                    // size × 0.40 = sphere radius; height × 1.4 → radius = 0.56 × height
                    // so sphere fills screen top-to-bottom with curved rim peeking at edges
                    EmotionOrbView(emotion: exp.emotion,
                                   size: geo.size.height * 1.4)
                        .position(isExpanded
                            ? CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                            : expandOrigin)
                        .scaleEffect(isExpanded ? 1 : 0.05)
                        .animation(.spring(response: 0.70, dampingFraction: 0.72), value: isExpanded)
                }
                .ignoresSafeArea()
                .zIndex(5)
            }
        }
        .sheet(item: $detailSession, onDismiss: contractOrb) { session in
            if #available(iOS 16.4, *) {
                SessionDetailSheet(session: session)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.ultraThinMaterial)
            } else {
                SessionDetailSheet(session: session)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .onAppear {
            layoutIndex = Int.random(in: 0..<Self.layouts.count)
            placedEmotions = []
            animateAll()
        }
        .onChange(of: viewModel.sessions.count) { _ in animateNew() }
    }

    // MARK: Tap handling
    private func handleTap(session: EmotionSession, at pos: CGPoint, geo: GeometryProxy) {
        expandOrigin = pos
        expandingSession = session
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.spring(response: 0.70, dampingFraction: 0.72)) { isExpanded = true }
        }
        // Sheet opens slightly before sphere fully fills — snappier feel
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
            detailSession = session
        }
    }

    private func contractOrb() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.80)) { isExpanded = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { expandingSession = nil }
    }

    // MARK: Layout helpers
    private func screenPos(slot: Int, geo: GeometryProxy) -> CGPoint {
        let f = layout.positions[min(slot, layout.positions.count - 1)]
        return CGPoint(x: geo.size.width * f.x, y: geo.size.height * f.y)
    }

    private func exploredSlots() -> Set<Int> {
        Set(viewModel.sessions.compactMap { emotionOrder.firstIndex(of: $0.emotion) })
    }

    private func animateAll() {
        for (slot, emotion) in emotionOrder.enumerated() {
            guard viewModel.sessions.contains(where: { $0.emotion == emotion }) else { continue }
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(slot) * 0.12 + 0.15) {
                withAnimation { _ = placedEmotions.insert(emotion) }
            }
        }
    }

    private func animateNew() {
        for session in viewModel.sessions where !placedEmotions.contains(session.emotion) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation { _ = placedEmotions.insert(session.emotion) }
            }
        }
    }

    private func makeLineParticles(geo: GeometryProxy) -> [LineParticle] {
        var result: [LineParticle] = []
        for (a, b) in layout.lines {
            let pa = screenPos(slot: a, geo: geo)
            let pb = screenPos(slot: b, geo: geo)
            let count = Int(hypot(pb.x - pa.x, pb.y - pa.y) / 18)
            for j in 0...max(1, count) {
                let t  = CGFloat(j) / CGFloat(max(1, count))
                result.append(LineParticle(
                    base:  CGPoint(x: pa.x + (pb.x - pa.x) * t,
                                  y: pa.y + (pb.y - pa.y) * t),
                    phase: Double.random(in: 0...(2 * .pi)),
                    freq:  Double.random(in: 0.3...0.7),
                    size:  CGFloat.random(in: 1.5...3.5),
                    alpha: Double.random(in: 0.15...0.50)
                ))
            }
        }
        return result
    }
}

// MARK: - Session Detail Overlay (full-screen)

struct SessionDetailOverlay: View {
    let session: EmotionSession
    let onDismiss: () -> Void

    @State private var contentIn = false

    var body: some View {
        ZStack {
            // Dark scrim over expanded orb
            Color.black.opacity(0.58).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Dismiss ──────────────────────────────────────────────
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    .padding(.trailing, 24)
                    .padding(.top, 56)
                }

                Spacer()

                // ── Emotion identity ─────────────────────────────────────
                VStack(spacing: 12) {
                    Text(session.emotion.emoji)
                        .font(.system(size: 80))
                        .shadow(color: session.emotion.color, radius: 30)

                    Text(session.emotion.rawValue)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(session.emotion.tagline)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer().frame(height: 48)

                // ── Stats ────────────────────────────────────────────────
                HStack(spacing: 0) {
                    statCell(icon: "timer",
                             label: "Stabilised in",
                             value: session.formattedStabilizationTime)

                    Rectangle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 1, height: 54)

                    statCell(icon: "lungs.fill",
                             label: "Breathing",
                             value: session.breathingQuality)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(session.emotion.color.opacity(0.35), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 32)

                Spacer().frame(height: 24)

                // ── Date ─────────────────────────────────────────────────
                Text(session.formattedFullDate)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.42))

                Spacer()
            }
            .offset(y: contentIn ? 0 : 60)
            .opacity(contentIn ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.05)) {
                contentIn = true
            }
        }
    }

    @ViewBuilder
    private func statCell(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(session.emotion.color)
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.50))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Line Particle

struct LineParticle {
    let base:  CGPoint
    let phase: Double; let freq: Double
    let size:  CGFloat; let alpha: Double
}

// MARK: - Constellation Canvas

struct ConstellationCanvas: View {
    let layout: ConstellationLayout
    let exploredSlots: Set<Int>
    let particles: [LineParticle]
    let geo: GeometryProxy

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSince1970

                for (a, b) in layout.lines {
                    let pa = pos(a, size: size)
                    let pb = pos(b, size: size)
                    let lit = exploredSlots.contains(a) && exploredSlots.contains(b)
                    var path = Path()
                    path.move(to: pa); path.addLine(to: pb)
                    ctx.stroke(path,
                               with: .color(.white.opacity(lit ? 0.20 : 0.05)),
                               style: StrokeStyle(lineWidth: 1, dash: [5, 7]))
                }

                for p in particles {
                    let dx = sin(t * p.freq + p.phase) * 3.5
                    let dy = cos(t * p.freq * 0.8 + p.phase + 1) * 3.5
                    let pt = CGPoint(x: p.base.x + dx, y: p.base.y + dy)
                    let a  = p.alpha * (0.65 + 0.35 * sin(t * p.freq * 1.3 + p.phase))
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: pt.x - p.size/2, y: pt.y - p.size/2,
                                              width: p.size, height: p.size)),
                        with: .color(.white.opacity(a))
                    )
                }
            }
        }
    }

    private func pos(_ idx: Int, size: CGSize) -> CGPoint {
        let f = layout.positions[min(idx, layout.positions.count - 1)]
        return CGPoint(x: size.width * f.x, y: size.height * f.y)
    }
}

// MARK: - Session Detail Sheet (native iOS modal)

struct SessionDetailSheet: View {
    let session: EmotionSession

    var body: some View {
        ZStack {
            // Transparent base — lets presentationBackground material show through on iOS 16.4+
            // On older iOS: subtle emotion tint only
            Color.clear.ignoresSafeArea()
            session.emotion.color.opacity(0.12).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 36)

                // Emotion identity
                VStack(spacing: 14) {
                    Text(session.emotion.emoji)
                        .font(.system(size: 72))
                        .shadow(color: session.emotion.color.opacity(0.9), radius: 28)

                    Text(session.emotion.rawValue)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(session.emotion.tagline)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer().frame(height: 48)

                // Stats card
                HStack(spacing: 0) {
                    statCell(icon: "timer",
                             label: "Stabilised in",
                             value: session.formattedStabilizationTime)
                    Rectangle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 1, height: 54)
                    statCell(icon: "lungs.fill",
                             label: "Breathing",
                             value: session.breathingQuality)
                }
                .padding(.horizontal, 40).padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(session.emotion.color.opacity(0.35), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 32)

                Spacer().frame(height: 20)

                Text(session.formattedFullDate)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.40))

                Spacer()
            }
        }
    }

    @ViewBuilder
    private func statCell(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(session.emotion.color)
            Text(value).font(.system(size: 22, weight: .semibold, design: .rounded)).foregroundStyle(.white)
            Text(label).font(.system(size: 11)).foregroundStyle(.white.opacity(0.50))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Star Field

struct StarField: View {
    private struct Star: Identifiable {
        let id: Int; let x, y, size, opacity, dur: Double
    }
    private let stars: [Star] = (0..<80).map { i in
        let s = Double(i * 1637 &+ 941)
        func rng(_ o: Double) -> Double {
            abs((sin(s + o) * 43758.5453).truncatingRemainder(dividingBy: 1))
        }
        return Star(id: i, x: rng(0), y: rng(1),
                    size: rng(2) * 1.8 + 0.5, opacity: rng(3) * 0.45 + 0.10,
                    dur: rng(4) * 3 + 2)
    }
    @State private var on = false
    var body: some View {
        GeometryReader { geo in
            ForEach(stars) { s in
                Circle()
                    .fill(.white.opacity(on ? s.opacity : s.opacity * 0.35))
                    .frame(width: s.size, height: s.size)
                    .position(x: geo.size.width * s.x, y: geo.size.height * s.y)
                    .animation(.easeInOut(duration: s.dur).repeatForever(autoreverses: true)
                                .delay(s.dur * 0.4), value: on)
            }
        }
        .allowsHitTesting(false)
        .onAppear { on = true }
    }
}
