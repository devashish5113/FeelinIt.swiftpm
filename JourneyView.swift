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
            RadialGradient(
                colors: [Color(red: 0.06, green: 0.04, blue: 0.14),
                         Color(red: 0.02, green: 0.02, blue: 0.06)],
                center: UnitPoint(x: 0.5, y: 0.25), startRadius: 0, endRadius: 550
            )
            .ignoresSafeArea()
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
            .padding(.top, 100)   // clears the header (73pt top + ~79pt text + 10pt gap)

            // Header — same centred 3-line format as Explore tab
            VStack {
                VStack(spacing: 8) {
                    Text(layout.name)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                        .kerning(3)
                    Text("Journey")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("\(viewModel.sessions.count) of 6 emotions explored")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .multilineTextAlignment(.center)
                .padding(.top, 77)
                Spacer()
            }
            .opacity(expandingSession == nil ? 1 : 0)
            .animation(.easeOut(duration: 0.3), value: expandingSession == nil)

            // ── Hologram expansion overlay ──────────────────────────────────
            if let exp = expandingSession {
                GeometryReader { geo in
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
                SessionDetailSheet(session: session, viewModel: viewModel)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.ultraThinMaterial)
            } else {
                SessionDetailSheet(session: session, viewModel: viewModel)
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
    @ObservedObject var viewModel: EmotionViewModel

    // Calendar month navigation (0 = current month, -1 = last month, etc.)
    @State private var calendarOffset: Int = 0
    // Frequency bar graph period, lifted so section title can reflect it
    @State private var freqPeriod: FrequencyPeriod = .week

    // "February 2026" based on calendarOffset
    private var calendarMonthTitle: String {
        let cal  = Calendar.current
        let base = cal.date(byAdding: .month, value: calendarOffset, to: Date()) ?? Date()
        let fmt  = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: base)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // ── Header ────────────────────────────────────────────────
                HStack(spacing: 14) {
                    Text(session.emotion.emoji)
                        .font(.system(size: 52))
                        .shadow(color: session.emotion.color.opacity(0.8), radius: 20)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.emotion.rawValue)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(session.formattedFullDate)
                            .font(.system(size: 12)).foregroundStyle(.white.opacity(0.45))
                    }
                }
                .padding(.top, 8)

                // ── Highlights + both charts (tight 10pt spacing) ─────────
                VStack(alignment: .leading, spacing: 10) {
                    Text("Highlights")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)

                    // ── Monthly Calendar ──────────────────────────────────
                    sectionCard(icon: "calendar") {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(session.emotion.color)
                                Text(calendarMonthTitle)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.70))
                            }
                            Spacer()
                            HStack(spacing: 0) {
                                Button { withAnimation { calendarOffset -= 1 } } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.55))
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                                Button { withAnimation { calendarOffset = min(calendarOffset + 1, 0) } } label: {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(calendarOffset < 0 ? .white.opacity(0.55) : .white.opacity(0.20))
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                                .disabled(calendarOffset >= 0)
                            }
                        }
                        CalendarGridView(
                            highlightedEmotion: session.emotion,
                            sessions: viewModel.sessions,
                            monthOffset: calendarOffset
                        )
                    } header: { EmptyView() }

                    // ── Frequency Bar Graph ───────────────────────────────
                    sectionCard(icon: "chart.bar.fill") {
                        HStack(spacing: 6) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(session.emotion.color)
                            Text(freqPeriod.label)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.70))
                        }
                        FrequencyBarGraph(
                            highlightedEmotion: session.emotion,
                            sessions: viewModel.sessions,
                            period: $freqPeriod
                        )
                    } header: { EmptyView() }
                } // end Highlights + charts VStack

            }   // VStack
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }   // ScrollView
        .background(
            ZStack {
                Color.clear.ignoresSafeArea()
                session.emotion.color.opacity(0.10).ignoresSafeArea()
            }
        )

    }

    // Generic bare card — header content is injected by caller
    @ViewBuilder
    private func sectionCard<Content: View, Header: View>(
        icon: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder header: () -> Header
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .padding(16)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(.white.opacity(0.10), lineWidth: 1))
    }
}

