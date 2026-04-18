import SwiftUI

struct HUDContentView: View {
    let state: HUDState
    let audioLevel: AudioLevelMonitor
    let waveform: WaveformBuffer
    let speechService: SpeechRecognitionService
    let activeModeName: String
    let onClose: () -> Void
    var onSpeak: ((String) -> Void)?
    var onPermissionAction: (() -> Void)?
    var chatSession: ChatSession?
    var onChatSend: ((String) -> Void)?
    var onChatVoice: (() -> Void)?
    var onPin: (() -> Void)?

    @State private var appeared = false

    private var isChat: Bool {
        if case .chat = state.currentPhase { return true }
        return false
    }

    var body: some View {
        Group {
            if isChat {
                phaseContent
                    .frame(
                        minWidth: Constants.ChatHUD.minWidth,
                        maxWidth: .infinity,
                        minHeight: Constants.ChatHUD.minHeight,
                        maxHeight: .infinity
                    )
                    .jarvisHUDBackground(showReticle: false)
            } else {
                VStack(spacing: 0) {
                    phaseContent
                }
                .padding(Constants.HUD.padding)
                .frame(width: Constants.HUD.width)
                .jarvisHUDBackground()
            }
        }
        .scaleEffect(appeared ? 1 : Constants.Animation.appearScaleFrom)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : Constants.Animation.appearOffsetFrom)
        .onAppear {
            withAnimation(.spring(duration: Constants.Animation.appearDuration, bounce: Constants.Animation.appearBounce)) {
                appeared = true
            }
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch state.currentPhase {
        case .recording(let elapsed):
            recordingView(elapsed: elapsed)
        case .processing:
            processingView
        case .result(let text):
            resultView(text: text)
        case .confirmation(let message):
            confirmationView(message: message)
        case .error(let message):
            errorView(message: message)
        case .permissionError(let permission, let instructions):
            permissionErrorView(permission: permission, instructions: instructions)
        case .chat:
            if let chatSession, let onChatSend {
                ChatView(
                    chatSession: chatSession,
                    onSend: onChatSend,
                    onVoice: onChatVoice,
                    onClose: onClose,
                    onPin: { onPin?() },
                    isPinned: state.isPinned
                )
            }
        case .uptodate, .infoMode:
            // Uptodate + Info both get dedicated panels in HUDWindowController; this
            // switch case exists only for phase-switch completeness.
            EmptyView()
        }
    }

    // MARK: - Recording

    private func recordingView(elapsed: TimeInterval) -> some View {
        let remaining = max(0, Constants.maxRecordingDuration - elapsed)

        return VStack(spacing: 10) {
            // Top status row: mode badge + remaining countdown
            HStack(spacing: 8) {
                modeBadge
                Spacer()
                Label(formatTime(remaining), systemImage: "timer")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(JarvisTheme.neonCyan.opacity(0.85))
            }

            ArcReactorView(
                progress: min(elapsed / Constants.maxRecordingDuration, 1.0),
                size: 88,
                levelMonitor: audioLevel
            )
            .padding(.top, 2)

            // Live transcription — only shown once there's something to show so the
            // HUD doesn't display an empty placeholder line on every press.
            if !speechService.transcript.isEmpty {
                Text(speechService.transcript)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
            } else {
                Text("Lytter…")
                    .font(.callout)
                    .foregroundStyle(JarvisTheme.neonCyan.opacity(0.45))
            }

            // Silence hint — fades in/out when the mic has been quiet >2 s
            if audioLevel.isSilent {
                Label("Slip for at sende", systemImage: "hand.tap.fill")
                    .font(.caption)
                    .foregroundStyle(JarvisTheme.brightCyan)
                    .shadow(color: JarvisTheme.brightCyan.opacity(0.7), radius: 4)
                    .transition(.opacity.combined(with: .scale))
            }

            WaveformScope(buffer: waveform, height: 36)
                .padding(.horizontal, 2)
        }
        .animation(.easeInOut(duration: 0.25), value: audioLevel.isSilent)
        .animation(.easeInOut(duration: 0.2), value: speechService.transcript.isEmpty)
    }

