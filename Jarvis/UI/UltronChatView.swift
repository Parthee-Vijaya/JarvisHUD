import SwiftUI

/// v2.0 Chat screen per the Ultron handoff (Screen 3). Wired to the real
/// `ChatSession` owned by `HUDWindowController` — messages are live,
/// the composer submits through the `onSend` callback which ultimately
/// routes into `ChatCommandRouter.run(mode:input:)`.
///
/// When `session` is nil the view renders a demo seed so Xcode previews
/// still work standalone (the preview at the bottom of this file).
struct UltronChatView: View {
    @Bindable var session: ChatSession
    var onSend: (String) -> Void = { _ in }
    var conversationTitle: String = "Ny samtale"

    @State private var composerText: String = ""
    @FocusState private var composerFocused: Bool

    init(session: ChatSession?, onSend: @escaping (String) -> Void) {
        self._session = Bindable(session ?? ChatSession())
        self.onSend = onSend
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 280)
                .background(UltronTheme.ink)
                .overlay(alignment: .trailing) {
                    Rectangle().fill(UltronTheme.lineSoft).frame(width: 1)
                }
            mainColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(UltronTheme.rootBackground)
        }
        .frame(minWidth: 960, minHeight: 640)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                newConversationButton
                groupLabel("Aktuel")
                activeConversationRow
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
        }
    }

    private func groupLabel(_ text: String) -> some View {
        Text(text)
            .font(.custom(UltronTheme.FontName.monoRegular, size: 9.5))
            .tracking(1.9).textCase(.uppercase)
            .foregroundStyle(UltronTheme.textFaint)
            .padding(.top, 18).padding(.bottom, 6)
    }

    private var newConversationButton: some View {
        Button {
            session.messages.removeAll()
            composerText = ""
            composerFocused = true
        } label: {
            HStack {
                Text("Ny samtale")
                    .font(.custom(UltronTheme.FontName.sansRegular, size: 13))
                    .foregroundStyle(UltronTheme.text)
                Spacer()
                Text("⌘N")
                    .font(.custom(UltronTheme.FontName.monoRegular, size: 10))
                    .foregroundStyle(UltronTheme.textFaint)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(UltronTheme.ink3)
                            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(UltronTheme.line, lineWidth: 1))
                    )
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(UltronTheme.ink2)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(UltronTheme.lineSoft, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    private var activeConversationRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(conversationTitle)
                .font(.custom(UltronTheme.FontName.serifRoman, size: 14).weight(.medium))
                .foregroundStyle(UltronTheme.text)
                .lineLimit(2)
            Text(conversationSummary)
                .font(.custom(UltronTheme.FontName.monoRegular, size: 10.5))
                .tracking(0.6).foregroundStyle(UltronTheme.textMute)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(UltronTheme.ink2)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(UltronTheme.lineSoft, lineWidth: 1))
        )
    }

    private var conversationSummary: String {
        let count = session.messages.count
        if count == 0 { return "Ingen beskeder endnu" }
        return "\(count) beskeder"
    }

    // MARK: - Main column

    private var mainColumn: some View {
        VStack(spacing: 0) { headerBar; messageStream; composer }
    }

    private var headerBar: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(conversationTitle)
                .font(UltronTheme.Typography.sectionH2())
                .foregroundStyle(UltronTheme.text)
            Spacer(minLength: 12)
            if session.isStreaming {
                HStack(spacing: 6) {
                    Circle().fill(UltronTheme.warn).frame(width: 6, height: 6)
                    Text("skriver")
                        .font(.custom(UltronTheme.FontName.monoRegular, size: 10))
                        .tracking(0.8).textCase(.uppercase)
                        .foregroundStyle(UltronTheme.warn)
                }
            }
            Text("Sonnet 4.7 · agent")
                .font(.custom(UltronTheme.FontName.monoRegular, size: 10.5))
                .foregroundStyle(UltronTheme.textMute)
        }
        .padding(.horizontal, 28).padding(.vertical, 18)
        .background(UltronTheme.ink)
        .overlay(alignment: .bottom) {
            Rectangle().fill(UltronTheme.lineSoft).frame(height: 1)
        }
    }

    private var messageStream: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if session.messages.isEmpty {
                        emptyState
                    } else {
                        ForEach(session.messages) { msg in
                            messageRow(msg).id(msg.id)
                        }
                    }
                }
                .frame(maxWidth: 880, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 28).padding(.top, 28).padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: session.messages.last?.id) { _, newID in
                guard let newID else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(newID, anchor: .bottom)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Hej.")
                .font(.custom(UltronTheme.FontName.serifRoman, size: 36).weight(.light))
                .foregroundStyle(UltronTheme.text)
            Text("Hvad skal vi lave?")
                .font(.custom(UltronTheme.FontName.serifItalic, size: 20))
                .foregroundStyle(UltronTheme.textDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }

    @ViewBuilder
    private func messageRow(_ msg: ChatMessage) -> some View {
        switch msg.role {
        case .user:      userMessage(msg)
        case .assistant: assistantMessage(msg)
        }
    }

    private func monoKicker(_ text: String) -> some View {
        Text(text)
            .font(.custom(UltronTheme.FontName.monoRegular, size: 9.5))
            .tracking(1.9).textCase(.uppercase)
            .foregroundStyle(UltronTheme.textMute)
    }

    private func userMessage(_ msg: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            monoKicker("Dig · \(Self.timeFormatter.string(from: msg.timestamp))")
            Text(msg.text)
                .font(.custom(UltronTheme.FontName.sansRegular, size: 14.5))
                .foregroundStyle(UltronTheme.text)
                .lineSpacing(3)
                .textSelection(.enabled)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(UltronTheme.ink2)
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(UltronTheme.lineSoft, lineWidth: 1))
                )
                .frame(maxWidth: 520, alignment: .leading)
        }
    }

    private func assistantMessage(_ msg: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                monoKicker("Ultron · \(Self.timeFormatter.string(from: msg.timestamp))")
                if msg.lastError != nil {
                    Text("fejl")
                        .font(.custom(UltronTheme.FontName.monoRegular, size: 9.5))
                        .tracking(0.5).textCase(.uppercase)
                        .foregroundStyle(UltronTheme.warn)
                        .padding(.horizontal, 7).padding(.vertical, 1)
                        .background(Capsule().fill(UltronTheme.warn.opacity(0.15))
                            .overlay(Capsule().stroke(UltronTheme.warn.opacity(0.55), lineWidth: 1)))
                }
            }
            Text(msg.text.isEmpty && session.isStreaming ? "…" : msg.text)
                .font(.custom(UltronTheme.FontName.serifRoman, size: 16))
                .foregroundStyle(UltronTheme.text)
                .lineSpacing(4)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(spacing: 0) {
            Rectangle().fill(UltronTheme.lineSoft).frame(height: 1)
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topLeading) {
                    if composerText.isEmpty {
                        Text("Svar, eller tryk ⌥ Retur for at diktere…")
                            .font(.custom(UltronTheme.FontName.sansRegular, size: 14.5))
                            .foregroundStyle(UltronTheme.textFaint)
                            .padding(.vertical, 2).allowsHitTesting(false)
                    }
                    TextField("", text: $composerText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.custom(UltronTheme.FontName.sansRegular, size: 14.5))
                        .foregroundStyle(UltronTheme.text)
                        .lineLimit(2...6)
                        .focused($composerFocused)
                        .onSubmit(submit)
                }
                .frame(minHeight: 40, alignment: .topLeading)

                HStack(spacing: 10) {
                    Spacer(minLength: 8)
                    sendButton
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: UltronTheme.Radius.composer, style: .continuous)
                    .fill(UltronTheme.ink2)
                    .overlay(RoundedRectangle(cornerRadius: UltronTheme.Radius.composer, style: .continuous)
                        .stroke(UltronTheme.lineSoft, lineWidth: 1))
            )
            .frame(maxWidth: 880)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 28).padding(.top, 14).padding(.bottom, 22)
        }
        .background(UltronTheme.ink)
    }

    private var sendButton: some View {
        Button(action: submit) {
            Text("Send ⌘⏎")
                .font(UltronTheme.Typography.bodySemibold(size: 13))
                .foregroundStyle(UltronTheme.ink)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(Capsule().fill(canSend ? UltronTheme.paper : UltronTheme.paper.opacity(0.4)))
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .keyboardShortcut(.return, modifiers: .command)
    }

    private var canSend: Bool {
        !composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !session.isStreaming
    }

    private func submit() {
        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !session.isStreaming else { return }
        composerText = ""
        onSend(trimmed)
    }

    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df
    }()
}

#Preview("Ultron Chat — empty") {
    UltronChatView(session: nil, onSend: { _ in })
        .frame(width: 1200, height: 780)
}
