import AppKit
import Foundation

/// β.11 coordination layer for the unified chat command bar. Takes a
/// `(Mode, input)` pair from the UI and dispatches to the right pipeline or
/// service. All results feed back into the same `ChatSession`, so the chat's
/// message list renders everything uniformly regardless of which mode ran.
///
/// Direct hotkey invocations (⌥Q, ⌥⇧Space, etc.) do NOT route through this
/// router — they keep their legacy paste/HUD flow. This router is only used
/// when the user picks a mode inside the chat window.
@MainActor
final class ChatCommandRouter {
    enum RouterError: LocalizedError {
        case pickerCancelled
        case screenCaptureFailed(Error)
        case summaryFailed(Error)
        case geminiFailed(Error)

        var errorDescription: String? {
            switch self {
            case .pickerCancelled:          return "Ingen fil valgt."
            case .screenCaptureFailed(let e): return "Kunne ikke tage skærmbillede: \(e.localizedDescription)"
            case .summaryFailed(let e):     return "Opsummering fejlede: \(e.localizedDescription)"
            case .geminiFailed(let e):      return "AI-kald fejlede: \(e.localizedDescription)"
            }
        }
    }

    private let chatPipeline: ChatPipeline
    private let agentChatPipeline: () -> AgentChatPipeline?
    private let geminiClient: GeminiClient
    private let screenCapture: ScreenCaptureService
    private let summaryService: DocumentSummaryService
    private let chatSession: ChatSession

    init(
        chatPipeline: ChatPipeline,
        agentChatPipeline: @escaping () -> AgentChatPipeline?,
        geminiClient: GeminiClient,
        screenCapture: ScreenCaptureService,
        summaryService: DocumentSummaryService,
        chatSession: ChatSession
    ) {
        self.chatPipeline = chatPipeline
        self.agentChatPipeline = agentChatPipeline
        self.geminiClient = geminiClient
        self.screenCapture = screenCapture
        self.summaryService = summaryService
        self.chatSession = chatSession
    }

    // MARK: - Public

    /// Run a mode-scoped command. `input` semantics vary with
    /// `mode.inputKind`:
    ///   - `.text`      → plain user prompt
    ///   - `.voice`     → ignored (mic capture starts elsewhere via RecordingPipeline)
    ///   - `.screenshot`→ user's optional question about the screen
    ///   - `.document`  → ignored (the file picker launches on trigger)
    func run(mode: Mode, input: String) async {
        switch mode.inputKind {
        case .text:
            await runText(mode: mode, input: input)
        case .screenshot:
            await runVision(mode: mode, input: input)
        case .document:
            await runSummarize(mode: mode)
        case .voice:
            // Dictation from the chat bar is handled by the RecordingPipeline
            // directly — the command bar starts/stops the mic, no router step.
            break
        }
    }

    // MARK: - Text (Chat / Q&A / Translate / Agent / custom text modes)

    private func runText(mode: Mode, input: String) async {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        if mode.provider == .anthropic, mode.agentTools,
           let agent = agentChatPipeline() {
            agent.sendTextMessage(input)
        } else {
            // Gemini path — reuses ChatPipeline but with the picked mode's
            // systemPrompt + webSearch flag.
            chatPipeline.sendTextMessage(input, mode: mode)
        }
    }

    // MARK: - Screenshot (Vision)

    private func runVision(mode: Mode, input: String) async {
        let prompt = input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Beskriv hvad du ser på skærmen."
            : input

        chatSession.addUserMessage(prompt)
        let placeholderID = chatSession.addAssistantMessage("")
        chatSession.isStreaming = true
        defer { chatSession.isStreaming = false }

        let imageData: Data
        do {
            imageData = try await screenCapture.captureActiveWindow()
        } catch {
            chatSession.updateAssistant(
                id: placeholderID,
                text: RouterError.screenCaptureFailed(error).errorDescription ?? "Skærmfangst fejlede."
            )
            return
        }

        let result = await geminiClient.sendTextWithImage(
            prompt: prompt,
            mode: mode,
            imageData: imageData
        )
        switch result {
        case .success(let text):
            chatSession.updateAssistant(id: placeholderID, text: text)
        case .failure(let error):
            chatSession.updateAssistant(
                id: placeholderID,
                text: RouterError.geminiFailed(error).errorDescription ?? "AI-kald fejlede."
            )
        }
    }

    // MARK: - Document (Summarize)

    private func runSummarize(mode: Mode) async {
        guard let url = DocumentPicker.pickDocument() else { return }

        chatSession.addUserMessage("📄 \(url.lastPathComponent) — opsummer dette dokument")
        let placeholderID = chatSession.addAssistantMessage("")
        chatSession.isStreaming = true
        defer { chatSession.isStreaming = false }

        do {
            let summary = try await summaryService.summarizeForChat(url: url)
            chatSession.updateAssistant(id: placeholderID, text: summary)
        } catch {
            chatSession.updateAssistant(
                id: placeholderID,
                text: RouterError.summaryFailed(error).errorDescription ?? "Opsummering fejlede."
            )
        }
    }
}