    private var modeBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "waveform")
                .font(.caption2)
            Text(activeModeName.isEmpty ? "Jarvis" : activeModeName)
                .font(.system(.caption, design: .rounded).weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background {
            Capsule()
                .fill(JarvisTheme.neonCyan.opacity(0.15))
                .overlay(Capsule().stroke(JarvisTheme.neonCyan.opacity(0.6), lineWidth: 0.75))
        }
        .foregroundStyle(JarvisTheme.brightCyan)
    }

    // MARK: - Processing

    private var processingView: some View {
        VStack(spacing: 14) {
            HStack {
                headerIcon("cpu", color: JarvisTheme.warningGlow)
                Text("Behandler...").font(.headline).foregroundStyle(JarvisTheme.brightCyan)
                Spacer()
            }
            ArcReactorView(progress: 0, size: 72, levelMonitor: nil)
                .padding(.vertical, 4)
            // Show the last transcription so the user can verify what was sent.
            if !speechService.transcript.isEmpty {
                Text("\u{201E}\(speechService.transcript)\u{201C}")
                    .font(.caption)
                    .foregroundStyle(JarvisTheme.neonCyan.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
    }

    // MARK: - Result

    private func resultView(text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                headerIcon("waveform.circle.fill", color: JarvisTheme.neonCyan)
                Text("Jarvis")
                    .font(.headline)
                    .foregroundStyle(JarvisTheme.brightCyan)
                Spacer()
                hudControlButton(system: state.isPinned ? "pin.fill" : "pin",
                                 tint: state.isPinned ? JarvisTheme.neonCyan : JarvisTheme.neonCyan.opacity(0.55),
                                 help: state.isPinned ? "Unpin" : "Pin") { onPin?() }
                hudControlButton(system: "speaker.wave.2.fill",
                                 tint: JarvisTheme.neonCyan.opacity(0.7),
                                 help: "Læs op") { onSpeak?(text) }
                hudControlButton(system: "xmark.circle.fill",
                                 tint: JarvisTheme.neonCyan.opacity(0.55),
                                 help: "Luk", action: onClose)
            }
            Rectangle()
                .fill(JarvisTheme.neonCyan.opacity(0.25))
                .frame(height: 1)
            ScrollView {
                MarkdownTextView(text, foregroundColor: .white.opacity(0.95))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
        }
    }

    // MARK: - Confirmation

    private func confirmationView(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(JarvisTheme.successGlow)
                .shadow(color: JarvisTheme.brightCyan.opacity(0.6), radius: 4)
            Text(message)
                .font(.body)
                .foregroundStyle(.white.opacity(0.95))
            Spacer()
        }
    }

    // MARK: - Error

    private func errorView(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(JarvisTheme.criticalGlow)
                    .shadow(color: JarvisTheme.criticalGlow.opacity(0.5), radius: 4)
                Text("Fejl").font(.headline).foregroundStyle(JarvisTheme.criticalGlow)
                Spacer()
                hudControlButton(system: "xmark.circle.fill",
                                 tint: JarvisTheme.neonCyan.opacity(0.5),
                                 help: "Luk", action: onClose)
            }
            Text(message)
                .font(.body)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    // MARK: - Permission Error

    private func permissionErrorView(permission: String, instructions: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .font(.title2)
                    .foregroundStyle(JarvisTheme.warningGlow)
                    .shadow(color: JarvisTheme.warningGlow.opacity(0.5), radius: 4)
                Text("\(permission) kræves").font(.headline).foregroundStyle(JarvisTheme.brightCyan)
                Spacer()
                hudControlButton(system: "xmark.circle.fill",
                                 tint: JarvisTheme.neonCyan.opacity(0.5),
                                 help: "Luk", action: onClose)
            }
            Text(instructions)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.8))
            if let action = onPermissionAction {
                Button("Åbn Indstillinger") { action() }
                    .buttonStyle(.borderedProminent)
                    .tint(JarvisTheme.neonCyan)
                    .controlSize(.small)
            }
        }
    }

    // MARK: - Helpers

    private func headerIcon(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .foregroundStyle(color)
            .font(.title3)
            .shadow(color: color.opacity(0.6), radius: 3)
    }

    private func hudControlButton(system: String, tint: Color, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system).foregroundStyle(tint)
        }
        .buttonStyle(.borderless)
        .help(help)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let seconds = Int(time)
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
