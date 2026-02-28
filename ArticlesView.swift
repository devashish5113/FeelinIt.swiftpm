import SwiftUI
import AVFoundation

struct ArticlesView: View {
    @State private var selectedArticle: EmotionArticle? = nil

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 36) {
                    ForEach(Emotion.allCases) { emotion in
                        EmotionArticleSection(emotion: emotion, onSelect: { selectedArticle = $0 })
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollContentBackground(.hidden)
            .background {
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

    private func accentColor(for article: EmotionArticle) -> Color {
        for emotion in Emotion.allCases {
            if emotion.articles.contains(where: { $0.id == article.id }) {
                return emotion.color
            }
        }
        return .purple
    }
}

private struct EmotionArticleSection: View {
    let emotion: Emotion
    let onSelect: (EmotionArticle) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About \(emotion.rawValue)")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .accessibilityAddTraits(.isHeader)

            ForEach(emotion.articles) { article in
                ArticleBrowseCard(
                    article: article,
                    accentColor: emotion.color,
                    onTap: { onSelect(article) }
                )
                .padding(.horizontal, 16)
            }
        }
    }
}

struct ArticleBrowseCard: View {
    let article: EmotionArticle
    let accentColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(article.title). \(article.subtitle)")
        .accessibilityHint("Double tap to read full article")
        .accessibilityAddTraits(.isButton)
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

struct ArticleDetailSheet: View {
    let article: EmotionArticle
    let accentColor: Color
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speaker = ArticleSpeaker()

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
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
                    .frame(maxWidth: .infinity)
                }
                .ignoresSafeArea(edges: .top)

                Button {
                    if speaker.isSpeaking {
                        speaker.stop()
                    } else {
                        speaker.speak(article: article)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.30, green: 0.10, blue: 0.65),
                                             Color(red: 0.50, green: 0.18, blue: 0.80)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color(red: 0.75, green: 0.55, blue: 1.0),
                                                     Color(red: 0.90, green: 0.50, blue: 0.85)],
                                            startPoint: .top, endPoint: .bottom
                                        ),
                                        lineWidth: 2
                                    )
                            )
                            .frame(width: 56, height: 56)
                            .shadow(color: .purple.opacity(0.45), radius: 8, x: 0, y: 4)

                        Image(systemName: speaker.isSpeaking ? "stop.circle.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .opacity(0.80)
                }
                .accessibilityLabel(speaker.isSpeaking ? "Stop reading" : "Read article aloud")
                .accessibilityHint(speaker.isSpeaking ? "Double tap to stop" : "Double tap to hear this article")
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        speaker.stop()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(accentColor)
                }
            }
        }
        .onDisappear { speaker.stop() }
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

final class ArticleSpeaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var isSpeaking = false
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try? AVAudioSession.sharedInstance().setActive(true)
            DispatchQueue.main.async {
                let warmup = AVSpeechUtterance(string: " ")
                warmup.volume = 0
                self?.synthesizer.speak(warmup)
            }
        }
    }

    func speak(article: EmotionArticle) {
        stop()
        var text = article.title + ". "
        for section in article.sections {
            if !section.heading.isEmpty { text += section.heading + ". " }
            text += section.body + " "
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        utterance.pitchMultiplier = 1.05
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }
}
