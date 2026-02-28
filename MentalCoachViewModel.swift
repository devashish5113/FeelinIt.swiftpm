import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Chat Message Model

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    var content: String
    var options: [String]

    enum Role { case user, assistant }

    static func user(_ text: String) -> ChatMessage {
        ChatMessage(role: .user, content: text, options: [])
    }

    static func assistant(_ text: String, options: [String] = []) -> ChatMessage {
        ChatMessage(role: .assistant, content: text, options: options)
    }
}

// MARK: - View Model

@available(iOS 26, *)
@MainActor
final class MentalCoachViewModel: ObservableObject {

    @Published var messages: [ChatMessage] = []
    @Published var isResponding = false
    @Published var inputText = ""

    private var responseTask: Task<Void, Never>?

    #if canImport(FoundationModels)
    private lazy var session: LanguageModelSession = {
        LanguageModelSession(instructions: Self.systemInstruction)
    }()

    private static let systemInstruction = """
    You are a warm, compassionate mental wellness coach inside an app called FeelinIt. \
    Your role is to help the user explore and understand their emotions in a safe, non-judgmental space. \
    Keep responses concise — 3 to 4 sentences maximum. Be empathetic but practical. \
    After every response, add a blank line and then list exactly 4 short actionable options the user can pick, \
    formatted as a numbered list (1. … 2. … 3. … 4. …). \
    The options should be contextually relevant to what the user said. \
    Examples of option categories: talk it through deeper, get a practical coping strategy, \
    try a quick breathing exercise, hear a positive affirmation. \
    Do NOT use markdown formatting — plain text only. \
    Never diagnose or prescribe medication. If the user expresses thoughts of self-harm, \
    gently encourage them to contact a crisis helpline.
    """
    #endif

    init() {}

    // MARK: Send
    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        inputText = ""
        messages.append(.user(trimmed))
        responseTask = Task { await generateResponse(for: trimmed) }
    }

    func selectOption(_ option: String) {
        // Remove all options from the message that offered them
        if let lastAssistantIndex = messages.lastIndex(where: { $0.role == .assistant }) {
            messages[lastAssistantIndex].options = []
        }
        // Place option text in the input field so user can edit/complete it
        inputText = option
    }

    func resetChat() {
        responseTask?.cancel()
        responseTask = nil
        messages = []
        inputText = ""
        isResponding = false
        #if canImport(FoundationModels)
        session = LanguageModelSession(instructions: Self.systemInstruction)
        #endif
    }

    // MARK: Response generation
    private func generateResponse(for prompt: String) async {
        isResponding = true
        messages.append(.assistant(""))
        let index = messages.count - 1

        #if canImport(FoundationModels)
        do {
            let stream = session.streamResponse(to: prompt)
            for try await chunk in stream {
                guard !Task.isCancelled, index < messages.count else { return }
                messages[index].content = chunk.content
            }
        } catch {
            guard !Task.isCancelled, index < messages.count else { return }
            messages[index].content = "I'm having trouble responding right now. Please try again."
        }
        #else
        guard index < messages.count else { return }
        messages[index].content = "Foundation Models is not available on this device."
        #endif

        // Parse numbered options from the response
        guard !Task.isCancelled, index < messages.count else { return }
        let parsed = parseOptions(from: messages[index].content)
        messages[index].content = parsed.body
        messages[index].options = parsed.options
        isResponding = false
    }

    // MARK: Option parsing
    private func parseOptions(from text: String) -> (body: String, options: [String]) {
        let lines = text.components(separatedBy: "\n")
        var bodyLines: [String] = []
        var options: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let first = trimmed.first, first.isNumber,
               trimmed.count > 2,
               trimmed[trimmed.index(after: trimmed.startIndex)] == "." {
                let optionText = String(trimmed.dropFirst(2))
                    .trimmingCharacters(in: .whitespaces)
                if !optionText.isEmpty {
                    options.append(optionText)
                }
            } else {
                bodyLines.append(line)
            }
        }

        let body = bodyLines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (body, options)
    }
}
