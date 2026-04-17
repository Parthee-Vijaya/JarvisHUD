import Foundation
import Observation
import GoogleGenerativeAI

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: ChatRole
    var text: String
    let timestamp: Date

    enum ChatRole: String, Codable {
        case user
        case assistant
    }

    init(id: UUID = UUID(), role: ChatRole, text: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }
}

@Observable
class ChatSession {
    var messages: [ChatMessage] = []
    var isStreaming = false

    /// SDK chat object for multi-turn conversation
    var sdkChat: Chat?

    func addUserMessage(_ text: String) {
        let message = ChatMessage(role: .user, text: text)
        messages.append(message)
    }

    func addAssistantMessage(_ text: String) -> UUID {
        let message = ChatMessage(role: .assistant, text: text)
        messages.append(message)
        return message.id
    }

    func appendToAssistant(id: UUID, delta: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].text += delta
    }

    func updateAssistant(id: UUID, text: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].text = text
    }

    func clear() {
        messages.removeAll()
        sdkChat = nil
        isStreaming = false
    }

    /// Convert messages to ModelContent history for Gemini SDK
    func toModelHistory() -> [ModelContent] {
        messages.compactMap { msg in
            let role = msg.role == .user ? "user" : "model"
            guard !msg.text.isEmpty else { return nil }
            return ModelContent(role: role, parts: [.text(msg.text)])
        }
    }
}
