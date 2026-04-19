import SwiftUI

/// HUD backdrop — v1.4 Fase 2c glass-refined direction.
///
/// Layer stack:
///   1. surfaceBase (dynamic light/dark base colour for contrast fallback)
///   2. .regularMaterial (macOS vibrancy — gives the HUD its "glass" feel)
///   3. Rounded clip + hairline stroke (0.5pt — just enough to separate from
///      the desktop without looking drawn)
///   4. Native drop shadow (system shadow-style matches Apple first-party
///      floating panels like Spotlight and the Now Playing widget)
///
/// v1.3 and earlier used `JarvisTheme.surfaceBase` flat + a custom 20pt/8y
/// shadow with 0.45 alpha — that read as heavy on the light-mode variant and
/// didn't blend with the user's wallpaper. Materials + native drop shadow
/// fixes both.
struct JarvisHUDBackground: ViewModifier {
    var cornerRadius: CGFloat = Constants.HUD.cornerRadius
    /// Retained for API compatibility — reticle corners are gone in α.5.
    var showReticle: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                // Material needs an opaque-ish base below it or the HUD reads
                // too transparent on a busy desktop. 0.6 opacity gives enough
                // substance while still letting vibrancy breathe.
                JarvisTheme.surfaceBase.opacity(0.6),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(JarvisTheme.hairline, lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 18, y: 6)
    }
}

extension View {
    func jarvisHUDBackground(cornerRadius: CGFloat = Constants.HUD.cornerRadius, showReticle: Bool = false) -> some View {
        modifier(JarvisHUDBackground(cornerRadius: cornerRadius, showReticle: showReticle))
    }
}
