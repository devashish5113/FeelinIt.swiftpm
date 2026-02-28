import SwiftUI

// MARK: - Articles Tab

struct ArticlesView: View {
    @State private var selectedArticle: EmotionArticle? = nil

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    ForEach(Emotion.allCases) { emotion in
                        EmotionArticleSection(emotion: emotion, onSelect: { selectedArticle = $0 })
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .scrollContentBackground(.hidden)
            .background {
                // Background lives INSIDE NavigationView — the only way to
                // reliably show through its opaque container
                ZStack {
                    RadialGradient(
                        colors: [Color(red: 0.06, green: 0.04, blue: 0.14),
                                 Color(red: 0.02, green: 0.02, blue: 0.06)],
                        center: UnitPoint(x: 0.5, y: 0.25), startRadius: 0, endRadius: 550
                    )
                    StarField()
                }
                .ignoresSafeArea()
            }
            .navigationTitle("Articles")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .sheet(item: $selectedArticle) { article in
            ArticleDetailSheet(
                article: article,
                accentColor: accentColor(for: article)
            )
        }
    }

    // Map article back to its emotion colour for the detail sheet
    private func accentColor(for article: EmotionArticle) -> Color {
        for emotion in Emotion.allCases {
            if emotion.articles.contains(where: { $0.id == article.id }) {
                return emotion.color
            }
        }
        return .purple
    }
}

// MARK: - Per-emotion Section

private struct EmotionArticleSection: View {
    let emotion: Emotion
    let onSelect: (EmotionArticle) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section heading
            Text("About \(emotion.rawValue)")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            ForEach(emotion.articles) { article in
                ArticleBrowseCard(
                    article: article,
                    accentColor: emotion.color,
                    onTap: { onSelect(article) }
                )
            }
        }
    }
}

// MARK: - Browse Card (light, Health-app style)

struct ArticleBrowseCard: View {
    let article: EmotionArticle
    let accentColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {

                // ── Thumbnail ─────────────────────────────────────────────
                ZStack {
                    LinearGradient(
                        colors: [accentColor.opacity(0.70), accentColor.opacity(0.30)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    if let uiImg = UIImage(named: article.thumbnailName) {
                        Image(uiImage: uiImg)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: placeholderIcon)
                            .font(.system(size: 52, weight: .ultraLight))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .clipped()

                // ── Text ──────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 5) {
                    Text(article.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(article.subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .background(Color(white: 0.13))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
    }

    private var placeholderIcon: String {
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

// MARK: - Article Full-Screen Reader Sheet

struct ArticleDetailSheet: View {
    let article: EmotionArticle
    let accentColor: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                // frame(maxWidth: .infinity) gives the column a definite width
                // so all child Text views know their wrapping boundary.
                VStack(alignment: .leading, spacing: 0) {

                    // Hero thumbnail — GeometryReader ensures image layout
                    // never exceeds screen width regardless of aspect ratio
                    GeometryReader { geo in
                        ZStack {
                            LinearGradient(
                                colors: [accentColor.opacity(0.65), accentColor.opacity(0.25)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                            if let uiImg = UIImage(named: article.thumbnailName) {
                                Image(uiImage: uiImg)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geo.size.width, height: 240)
                                    .clipped()
                            } else {
                                Image(systemName: heroIcon)
                                    .font(.system(size: 80, weight: .ultraLight))
                                    .foregroundStyle(.white.opacity(0.35))
                            }
                        }
                        .frame(width: geo.size.width, height: 240)
                    }
                    .frame(height: 240)

                    // Article body — 24pt breathing room on both sides
                    VStack(alignment: .leading, spacing: 22) {
                        Text(article.title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Color(.label))
                            .multilineTextAlignment(.leading)

                        ForEach(article.sections) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                if !section.heading.isEmpty {
                                    Text(section.heading)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(Color(.label))
                                        .multilineTextAlignment(.leading)
                                }
                                Text(section.body)
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color(.secondaryLabel))
                                    .lineSpacing(6)
                                    .multilineTextAlignment(.leading)
                            }
                        }

                        // Source attribution
                        HStack(spacing: 5) {
                            Image(systemName: "link")
                                .font(.system(size: 11))
                            Text("Source: \(article.source)")
                                .font(.system(size: 12))
                                .multilineTextAlignment(.leading)
                        }
                        .foregroundStyle(Color(.tertiaryLabel))
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 48)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                }
                .frame(maxWidth: .infinity)   // ← key: constrains text width
            }
            .ignoresSafeArea(edges: .top)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(accentColor)
                }
            }
        }
    }

    private var heroIcon: String {
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

