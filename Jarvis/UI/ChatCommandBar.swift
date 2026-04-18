import SwiftUI

/// Spotlight-inspired command bar for the chat window (β.11+).
///
/// Hosts the Jarvis sparkle, a text field, a mode picker (acts as "New Chat ▾"),
/// and an adaptive send button. Replaces the old ChatView header + input bar.
/// Unifies mode launching: pick any mode, type a prompt, hit send — the router
/// dispatches to the correct pipeline and results render as chat bubbles.
struct ChatCommandBar: View {
    let chatSession: ChatSession
    @Binding var selectedMode: Mode
    let availableModes: [Mode]
    /// Maps a mode to its keyboard shortcut display string (⌥⇧A, ⌥Q, …).
    /// Called when the mode picker is rendered so each row shows its shortcut.
    let shortcutLookup: (Mode) -> String?

    let onSubmit: (String) -> Void
    let onNewChat: () -> Void
    let onClose: () -> Void
    let onPin: () -> Void
    let isPinned: Bool
    /// Recording state for `.voice` modes — controls the mic button visuals.
    /// Nil when the selected mode isn't `.voice`.
    let isRecording: Bool
    let onToggleRecord: (() -> Void)?

    @State private var commandText: String = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkle")
                .font(.system(size: 16))
                .foregroundStyle(JarvisTheme.accent)
                .shadow(color: JarvisTheme.accent.opacity(0.4), radius: 5)

            TextField(placeholder, text: $commandText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(JarvisTheme.textPrimary)
                .focused($inputFocused)
                .lineLimit(1...4)
                .onSubmit(performSubmit)
                .disabled(selectedMode.inputKind == .voice)

            Spacer(minLength: 8)

            modePicker
            sendButton

            Divider()
                .frame(height: 18)
                .background(JarvisTheme.hairline)

            headerIconButton(system: isPinned ? "pin.fill" : "pin",
                             active: isPinned, help: isPinned ? "Unpin" : "Pin",
                             action: onPin)
            headerIconButton(system: "xmark", help: "Luk", action: onClose)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .onAppear {
            DispatchQueue.main.async { inputFocused = true }
        }
    }

    // MARK: - Placeholder per mode

    private var placeholder: String {
        switch selectedMode.inputKind {
        case .voice:
            return isRecording ? "Optager… tryk stop for at transskribere" : "Valgt — tryk mic for at optage"
        case .screenshot:
            return "Beskriv hvad du vil vide om skærmen…"
        case .document:
            return "Tryk Beregn for at vælge et dokument"
        case .text:
            switch selectedMode.name {
            case "Q&A":        return "Stil et spørgsmål…"
            case "Translate":  return "Tekst at oversætte…"
            case "Agent":      return "Bed Jarvis gøre noget…"
            case "Chat":       return "Hvad kan jeg hjælpe med i dag?"
            case "VibeCode":   return "Beskriv funktionen du vil bygge…"
            case "Professional": return "Tekst at omskrive professionelt…"
            default:           return "Hvad kan jeg hjælpe med?"
            }
        }
    }

    // MARK: - Mode picker

    private var modePicker: some View {
        Menu {
            Button {
                commandText = ""
                chatSession.clear()
                onNewChat()
            } label: {
                Label("Ny samtale", systemImage: "plus.circle")
            }

            Divider()

            ForEach(availableModes, id: \.id) { mode in
                Button {
                    selectedMode = mode
                    if mode.inputKind == .voice, let onToggleRecord {
                        onToggleRecord()  // auto-start mic on selection
                    }
                    if mode.inputKind == .document {
                        performSubmit()   // instantly open file picker
                    }
                    inputFocused = true
                } label: {
                    HStack {
                        Label(mode.name, systemImage: mode.icon)
                        if let shortcut = shortcutLookup(mode) {
                            Spacer()
                            Text(shortcut)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(JarvisTheme.textMuted)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: selectedMode.icon)
                    .font(.system(size: 11))
                Text(selectedMode.name)
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundStyle(JarvisTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(JarvisTheme.surfaceElevated)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    // MARK: - Send button (adapts to inputKind)

    @ViewBuilder
    private var sendButton: some View {
        switch selectedMode.inputKind {
        case .voice:
            Button(action: { onToggleRecord?() }) {
                Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(isRecording ? JarvisTheme.criticalGlow : JarvisTheme.accent)
            }
            .buttonStyle(.plain)
            .help(isRecording ? "Stop optagelse" : "Start optagelse")

        case .document:
            Button(action: performSubmit) {
                Image(systemName: "arrow.up.doc.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(JarvisTheme.accent)
            }
            .buttonStyle(.plain)
            .help("Vælg dokument")

        case .screenshot:
            Button(action: performSubmit) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 24))
                    .foregroundStyle(canSubmit ? JarvisTheme.accent : JarvisTheme.textMuted)
            }
            .buttonStyle(.plain)
            .disabled(chatSession.isStreaming)
            .help("Tag skærmbillede og spørg")

        case .text:
            Button(action: performSubmit) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(canSubmit ? JarvisTheme.accent : JarvisTheme.textMuted)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
            .keyboardShortcut(.return, modifiers: [])
            .help("Send")
        }
    }

    private var canSubmit: Bool {
        !commandText.trimmingCharacters(in: .whitespaces).isEmpty && !chatSession.isStreaming
    }

    private func performSubmit() {
        let text = commandText.trimmingCharacters(in: .whitespaces)
        // Screenshot + document modes allow empty text
        if selectedMode.inputKind == .text, text.isEmpty { return }
        commandText = ""
        onSubmit(text)
    }

    // MARK: - Icon buttons

    private func headerIconButton(system: String, active: Bool = false, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(active ? JarvisTheme.accent : JarvisTheme.textSecondary)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(JarvisTheme.surfaceElevated)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
