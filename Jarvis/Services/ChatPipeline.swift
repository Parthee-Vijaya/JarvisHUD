import Foundation
import GoogleGenerativeAI

class ChatPipeline {
    private let geminiClient: GeminiClient
    private let chatSession: ChatSession
    private let hudController: HUDWindowController
    private let mode: Mode
    private let conversationStore = ConversationStore()

    private var sdkChat: Chat?
    private var conversationID: UUID?

    init(
        geminiClient: GeminiClient,
        chatSession: ChatSession,
        hudController: HUDWindowController,
        mode: Mode = BuiltInModes.chat
    ) {
        self.geminiClient = geminiClient
        self.chatSession = chatSession
        self.hudController = hudController
        self.mode = mode
    }

    // MARK: - Text Message

    func sendTextMessage(_ text: String) {
        chatSession.addUserMessage(text)
        let placeholderID = chatSession.addAssistantMessage("")
        chatSession.isStreaming = true

        Task {
            await streamResponse(placeholderID: placeholderID, text: text)
        }
    }

    // MARK: - Voice Message (transcribe first, then chat)

    func sendVoiceMessage(audioData: Data, transcribeMode: Mode) {
        chatSession.isStreaming = true

        Task {
            // Step 1: Transcribe audio to text
            let transcribeResult = await geminiClient.sendAudio(audioData, mode: transcribeMode)

            switch transcribeResult {
            case .success(let transcript):
                guard !transcript.isEmpty else {
                    chatSession.isStreaming = false
                    return
                }
                // Step 2: Add user message with transcript
                chatSession.addUserMessage(transcript)
                let placeholderID = chatSession.addAssistantMessage("")

                // Step 3: Stream chat response
                await streamResponse(placeholderID: placeholderID, text: transcript)

            case .failure(let error):
                LoggingService.shared.log("Voice transcription failed: \(error)", level: .error)
                chatSession.isStreaming = false
            }
        }
    }

    // MARK: - Streaming Core

    private func streamResponse(placeholderID: UUID, text: String) async {
        // Lazily create SDK chat. Re-create each time the cached chat is nil (e.g. API key rotation)
        // so a freshly-saved Keychain key is picked up without an app relaunch.
        if sdkChat == nil {
            if let (_, chat) = geminiClient.startChat(mode: mode, history: chatSession.toModelHistory().dropLast(1).map { $0 }) {
                sdkChat = chat
            } else {
                chatSession.updateAssistant(id: placeholderID, text: "Fejl: Ingen API-nøgle fundet. Tilføj den i Indstillinger.")
                chatSession.isStreaming = false
                // Persist the error so it doesn't silently disappear; empty-text filter in
                // toModelHistory strips it from subsequent API calls.
                conversationID = conversationStore.saveSession(chatSession, existingID: conversationID)
                return
            }
        }

        let result = await geminiClient.sendTextStreaming(
            chat: sdkChat!,
            text: text,
            mode: mode,
            onDelta: { [weak self] delta in
                self?.chatSession.appendToAssistant(id: placeholderID, delta: delta)
            }
        )

        switch result {
        case .success(let cleaned):
            // Replace with post-processed text
            chatSession.updateAssistant(id: placeholderID, text: cleaned)
        case .failure(let error):
            let errorText = chatSession.messages.first(where: { $0.id == placeholderID })?.text ?? ""
            if errorText.isEmpty {
                chatSession.updateAssistant(id: placeholderID, text: "Fejl: \(error.localizedDescription)")
            }
        }

        chatSession.isStreaming = false

        // Auto-save conversation
        conversationID = conversationStore.saveSession(chatSession, existingID: conversationID)
    }

    func reset() {
        sdkChat = nil
        conversationID = nil
    }
}
