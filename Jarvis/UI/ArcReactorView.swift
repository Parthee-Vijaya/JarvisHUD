import SwiftUI

/// Iron Man arc-reactor recording indicator. The reactor itself pulses in real time with
/// the mic RMS from `AudioLevelMonitor`; a concentric ring of waveform bars around it
/// shows the actual voice activity so the user can see Jarvis is listening.
struct ArcReactorView: View {
    /// 0...1 fraction of `Constants.maxRecordingDuration` elapsed — drives the outer trim arc.
    var progress: Double = 0
    /// Outer diameter of the whole assembly.
    var size: CGFloat = 64
    /// Observable audio level, 0 = silence, 1 = clipping. When nil, falls back to a
    /// time-based idle pulse so processing/empty-state animations still look alive.
    var levelMonitor: AudioLevelMonitor? = nil

    @State private var idlePulse: Bool = false
    @State private var rotation: Double = 0

    private let barCount = 24

    /// The effective pulse intensity — real voice if we have a monitor, otherwise a slow idle breath.
    /// Raw level is quantised to 20 buckets (0.05 step) so SwiftUI doesn't rerun the implicit
    /// `.animation(...)` on every sample; with 24 bars that's the difference between ~480 and
    /// ~240 animation tasks/sec — visually identical, much cheaper on older Macs.
    private var intensity: Double {
        if let monitor = levelMonitor {
            return (monitor.level * 20).rounded() / 20
        }
        return idlePulse ? 1.0 : 0.0
    }

    var body: some View {
        ZStack {
            // Outer faint dashed ring — rotates slowly to hint at continuous listening.
            Circle()
                .stroke(
                    JarvisTheme.neonCyan.opacity(0.35),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(rotation))

            // Live waveform bars arranged around the reactor — reactive to voice.
            waveformRing

            // Progress arc — how close we are to max-duration cutoff.
            Circle()
                .trim(from: 0, to: max(0, min(progress, 1)))
                .stroke(
                    LinearGradient(
                        colors: [JarvisTheme.brightCyan, JarvisTheme.neonCyan],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .frame(width: size - 10, height: size - 10)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: progress)
                .shadow(color: JarvisTheme.neonCyan.opacity(0.7), radius: 4)

            // Mid pulse ring — intensity drives its expand/contract.
            Circle()
                .stroke(
                    JarvisTheme.neonCyan.opacity(0.25 + intensity * 0.6),
                    lineWidth: 1.5 + CGFloat(intensity) * 1.2
                )
                .frame(width: size - 24, height: size - 24)
                .scaleEffect(0.92 + intensity * 0.18)
                .animation(.easeOut(duration: 0.12), value: intensity)

            // Core — grows + glows with voice.
            Circle()
                .fill(JarvisTheme.coreGradient)
                .frame(width: size * 0.36, height: size * 0.36)
                .scaleEffect(0.85 + intensity * 0.4)
                .shadow(color: JarvisTheme.brightCyan.opacity(0.7 + intensity * 0.3),
                        radius: 4 + CGFloat(intensity) * 10)
                .animation(.easeOut(duration: 0.1), value: intensity)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                idlePulse = true
            }
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }

    // MARK: - Waveform ring

    /// 24 thin bars radiating outward from the reactor rim, each reacting to audio level
    /// with a small per-bar phase offset so the ring breathes like a real spectrum.
    private var waveformRing: some View {
        let baseRadius = size * 0.46
        let maxBarLength = size * 0.18

        return ZStack {
            ForEach(0..<barCount, id: \.self) { i in
                let phase = Double(i) / Double(barCount)
                // Slight sinusoidal variation so every bar doesn't move in perfect lockstep.
                let variation = 0.55 + 0.45 * sin((phase * .pi * 4) + (rotation * .pi / 180))
                let barLength = maxBarLength * CGFloat(max(0.15, intensity * variation))
                WaveformTick(length: barLength)
                    .offset(y: -(baseRadius + barLength / 2))
                    .rotationEffect(.degrees(Double(i) / Double(barCount) * 360))
                    .animation(.easeOut(duration: 0.08), value: intensity)
            }
        }
    }
}

private struct WaveformTick: View {
    let length: CGFloat

    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [JarvisTheme.brightCyan, JarvisTheme.neonCyan.opacity(0.2)],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: 2, height: max(2, length))
            .shadow(color: JarvisTheme.neonCyan.opacity(0.6), radius: 2)
    }
}