// MARK: - Calendar Grid View

struct CalendarGridView: View {
    let highlightedEmotion: Emotion
    let sessions: [EmotionSession]
    let monthOffset: Int          // 0 = current month; negative = past months

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let dayLabels = ["S","M","T","W","T","F","S"]

    private var loggedSessions: [EmotionSession] { sessions.filter { $0.isLogged } }

    // First day of the displayed month
    private var displayedMonthStart: Date {
        let base = calendar.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
        let comps = calendar.dateComponents([.year, .month], from: base)
        return calendar.date(from: comps) ?? base
    }

    private var monthDays: [Date?] {
        let first = displayedMonthStart
        guard let range = calendar.range(of: .day, in: .month, for: first) else { return [] }
        let weekday = calendar.component(.weekday, from: first) - 1
        var days: [Date?] = Array(repeating: nil, count: weekday)
        for d in range {
            if let date = calendar.date(byAdding: .day, value: d - 1, to: first) {
                days.append(date)
            }
        }
        return days
    }

    private func sessionsOn(_ date: Date) -> [EmotionSession] {
        loggedSessions.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    var body: some View {
        VStack(spacing: 6) {
            // Day-of-week header
            HStack(spacing: 0) {
                ForEach(dayLabels, id: \.self) { d in
                    Text(d).font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.30))
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, day in
                    if let day = day {
                        DayCell(day: day,
                                daySessions: sessionsOn(day),
                                highlightedEmotion: highlightedEmotion,
                                isToday: calendar.isDateInToday(day))
                    } else {
                        Color.clear.frame(height: 36)
                    }
                }
            }
        }
    }
}

struct DayCell: View {
    let day: Date
    let daySessions: [EmotionSession]
    let highlightedEmotion: Emotion
    let isToday: Bool

    private var dayNumber: String {
        "\(Calendar.current.component(.day, from: day))"
    }

    // Session for the highlighted emotion on this day (if any)
    private var highlightSession: EmotionSession? {
        daySessions.first { $0.emotion == highlightedEmotion }
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(dayNumber)
                .font(.system(size: 11, weight: isToday ? .bold : .regular))
                .foregroundStyle(isToday ? highlightedEmotion.color : .white.opacity(0.55))
                .frame(height: 16)

            // Dot row: always compact — dot for highlighted + overflow count
            Group {
                if daySessions.isEmpty {
                    Color.clear.frame(width: 5, height: 5)
                } else if daySessions.count == 1 {
                    // Single dot
                    Circle()
                        .fill(daySessions[0].emotion.color)
                        .opacity(daySessions[0].emotion == highlightedEmotion ? 1.0 : 0.22)
                        .frame(width: 5, height: 5)
                } else {
                    // More than one: show highlighted emotion dot (or first) + overflow
                    HStack(spacing: 2) {
                        let show = highlightSession ?? daySessions[0]
                        Circle()
                            .fill(show.emotion.color)
                            .frame(width: 5, height: 5)
                        let extra = daySessions.count - 1
                        Text("+\(extra)")
                            .font(.system(size: 6, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
        }
        .frame(height: 36)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isToday ? highlightedEmotion.color.opacity(0.15) : .clear)
        )
    }
}

// MARK: - Frequency Vertical Bar Graph

enum FrequencyPeriod: String, CaseIterable {
    case day  = "D"
    case week = "W"
    case month = "M"
    case year = "Y"

    var days: Int {
        switch self { case .day: return 1; case .week: return 7; case .month: return 30; case .year: return 365 }
    }

    var label: String {
        switch self { case .day: return "Today"; case .week: return "Last 7 Days"; case .month: return "Last 30 Days"; case .year: return "Last Year" }
    }
}

struct FrequencyBarGraph: View {
    let highlightedEmotion: Emotion
    let sessions: [EmotionSession]

    @Binding var period: FrequencyPeriod

    private var loggedInPeriod: [EmotionSession] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -period.days, to: Date()) ?? Date()
        return sessions.filter { $0.isLogged && $0.date >= cutoff }
    }

