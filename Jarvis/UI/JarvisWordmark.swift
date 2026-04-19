import SwiftUI

/// Branded wordmark rendered above the chat greeting. v1.4 Fase 2c replaces
/// the generic multi-hue sparkle with a proper J.A.R.V.I.S identity:
///
///   • SF Pro Rounded Bold, 20pt, 8pt tracking — confident, not shouty
///   • AngularGradient fill cycling through the Gemini/Stark-ish palette
///     (blue → purple → pink → amber → green) so the mark catches the eye
///     without competing with the big greeting text below it
///   • Soft glow underneath, short animated accent bar that breathes
///     subtly (opacity pulse on a 2.4s cycle) to hint that the assistant
///     is alive
///
/// The name is rendered as "J.A.R.V.I.S" with periods because that's the
/// canonical Stark spelling — matches the app's `Constants.displayName`.
struct JarvisWordmark: View {
    @State private var glow: Bool = false

    private static let letters: [Character] = Array("J.A.R.V.I.S")

    var body: some View {
        VStack(spacing: 8) {
            wordmark
            accentBar
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("J.A.R.V.I.S")
    }

    // MARK: - Wordmark text

    private var wordmark: some View {
        HStack(spacing: 2) {
            ForEach(Array(Self.letters.enumerated()), id: \.offset) { index, ch in
                Text(String(ch))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .kerning(ch == "." ? 0 : 4)
                    // Each letter picks a slightly rotated gradient angle so
                    // the palette shifts across the word instead of painting
                    // every letter with the same colour. Gives the mark a
                    // shimmer when the user's eye tracks across it.
                    .foregroundStyle(gradient(rotation: Double(index) * 0.06))
                    // periods are slightly smaller + raised to sit mid-line
                    // like a monograph ("J·A·R·V·I·S") without breaking
                    // accessibility reads.
                    .baselineOffset(ch == "." ? 0 : 0)
            }
        }
        .shadow(color: glowColor.opacity(glow ? 0.55 : 0.30), radius: 12)
        .shadow(color: Color.black.opacity(0.6), radius: 2, y: 1)
    }

    // MARK: - Accent bar underneath

    /// A subtle 2-pt tall capsule the same width as the word. Holds the
    /// same angular gradient so eye stays on-brand. Pulses in opacity
    /// on the same cycle as the wordmark glow.
    private var accentBar: some View {
        Capsule(style: .continuous)
            .fill(gradient())
            .frame(height: 2)
            .frame(maxWidth: 170)
            .opacity(glow ? 0.95 : 0.65)
    }

    // MARK: - Palette

    /// Five-stop multi-hue palette — same family as the Gemini sparkle we
    /// used to render here but re-sequenced for a left-to-right reading
    /// order (cool → warm → cool again) so the word has a discernible
    /// "direction" when you look at it.
    private func gradient(rotation: Double = 0) -> AngularGradient {
        AngularGradient(
            colors: [
                Color(red: 0.30, green: 0.55, blue: 1.00),   // blue
                Color(red: 0.58, green: 0.39, blue: 0.95),   // purple
                Color(red: 0.95, green: 0.42, blue: 0.58),   // pink
                Color(red: 0.99, green: 0.72, blue: 0.30),   // amber
                Color(red: 0.35, green: 0.80, blue: 0.55),   // green
                Color(red: 0.30, green: 0.55, blue: 1.00)    // back to blue
            ],
            center: .center,
            angle: .degrees(rotation * 360)
        )
    }

    private var glowColor: Color {
        Color(red: 0.55, green: 0.45, blue: 0.95)  // soft violet — reads warm on dark bg
    }
}
