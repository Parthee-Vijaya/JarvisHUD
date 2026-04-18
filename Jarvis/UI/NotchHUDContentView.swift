import SwiftUI

/// HUD content styled as a pill growing downward out of the MacBook notch.
///
/// Layout follows Apple's Dynamic-Island-inspired widget design language:
/// - **Flat top** edge tucked flush against the system notch bottom
/// - **Generously rounded bottom corners** (32 pt) so the pill reads as a shape
///   extension of the camera cutout, not a separate overlay
/// - **Two-column content**: visualisation on the left, information on the right,
///   separated by a hair-thin cyan divider
struct NotchHUDContentView: View {
    let state: HUDState
    let audioLevel: AudioLevelMonitor
    let waveform: WaveformBuffer
    let speechService: SpeechRecognitionService
    let activeModeName: String
    let onClose: () -> Void
    var onSpeak: ((String) -> Void)?
    var onPermissionAction: (() -> Void)?

    @State private var appeared = false

    var body: some View {
        HStack(spacing: 0) {
            visualColumn
                .frame(width: Constants.NotchHUD.visualColumnWidth)

            Rectangle()
                .fill(JarvisTheme.neonCyan.opacity(0.18))
                .frame(width: 0.5)
                .padding(.vertical, 16)

            contentColumn
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black)
        .clipShape(NotchPillShape(cornerRadius: Constants.NotchHUD.cornerRadius))
        .overlay(
            NotchPillShape(cornerRadius: Constants.NotchHUD.cornerRadius)
                .stroke(JarvisTheme.neonCyan.opacity(0.35), lineWidth: 0.75)
        )
        .shadow(color: JarvisTheme.neonCyan.opacity(0.25), radius: 18, y: 6)
        .shadow(color: .black.opacity(0.55), radius: 24, y: 10)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(y: appeared ? 1 : 0.82, anchor: .top)
        .onAppear {
            withAnimation(.spring(duration: 0.4, bounce: 0.3)) {
                appeared = true
            }
        }
    }

    // MARK: - LEFT COLUMN (visualisation)

    @ViewBuilder
    private var visualColumn: some View {
        switch state.currentPhase {
        case .recording, .processing:
            VStack(spacing: 8) {
                ArcReactorView(
                    progress: recordingProgress,
                    size: 58,
                    levelMonitor: isRecording ? audioLevel : nil
                )
                WaveformScope(buffer: waveform, height: 14)
                    .opacity(isRecording ? 1 : 0.3)
            }
            .frame(maxHeight: .infinity, alignment: .center)

        case .result:
            VStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(JarvisTheme.neonCyan)
                    .shadow(color: JarvisTheme.neonCyan.opacity(0.7), radius: 8)
            }
            .frame(maxHeight: .infinity, alignment: .center)

        case .confirmation:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(JarvisTheme.successGlow)
                .shadow(color: JarvisTheme.brightCyan.opacity(0.7), radius: 8)
                .frame(maxHeight: .infinity, alignment: .center)

        case .error, .permissionError:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 38))
                .foregroundStyle(JarvisTheme.criticalGlow)
                .shadow(color: JarvisTheme.criticalGlow.opacity(0.7), radius: 6)
                .frame(maxHeight: .infinity, alignment: .center)

        case .chat, .uptodate:
            EmptyView()
        }
    }

    // MARK: - RIGHT COLUMN (content)

    @ViewBuilder
    private var contentColumn: some View {
        switch state.currentPhase {
        case .recording(let elapsed):
            recordingContent(elapsed: elapsed)
        case .processing:
            processingContent
        case .result(let text):
            resultContent(text: text)
        case .confirmation(let message):
            confirmationContent(message: message)
        case .error(let message):
            errorContent(title: "Fejl", message: message)
        case .permissionError(let permission, let instructions):
            errorContent(title: "\(permission) kræves", message: instructions)
        case .chat, .uptodate:
            EmptyView()
        }
    }

    private func recordingContent(elapsed: TimeInterval) -> some View {
        let remaining = max(0, Constants.maxRecordingDuration - elapsed)
        return VStack(alignment: .leading, spacing: 6) {
            headerRow(
                title: activeModeName.isEmpty ? "Jarvis" : activeModeName,
                trailing: {
                    Text(formatTime(remaining))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(JarvisTheme.neonCyan.opacity(0.8))
                }
            )

            if !speechService.transcript.isEmpty {
                Text(speechService.transcript)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            } else {
                Text(audioLevel.isSilent ? "Slip for at sende" : "Lytter…")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(audioLevel.isSilent ? JarvisTheme.brightCyan : JarvisTheme.neonCyan.opacity(0.6))
            }

            Spacer(minLength: 0)
        }
        .animation(.easeInOut(duration: 0.2), value: audioLevel.isSilent)
        .animation(.easeInOut(duration: 0.2), value: speechService.transcript.isEmpty)
    }

    private var processingContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerRow(title: "Behandler…", trailing: {
                ProgressView().controlSize(.mini).tint(JarvisTheme.neonCyan)
            })
            if !speechService.transcript.isEmpty {
                Text(speechService.transcript)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(JarvisTheme.neonCyan.opacity(0.7))
                    .lineLimit(2)
            } else {
                Text("Jarvis tænker over det…")
                    .font(.caption)
                    .foregroundStyle(JarvisTheme.neonCyan.opacity(0.5))
            }
            Spacer(minLength: 0)
        }
    }

    private func resultContent(text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            headerRow(title: "Jarvis", trailing: {
                HStack(spacing: 8) {
                    Button { onSpeak?(text) } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(JarvisTheme.neonCyan.opacity(0.75))
                    }
                    .buttonStyle(.borderless)
                    .help("Læs op")
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(JarvisTheme.neonCyan.opacity(0.55))
                    }
                    .buttonStyle(.borderless)
                }
            })
            ScrollView {
                MarkdownTextView(text, foregroundColor: .white.opacity(0.95))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func confirmationContent(message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Færdig")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(JarvisTheme.brightCyan)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.85))
            Spacer(minLength: 0)
        }
    }

    private func errorContent(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            headerRow(title: title, titleColor: JarvisTheme.criticalGlow, trailing: {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(JarvisTheme.neonCyan.opacity(0.55))
                }
                .buttonStyle(.borderless)
            })
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(3)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Shared header row

    @ViewBuilder
    private func headerRow<Trailing: View>(
        title: String,
        titleColor: Color = JarvisTheme.brightCyan,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(titleColor)
            Spacer(minLength: 0)
            trailing()
        }
    }

    // MARK: - Helpers

    private var isRecording: Bool {
        if case .recording = state.currentPhase { return true }
        return false
    }

    private var recordingProgress: Double {
        if case .recording(let elapsed) = state.currentPhase {
            return min(elapsed / Constants.maxRecordingDuration, 1.0)
        }
        return 0
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let seconds = Int(time)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

/// Flat top, rounded bottom corners. Matches the visual language of the notch
/// (camera cutout has flat top + curved bottom) so the pill looks continuous.
struct NotchPillShape: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(cornerRadius, rect.height / 2, rect.width / 2)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - r, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - r),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.closeSubpath()
        return path
    }
}
