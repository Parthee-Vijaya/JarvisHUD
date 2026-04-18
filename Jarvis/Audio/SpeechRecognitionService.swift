import AVFoundation
import Foundation
import Observation
import Speech

/// On-device live transcription shown in the HUD while the user is talking.
/// This is *purely* for visual feedback — the authoritative transcription still comes
/// from Gemini via the WAV upload. If SFSpeechRecognizer is unavailable or permission
/// is denied, the service silently no-ops and the HUD just doesn't show the preview.
///
/// Privacy: `requiresOnDeviceRecognition = true` forces recognition to stay on the
/// Mac — no audio frames leave the machine for this preview.
@MainActor
@Observable
final class SpeechRecognitionService {
    /// Current rolling transcription. Updates as the user speaks; cleared on stop.
    var transcript: String = ""

    /// True once authorization is granted and on-device recognition is supported.
    private(set) var isAvailable: Bool = false

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?

    /// Ask for authorization at startup. Safe to call multiple times — SFSpeech caches.
    func requestAuthorization() async {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard status == .authorized else {
            LoggingService.shared.log("Speech recognition authorization: \(status.rawValue)", level: .info)
            isAvailable = false
            return
        }
        // Prefer the user's current locale; fall back to en-US. Danish + English are both
        // supported on-device on modern Macs.
        let locale = bestSupportedLocale()
        recognizer = SFSpeechRecognizer(locale: locale)
        isAvailable = recognizer?.isAvailable == true && recognizer?.supportsOnDeviceRecognition == true
        LoggingService.shared.log("Speech recognition ready (locale=\(locale.identifier), onDevice=\(isAvailable))")
    }

    /// Start listening. Safe to call with no authorization — just no-ops.
    func start() {
        guard isAvailable, let recognizer else { return }
        stop()  // defensive — clean slate

        transcript = ""

        let engine = AVAudioEngine()
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.requiresOnDeviceRecognition = true

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            req.append(buffer)
        }

        do {
            try engine.start()
        } catch {
            LoggingService.shared.log("Speech recognition engine failed: \(error)", level: .warning)
            inputNode.removeTap(onBus: 0)
            return
        }

        audioEngine = engine
        request = req

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if error != nil {
                    self.stop()
                }
            }
        }
    }

    /// Stop listening and free resources. Keeps the last transcript visible so the
    /// HUD can show it during the processing phase if it wants.
    func stop() {
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        audioEngine = nil
    }

    /// Clear the transcript (e.g. before a fresh recording).
    func reset() {
        transcript = ""
    }

    private func bestSupportedLocale() -> Locale {
        let preferred = Locale.current
        let supported = SFSpeechRecognizer.supportedLocales()
        if supported.contains(preferred) { return preferred }
        // Prefer Danish if available, then en_US.
        if let da = supported.first(where: { $0.identifier.hasPrefix("da") }) { return da }
        return Locale(identifier: "en_US")
    }
}
