import Foundation
import Observation

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

/// Multi-turn chat session. v5.0.0-alpha removed the cached SDK `Chat` object —
/// we now pass the full message history to `GeminiClient.sendChatStreaming`
/// on each turn, which is what the REST API expects anyway. That means an
/// API-key rotation takes effect immediately: no cached credentials sitting
/// inside an SDK object.
@Observable
class ChatSession {
    var messages: [ChatMessage] = []
    var isStreaming = false

    func addUserMessage(_ text: String) {
        messages.append(ChatMessage(role: .user, text: text))
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
        isStreaming = false
    }

    /// Turn the message log into REST history suitable for
    /// `GeminiClient.sendChatStreaming(history:)`. Drops empty assistant
    /// placeholders (the streaming sentinel) and drops the trailing user
    /// message (which the caller passes separately as `text`).
    ///
    /// The Gemini REST API also requires history to end on a `model` turn
    /// (or be empty). α.12 adds a defensive trim that ensures we never send
    /// history ending on a `user` turn — if the session is corrupted (e.g.
    /// crash-recovered mid-turn) we walk back to the last valid model reply.
    func currentHistory(excludingLastUser: Bool = true) -> [GeminiContent] {
        var prepared: [GeminiContent] = []
        for message in messages {
            let role = message.role == .user ? "user" : "model"
            let trimmed = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            prepared.append(GeminiContent(role: role, parts: [.text(trimmed)]))
        }
        if excludingLastUser, prepared.last?.role == "user" {
            prepared.removeLast()
        }
        // Defensive: a valid history for Gemini ends on a model turn (or is
        // empty). Trim any trailing user messages that would otherwise confuse
        // the API or the model into re-answering them.
        while prepared.last?.role == "user" {
            prepared.removeLast()
        }
        return prepared
    }
}
