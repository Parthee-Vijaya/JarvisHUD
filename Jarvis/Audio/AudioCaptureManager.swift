import AVFoundation

/// Records microphone audio to WAV. v5.0.0-alpha.4 onward this no longer owns
/// its own AVAudioEngine — it subscribes to `SharedAudioEngine` so the live
/// speech-recognition service and the WAV writer consume one microphone in one
/// tap, which cuts start-up latency and eliminates mic-contention glitches.
@MainActor
class AudioCaptureManager {
    private var audioData = Data()
    private var isRecording = false
    private var subscriberToken: UUID?
    private var bufferWarningLogged = false
    private static let bufferWarnThresholdBytes = 10 * 1_024 * 1_024  // 10 MB

    var onRecordingStarted: (() -> Void)?
    var onRecordingStopped: ((Data) -> Void)?

    /// Live audio-level sink, wired to the HUD's pulse indicator.
    weak var levelMonitor: AudioLevelMonitor?

    /// Rolling oscilloscope buffer, wired to the waveform strip in the HUD.
    weak var waveformBuffer: WaveformBuffer?

    func startRecording() throws {
        guard !isRecording else { return }
        let engine = SharedAudioEngine.shared
        try engine.start()

        guard let format = engine.inputFormat, format.sampleRate > 0 else {
            throw JarvisError.audioFormatInvalid
        }

        audioData = Data()
        bufferWarningLogged = false
        audioData.append(createWAVHeader(
            dataSize: 0,
            sampleRate: format.sampleRate,
            channels: UInt16(format.channelCount)
        ))

        // Subscribe — the closure runs on the audio render thread. Keep work light.
        subscriberToken = engine.addSubscriber { [weak self] buffer in
            self?.consume(buffer)
        }

        isRecording = true
        onRecordingStarted?()
        LoggingService.shared.log("Audio recording started (shared engine)")
    }

    func stopRecording() -> Data {
        guard isRecording else { return Data() }

        if let token = subscriberToken {
            SharedAudioEngine.shared.removeSubscriber(token)
            subscriberToken = nil
        }
        isRecording = false
        levelMonitor?.reset()
        waveformBuffer?.reset()

        let dataSize = UInt32(audioData.count - 44)
        updateWAVHeader(data: &audioData, dataSize: dataSize)

        let result = audioData
        audioData = Data()

        LoggingService.shared.log("Audio recording stopped (\(result.count) bytes)")
        onRecordingStopped?(result)
        return result
    }

    // MARK: - Buffer consumer (audio thread)

    nonisolated private func consume(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)

        var sumOfSquares: Float = 0
        var peak: Float = 0
        var pcm = Data(capacity: frameCount * 2)
        for i in 0..<frameCount {
            let raw = channelData[i]
            let sample = max(-1.0, min(1.0, raw))
            sumOfSquares += sample * sample
            if abs(sample) > abs(peak) { peak = sample }
            var intSample = Int16(sample * Float(Int16.max))
            pcm.append(Data(bytes: &intSample, count: 2))
        }

        let rms = frameCount > 0 ? sqrt(sumOfSquares / Float(frameCount)) : 0
        let boostedRMS = min(1.0, Double(rms) * 3.0)
        let oscPeak = max(-1.0, min(1.0, peak * 2.5))

        // Bounce the WAV append + metering to main actor for state-isolation safety.
        Task { @MainActor [weak self] in
            guard let self, self.isRecording else { return }
            self.audioData.append(pcm)
            self.levelMonitor?.submit(rms: boostedRMS)
            self.waveformBuffer?.push(peak: oscPeak)

            if !self.bufferWarningLogged && self.audioData.count > Self.bufferWarnThresholdBytes {
                self.bufferWarningLogged = true
                LoggingService.shared.log("Audio buffer exceeded \(Self.bufferWarnThresholdBytes / 1_048_576) MB — approaching max duration", level: .warning)
            }
        }
    }

    // MARK: - WAV header helpers

    private func createWAVHeader(dataSize: UInt32, sampleRate: Double, channels: UInt16) -> Data {
        var header = Data()
        let sr = UInt32(sampleRate)
        let bitsPerSample: UInt16 = 16
        let byteRate = sr * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)

        header.append(contentsOf: "RIFF".utf8)
        var chunkSize = UInt32(36 + dataSize)
        header.append(Data(bytes: &chunkSize, count: 4))
        header.append(contentsOf: "WAVE".utf8)

        header.append(contentsOf: "fmt ".utf8)
        var subchunk1Size: UInt32 = 16
        header.append(Data(bytes: &subchunk1Size, count: 4))
        var audioFormat: UInt16 = 1
        header.append(Data(bytes: &audioFormat, count: 2))
        var ch = channels
        header.append(Data(bytes: &ch, count: 2))
        var srVal = sr
        header.append(Data(bytes: &srVal, count: 4))
        var br = byteRate
        header.append(Data(bytes: &br, count: 4))
        var ba = blockAlign
        header.append(Data(bytes: &ba, count: 2))
        var bps = bitsPerSample
        header.append(Data(bytes: &bps, count: 2))

        header.append(contentsOf: "data".utf8)
        var ds = dataSize
        header.append(Data(bytes: &ds, count: 4))
        return header
    }

    private func updateWAVHeader(data: inout Data, dataSize: UInt32) {
        var chunkSize = UInt32(36 + dataSize)
        data.replaceSubrange(4..<8, with: Data(bytes: &chunkSize, count: 4))
        var ds = dataSize
        data.replaceSubrange(40..<44, with: Data(bytes: &ds, count: 4))
    }
}
