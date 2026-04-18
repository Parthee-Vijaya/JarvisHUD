import SwiftUI

/// Iron Man–style HUD backdrop: deep-space gradient + cyan glow + cyan border + corner reticle.
/// Replaces the generic `.regularMaterial` used pre-v4.0.
struct JarvisHUDBackground: ViewModifier {
    var cornerRadius: CGFloat = Constants.HUD.cornerRadius
    var showReticle: Bool = true

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    JarvisTheme.deepSpaceGradient

                    // Subtle radial cyan bloom in the upper-left, evokes arc-reactor spill.
                    RadialGradient(
                        colors: [JarvisTheme.neonCyan.opacity(0.10), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 260
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(JarvisTheme.borderGradient, lineWidth: 1)
            }
            .overlay {
                if showReticle {
                    HUDReticleOverlay(cornerRadius: cornerRadius)
                }
            }
            .shadow(color: JarvisTheme.neonCyan.opacity(0.35), radius: 16, y: 0)
            .shadow(color: .black.opacity(0.55), radius: Constants.HUD.outerShadowRadius, y: Constants.HUD.outerShadowY)
    }
}

extension View {
    func jarvisHUDBackground(cornerRadius: CGFloat = Constants.HUD.cornerRadius, showReticle: Bool = true) -> some View {
        modifier(JarvisHUDBackground(cornerRadius: cornerRadius, showReticle: showReticle))
    }
}
