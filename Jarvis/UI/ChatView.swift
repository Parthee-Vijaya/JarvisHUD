import SwiftUI

struct ChatView: View {
    let chatSession: ChatSession
    let onSend: (String) -> Void
    let onVoice: (() -> Void)?
    let onClose: () -> Void
    let onPin: () -> Void
    let isPinned: Bool

    @State private var inputText = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader

            Divider()

            // Messages
            messagesArea

            Divider()

            // Input bar
            inputBar
        }
        .frame(
            minWidth: Constants.ChatHUD.minWidth,
            minHeight: Constants.ChatHUD.minHeight
        )
        .onAppear {
            inputFocused = true
        }
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .foregroundStyle(.accent)
                .font(.title3)
            Text("Jarvis Chat").font(.headline)
            Spacer()
            Button(action: onPin) {
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .foregroundStyle(isPinned ? .accent : .secondary)
            }
            .buttonStyle(.borderless)
            .help(isPinned ? "Unpin" : "Pin")
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Messages

    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if chatSession.messages.isEmpty {
                        emptyState
                    }
                    ForEach(chatSession.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: chatSession.messages.count) {
                if let last = chatSession.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: chatSession.messages.last?.text) {
                if let last = chatSession.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("Start en samtale med Jarvis")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Skriv en besked eller hold mic-knappen")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            if let onVoice {
                Button(action: onVoice) {
                    Image(systemName: "mic.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Tal til Jarvis")
            }

            TextField("Skriv en besked...", text: $inputText)
                .textFieldStyle(.plain)
                .focused($inputFocused)
                .onSubmit { sendMessage() }

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary : Color.accentColor)
            }
            .buttonStyle(.borderless)
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || chatSession.isStreaming)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !chatSession.isStreaming else { return }
        inputText = ""
        onSend(text)
    }
}
