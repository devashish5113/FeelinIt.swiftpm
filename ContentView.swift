import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = EmotionViewModel()

    var body: some View {
        ZStack {
            // Tab bar sits underneath everything
            TabView {
                // ── Tab 1: Explore ──────────────────────────────────────
                EmotionSelectionView(viewModel: viewModel)
                    .tabItem {
                        Label("Explore", systemImage: "brain.head.profile")
                    }

                // ── Tab 2: Journey ──────────────────────────────────────
                JourneyView(viewModel: viewModel)
                    .tabItem {
                        Label("Journey", systemImage: "sparkles")
                    }
            }
            .tint(Color(red: 0.68, green: 0.45, blue: 1.0))
            .preferredColorScheme(.dark)

            // NeuralVisualizationView overlays the full screen during exploration,
            // naturally hiding the tab bar for an immersive experience.
            if viewModel.selectedEmotion != nil {
                NeuralVisualizationView(viewModel: viewModel)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 1.05)),
                        removal:   .opacity.combined(with: .scale(scale: 0.95))
                    ))
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: viewModel.selectedEmotion == nil)
    }
}
