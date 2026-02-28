import SwiftUI

@available(iOS 26, *)
struct MentalCoachFAB: View {
    @StateObject private var vm = MentalCoachViewModel()
    @State private var showChat = false
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            showChat = true
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
                    .shadow(color: .purple.opacity(0.45), radius: pulse ? 14 : 8, x: 0, y: 4)

                Image(systemName: "stethoscope")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
            }
            .opacity(0.80)
        }
        .accessibilityLabel("Dr. Feel, your AI wellness coach")
        .accessibilityHint("Double tap to start a conversation")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .sheet(isPresented: $showChat) {
            MentalCoachChatView(vm: vm)
        }
    }
}

@available(iOS 26, *)
struct MentalCoachChatView: View {
    @ObservedObject var vm: MentalCoachViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            if vm.messages.isEmpty {
                                welcomeCard
                                    .padding(.top, 20)
                            }

                            ForEach(vm.messages) { msg in
                                messageBubble(msg)
                                    .id(msg.id)
                            }

                            if vm.isResponding {
                                typingIndicator
                                    .id("typing")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                    .onChange(of: vm.messages.count) { _ in
                        withAnimation {
                            if let lastID = vm.messages.last?.id {
                                proxy.scrollTo(lastID, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: vm.messages.last?.content) { _ in
                        withAnimation {
                            if let lastID = vm.messages.last?.id {
                                proxy.scrollTo(lastID, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()
                inputBar
            }
            .background(Color(red: 0.06, green: 0.04, blue: 0.12))
            .navigationTitle("Dr. Feel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(red: 0.08, green: 0.06, blue: 0.14), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        vm.resetChat()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .disabled(vm.messages.isEmpty)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.purple)
                }
            }
        }
    }

    private var welcomeCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "stethoscope")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )

            Text("Hey, I'm Dr. Feel")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

            Text("Tell me how you're feeling today, and I'll help you work through it.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)

            VStack(spacing: 8) {
                quickStartButton("I'm feeling anxious today", icon: "bolt.heart")
                quickStartButton("I need help calming down", icon: "leaf")
                quickStartButton("I'm feeling sad and low", icon: "cloud.rain")
                quickStartButton("I just want someone to listen", icon: "ear")
            }
            .padding(.top, 8)
        }
        .padding(24)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func quickStartButton(_ text: String, icon: String) -> some View {
        Button {
            vm.send(text)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.purple)
                    .frame(width: 20)
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    @ViewBuilder
    private func messageBubble(_ msg: ChatMessage) -> some View {
        VStack(alignment: msg.role == .user ? .trailing : .leading, spacing: 8) {
            HStack {
                if msg.role == .user { Spacer(minLength: 60) }

                Text(msg.content)
                    .font(.system(size: 15))
                    .foregroundStyle(msg.role == .user ? .white : .white.opacity(0.9))
                    .lineSpacing(4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        msg.role == .user
                            ? AnyShapeStyle(LinearGradient(
                                colors: [Color(red: 0.45, green: 0.25, blue: 0.85),
                                         Color(red: 0.55, green: 0.30, blue: 0.90)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(Color.white.opacity(0.08))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                if msg.role == .assistant { Spacer(minLength: 40) }
            }

            if !msg.options.isEmpty && !vm.isResponding {
                VStack(spacing: 6) {
                    ForEach(msg.options, id: \.self) { option in
                        Button {
                            vm.selectOption(option)
                        } label: {
                            HStack {
                                Text(option)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "arrow.right.circle")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.purple.opacity(0.7))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.purple.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .disabled(vm.isResponding)
                    }
                }
                .padding(.leading, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: msg.role == .user ? .trailing : .leading)
    }

    private var typingIndicator: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.purple.opacity(0.5))
                    .frame(width: 7, height: 7)
                    .scaleEffect(vm.isResponding ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(i) * 0.15),
                        value: vm.isResponding
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Type how you feel…", text: $vm.inputText, axis: .vertical)
                .lineLimit(1...4)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .focused($inputFocused)

            Button {
                vm.send(vm.inputText)
                inputFocused = false
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isResponding
                            ? Color.gray.opacity(0.3)
                            : Color.purple
                    )
            }
            .disabled(vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isResponding)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(red: 0.08, green: 0.06, blue: 0.14))
    }
}
