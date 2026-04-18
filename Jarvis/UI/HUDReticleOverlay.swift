import SwiftUI

/// Thin cyan L-brackets in each corner — subtle HUD decoration that makes the
/// glass feel like an instrument panel rather than a plain notification toast.
struct HUDReticleOverlay: View {
    var cornerRadius: CGFloat = Constants.HUD.cornerRadius
    var bracketLength: CGFloat = 12
    var inset: CGFloat = 8
    var lineWidth: CGFloat = 1

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            Path { path in
                // Top-left L
                path.move(to: CGPoint(x: inset, y: inset + bracketLength))
                path.addLine(to: CGPoint(x: inset, y: inset))
                path.addLine(to: CGPoint(x: inset + bracketLength, y: inset))

                // Top-right L
                path.move(to: CGPoint(x: w - inset - bracketLength, y: inset))
                path.addLine(to: CGPoint(x: w - inset, y: inset))
                path.addLine(to: CGPoint(x: w - inset, y: inset + bracketLength))

                // Bottom-left L
                path.move(to: CGPoint(x: inset, y: h - inset - bracketLength))
                path.addLine(to: CGPoint(x: inset, y: h - inset))
                path.addLine(to: CGPoint(x: inset + bracketLength, y: h - inset))

                // Bottom-right L
                path.move(to: CGPoint(x: w - inset - bracketLength, y: h - inset))
                path.addLine(to: CGPoint(x: w - inset, y: h - inset))
                path.addLine(to: CGPoint(x: w - inset, y: h - inset - bracketLength))
            }
            .stroke(JarvisTheme.brightCyan.opacity(0.55), lineWidth: lineWidth)
        }
        .allowsHitTesting(false)
    }
}
