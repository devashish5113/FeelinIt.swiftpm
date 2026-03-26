import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 60)

            // App icon
            if let uiImg = UIImage(named: "Feelinit icon") {
                Image(uiImage: uiImg)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color(red: 0.68, green: 0.45, blue: 1.0).opacity(0.4), radius: 16, x: 0, y: 6)
                    .padding(.bottom, 16)
            }

            // Title
            VStack(spacing: 8) {
                Text("Welcome to")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("FeelinIt")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.68, green: 0.45, blue: 1.0))
            }
            .padding(.bottom, 48)

            // Feature rows
            VStack(alignment: .leading, spacing: 28) {
                featureRow(
                    icon: "brain.head.profile",
                    color: Color(red: 0.68, green: 0.45, blue: 1.0),
                    title: "Explore Your Emotions",
                    description: "A living 3D neuron responds to six core emotions in real time."
                )

                featureRow(
                    icon: "wind",
                    color: Color(red: 0.3, green: 0.8, blue: 0.7),
                    title: "Restore Balance",
                    description: "Guided breathing and hand-steadiness biofeedback bring you back to calm."
                )

                featureRow(
                    icon: "sparkles",
                    color: Color(red: 1.0, green: 0.75, blue: 0.3),
                    title: "Track Your Journey",
                    description: "Every session becomes a star in your personal constellation."
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            // Health disclaimer
            Text("FeelinIt is a wellness tool, not a medical device. It does not diagnose, treat, or prevent any condition. AI suggestions are not professional medical advice. All data stays on your device. If you are in crisis, contact emergency services.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 16)

            // Continue button
            Button {
                withAnimation(.easeInOut(duration: 0.35)) {
                    isPresented = false
                }
            } label: {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(red: 0.68, green: 0.45, blue: 1.0))
                    )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 50)
        }
        .background(Color(red: 0.02, green: 0.02, blue: 0.06).ignoresSafeArea())
    }

    @ViewBuilder
    private func featureRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
        }
    }
}
