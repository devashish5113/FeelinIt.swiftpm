import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = EmotionViewModel()

    var body: some View {
        ZStack {
            if viewModel.selectedEmotion == nil {
                EmotionSelectionView(viewModel: viewModel)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal:   .opacity.combined(with: .scale(scale: 1.05))
                        )
                    )
            } else {
                NeuralVisualizationView(viewModel: viewModel)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 1.05)),
                            removal:   .opacity.combined(with: .scale(scale: 0.95))
                        )
                    )
            }
        }
        .animation(.easeInOut(duration: 0.5), value: viewModel.selectedEmotion == nil)
        .preferredColorScheme(.dark)
    }
}
