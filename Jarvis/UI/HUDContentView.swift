import SwiftUI

struct HUDContentView: View {
    let state: HUDState
    let onClose: () -> Void
    var onSpeak: ((String) -> Void)?
    var onPermissionAction: (() -> Void)?
    var chatSession: ChatSession?
    var onChatSend: ((String) -> Void)?
    var onChatVoice: (() -> Void)?
    var onPin: (() -> Void)?

    @State private var appeared = false
    @State private var waveformPhases: [Bool] = Array(repeating: false, count: Constants.Animation.waveformBarCount)

    var body: some View {
        VStack(spacing: 0) {
            phaseContent
        }
        .padding(Constants.HUD.padding)
        .frame(width: Constants.HUD.width)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Constants.HUD.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Constants.HUD.cornerRadius, style: .continuous)
                .stroke(.white.opacity(Constants.HUD.borderOpacity), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: Constants.HUD.outerShadowRadius, y: Constants.HUD.outerShadowY)
        .shadow(color: .black.opacity(0.1), radius: Constants.HUD.innerShadowRadius, y: Constants.HUD.innerShadowY)
        .scaleEffect(appeared ? 1 : Constants.Animation.appearScaleFrom)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : Constants.Animation.appearOffsetFrom)
        .onAppear {
            withAnimation(.spring(duration: Constants.Animation.appearDuration, bounce: Constants.Animation.appearBounce)) {
                appeared = true
            }
        }
    }

    // MARK: - Phase Content

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
        }
    }

    // MARK: - Recording

    private func recordingView(elapsed: TimeInterval) -> some View {
        VStack(spacing: 12) {
            HStack {
                headerIcon("waveform.circle.fill", color: .red)
                Text("Optager...").font(.headline)
                Spacer()
                Text(formatTime(elapsed))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                ForEach(0..<Constants.Animation.waveformBarCount, id: \.self) { index in
                    WaveformBar(isAnimating: waveformPhases[index])
                        .onAppear {
                            let delay = Double(index) * 0.1
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                waveformPhases[index] = true
                            }
                        }
                }
            }
            .frame(height: Constants.Animation.waveformBarMaxHeight)

            // Countdown ring
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: min(elapsed / Constants.maxRecordingDuration, 1.0))
                    .stroke(.red, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: elapsed)
            }
            .frame(width: 32, height: 32)
        }
    }

    // MARK: - Processing

    private var processingView: some View {
        VStack(spacing: 12) {
            HStack {
                headerIcon("gear.circle.fill", color: .orange)
                Text("Behandler...").font(.headline)
                Spacer()
            }
            ProgressView()
                .controlSize(.regular)
                .padding(.vertical, 8)
        }
    }

    // MARK: - Result

    private func resultView(text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                headerIcon("waveform.circle.fill", color: .accentColor)
                Text("Jarvis").font(.headline)
                Spacer()
                Button(action: { onPin?() }) {
                    Image(systemName: state.isPinned ? "pin.fill" : "pin")
                        .foregroundStyle(state.isPinned ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.borderless)
                .help(state.isPinned ? "Unpin" : "Pin")
                Button(action: { onSpeak?(text) }) {
                    Image(systemName: "speaker.wave.2.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Læs op")
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            Divider()
            ScrollView {
                MarkdownTextView(text)
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
                .foregroundStyle(.green)
            Text(message)
                .font(.body)
            Spacer()
        }
    }

    // MARK: - Error

    private func errorView(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                Text("Fejl").font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Permission Error

    private func permissionErrorView(permission: String, instructions: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("\(permission) kræves").font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            Text(instructions)
                .font(.callout)
                .foregroundStyle(.secondary)
            if let action = onPermissionAction {
                Button("Åbn Indstillinger") { action() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
    }

    // MARK: - Helpers

    private func headerIcon(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .foregroundStyle(color)
            .font(.title3)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let seconds = Int(time)
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Waveform Bar

private struct WaveformBar: View {
    let isAnimating: Bool
    @State private var height: CGFloat = 4

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(.red)
            .frame(width: Constants.Animation.waveformBarWidth, height: height)
            .onAppear {
                guard isAnimating else { return }
                withAnimation(
                    .easeInOut(duration: Constants.Animation.waveformAnimationDuration)
                    .repeatForever(autoreverses: true)
                    .delay(Double.random(in: 0...0.2))
                ) {
                    height = CGFloat.random(in: 8...Constants.Animation.waveformBarMaxHeight)
                }
            }
    }
}