    private func count(for emotion: Emotion) -> Int {
        loggedInPeriod.filter { $0.emotion == emotion }.count
    }

    private var maxCount: Int {
        max(1, Emotion.allCases.map { count(for: $0) }.max() ?? 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            periodPicker
            periodSubtitle
            barsRow
        }
    }

    private var periodPicker: some View {
        HStack(spacing: 0) {
            ForEach(FrequencyPeriod.allCases, id: \.self) { p in
                periodButton(p)
            }
        }
        .padding(4)
        .background(.white.opacity(0.10), in: Capsule())
    }

    @ViewBuilder
    private func periodButton(_ p: FrequencyPeriod) -> some View {
        let selected = (period == p)
        Button { withAnimation(.spring(response: 0.35)) { period = p } } label: {
            Text(p.rawValue)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selected ? Color.black : Color.white.opacity(0.55))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(selected ? AnyView(Color.white.clipShape(Capsule())) : AnyView(Color.clear))
        }
        .buttonStyle(.plain)
    }

    private var periodSubtitle: some View {
        Text(period.label)
            .font(.system(size: 11))
            .foregroundStyle(Color.white.opacity(0.35))
    }

    private var barsRow: some View {
        GeometryReader { geo in
            let barW   = (geo.size.width - 5 * 12) / 6
            let chartH = geo.size.height - 32
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(Emotion.allCases, id: \.self) { emotion in
                    barColumn(emotion: emotion, barWidth: barW, chartH: chartH)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(height: 140)
    }

    // Extracted to help the type-checker — avoids complex inline expression
    @ViewBuilder
    private func barColumn(emotion: Emotion, barWidth: CGFloat, chartH: CGFloat) -> some View {
        let c     = count(for: emotion)
        let isHL  = emotion == highlightedEmotion
        let fillH = c == 0 ? CGFloat(2) : CGFloat(c) / CGFloat(maxCount) * chartH

        VStack(spacing: 4) {
            Text(c == 0 ? "" : "\(c)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isHL ? emotion.color : .white.opacity(0.45))
                .frame(height: 12)

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isHL ? AnyShapeStyle(emotion.color) : AnyShapeStyle(Color.white.opacity(0.18)))
                .frame(width: barWidth, height: max(2, fillH))
                .opacity(isHL ? 1.0 : 0.5)
                .animation(.spring(response: 0.55, dampingFraction: 0.72), value: c)

            Text(emotion.emoji)
                .font(.system(size: 14))
                .frame(width: barWidth)
        }
    }
}

// MARK: - Article Browse Card (Health-app style)

struct ArticleCardView: View {
    let article: EmotionArticle
    let accentColor: Color
    let onTap: () -> Void      // caller (SessionDetailSheet) owns the sheet

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {

                // ── Thumbnail ───────────────────────────────────────────
                ZStack {
                    LinearGradient(
                        colors: [accentColor.opacity(0.55), accentColor.opacity(0.20)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    if let uiImg = UIImage(named: article.thumbnailName) {
                        Image(uiImage: uiImg)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: thumbnailIcon)
                            .font(.system(size: 48, weight: .ultraLight))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
                .frame(height: 160)
                .clipped()

                // ── Text block ─────────────────────────────────────────
                VStack(alignment: .leading, spacing: 6) {
                    Text(article.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)

                    Text(article.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        Text(article.readTime)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(accentColor.opacity(0.15), in: Capsule())
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.25))
                    }
                    .padding(.top, 2)
                }
                .padding(14)
            }
        }
        .buttonStyle(.plain)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(.white.opacity(0.10), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        // No .sheet here — sheet is owned by SessionDetailSheet
    }

    private var thumbnailIcon: String {
        switch article.thumbnailName {
        case let n where n.contains("calm"):    return "waveform.path.ecg"
        case let n where n.contains("anxiety"): return "bolt.fill"
        case let n where n.contains("sadness"): return "cloud.rain.fill"
        case let n where n.contains("love"):    return "heart.fill"
        case let n where n.contains("happy"):   return "sparkles"
        case let n where n.contains("angry"):   return "flame.fill"
        default: return "doc.text.fill"
        }
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
