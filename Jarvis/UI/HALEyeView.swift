import SwiftUI

/// HAL 9000 lens — the recording/processing indicator for v5.0.0-alpha.4 onward.
///
/// Three concentric rings: an outer brass bezel, an inner black aperture, and a
/// glowing red iris that breathes (idle) or pulses sharply with voice RMS.
/// Around the bezel sits a **radial waveform ring** of 32 bars that extends out
/// from the lens with the user's voice — much more prominent than the old 24-bar
/// arc-reactor ring.
struct HALEyeView: View {
    /// 0...1 fraction of `Constants.maxRecordingDuration` elapsed. Drives the
    /// subtle brass-ring trim arc around the outside.
    var progress: Double = 0
    /// Outer diameter of the whole assembly.
    var size: CGFloat = 110
    /// Audio level observable. nil = idle breath animation.
    var levelMonitor: AudioLevelMonitor? = nil

    @State private var idlePulse: Bool = false
    @State private var rotation: Double = 0

    private let barCount = 32

    /// Quantised level so SwiftUI doesn't rerun the implicit animation on every
    /// raw sample; 25 buckets matches the ~22 Hz audio tap update rate.
    private var intensity: Double {
        if let monitor = levelMonitor {
            return (monitor.level * 25).rounded() / 25
        }
        return idlePulse ? 0.7 : 0.0
    }

    var body: some View {
        ZStack {
            radialWaveform
            progressArc
            brassBezel
            blackAperture
            redIris
            coreFlare
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                idlePulse = true
            }
            withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }

    // MARK: - Layers (outer → inner)

    /// Radial waveform bars. 32 capsules emanating outward from the eye, each
    /// reacting to voice with a per-bar phase offset so the ring "breathes" in
    /// a wave motion instead of lockstep.
    private var radialWaveform: some View {
        let baseRadius = size * 0.48
        let maxBarLength = size * 0.26  // big — voice pushes bars well past the bezel

        return ZStack {
            ForEach(0..<barCount, id: \.self) { i in
                let phase = Double(i) / Double(barCount)
                let variation = 0.45 + 0.55 * (0.5 + 0.5 * sin((phase * .pi * 6) + (rotation * .pi / 180)))
                let barLength = maxBarLength * CGFloat(max(0.12, intensity * variation))
                HALWaveBar(length: barLength, intensity: intensity)
                    .offset(y: -(baseRadius + barLength / 2))
                    .rotationEffect(.degrees(Double(i) / Double(barCount) * 360))
                    .animation(.easeOut(duration: 0.1), value: intensity)
            }
        }
    }

    /// Brass circle arc that slowly fills as recording approaches max-duration.
    private var progressArc: some View {
        Circle()
            .trim(from: 0, to: max(0, min(progress, 1)))
            .stroke(
                LinearGradient(
                    colors: [JarvisTheme.halBrass, JarvisTheme.halRed],
                    startPoint: .top, endPoint: .bottom
                ),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
            .frame(width: size * 0.85, height: size * 0.85)
            .rotationEffect(.degrees(-90))
            .animation(.linear(duration: 0.4), value: progress)
    }

    /// Brass bezel — the thick brass ring that forms HAL's face plate.
    private var brassBezel: some View {
        Circle()
            .strokeBorder(
                AngularGradient(
                    colors: [
                        JarvisTheme.halBrass,
                        JarvisTheme.halBrass.opacity(0.6),
                        Color(red: 0.6, green: 0.45, blue: 0.2),
                        JarvisTheme.halBrass.opacity(0.9),
                        JarvisTheme.halBrass
                    ],
                    center: .center
                ),
                lineWidth: size * 0.055
            )
            .frame(width: size * 0.68, height: size * 0.68)
            .rotationEffect(.degrees(rotation * 0.1))   // very slow metallic shimmer
            .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
    }

    /// Pitch-black aperture inside the bezel — the "pupil" that the red iris sits in.
    private var blackAperture: some View {
        Circle()
            .fill(Color.black)
            .frame(width: size * 0.52, height: size * 0.52)
            .overlay(
                // Subtle inner shadow ring — suggests depth
                Circle()
                    .strokeBorder(Color.white.opacity(0.04), lineWidth: 0.75)
            )
    }

    /// The red iris — this is what pulses with voice. A radial gradient from
    /// bright white-hot core out to saturated red and fading to black.
    private var redIris: some View {
        let irisSize = size * (0.28 + CGFloat(intensity) * 0.16)
        let primaryGlow = 4 + CGFloat(intensity) * 14
        let secondaryGlow = 2 + CGFloat(intensity) * 6
        return Circle()
            .fill(JarvisTheme.coreGradient)
            .frame(width: irisSize, height: irisSize)
            .shadow(color: JarvisTheme.halRed.opacity(0.85), radius: primaryGlow)
            .shadow(color: JarvisTheme.halFlare.opacity(0.6), radius: secondaryGlow)
            .animation(.easeOut(duration: 0.08), value: intensity)
    }

    /// Tiny white-hot point dead-centre. Gives the iris a sense of depth and
    /// matches the chromatic "hot spot" in HAL's reference stills.
    private var coreFlare: some View {
        Circle()
            .fill(RadialGradient(
                colors: [Color.white.opacity(0.95), JarvisTheme.halFlare.opacity(0.0)],
                center: .center, startRadius: 0, endRadius: size * 0.08
            ))
            .frame(width: size * 0.18, height: size * 0.18)
            .scaleEffect(0.85 + intensity * 0.5)
            .animation(.easeOut(duration: 0.08), value: intensity)
    }
}

private struct HALWaveBar: View {
    let length: CGFloat
    let intensity: Double

    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [JarvisTheme.halFlare, JarvisTheme.halRed.opacity(0.3)],
                    startPoint: .bottom, endPoint: .top
                )
            )
            .frame(width: 2.5, height: max(3, length))
            .shadow(color: JarvisTheme.halRed.opacity(0.55 + intensity * 0.4), radius: 3)
    }
}
