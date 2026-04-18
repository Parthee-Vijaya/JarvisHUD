import SwiftUI

/// HAL 9000 / 2001: A Space Odyssey palette. v5.0.0-alpha.4 replaces the cyan
/// Iron Man theme with HAL's distinctive red-lens + brass aesthetic.
/// Legacy names (`neonCyan`, `brightCyan`, etc.) are preserved as aliases so
/// existing view code compiles without churn — they now map to the HAL equivalents.
enum JarvisTheme {
    // MARK: - Core HAL palette
    /// The iconic HAL lens glow. `#FF1744` — deep saturated red with enough
    /// luminance to read as "alive" on a dark background.
    static let halRed        = Color(red: 1.00, green: 0.09, blue: 0.27)
    /// Brighter flare red for active / peak states.
    static let halFlare      = Color(red: 1.00, green: 0.35, blue: 0.45)
    /// Deep crimson fade — used inside the lens aperture when it's "at rest".
    static let halDeep       = Color(red: 0.55, green: 0.00, blue: 0.05)
    /// Warm amber/brass for decorative rings, ala the brass trim around
    /// HAL's face plate.
    static let halBrass      = Color(red: 0.86, green: 0.65, blue: 0.28)
    /// Warning amber used in lieu of system yellow.
    static let halWarning    = Color(red: 1.00, green: 0.73, blue: 0.22)

    // MARK: - Surfaces
    /// Near-black base for the HUD interior. Darker than `.black` would be
    /// because macOS HUDs sit on top of translucency.
    static let surfaceBase   = Color(red: 0.027, green: 0.024, blue: 0.031)
    /// Slightly lighter surface for nested cards.
    static let surfaceElevated = Color(red: 0.059, green: 0.047, blue: 0.055)

    // MARK: - Legacy aliases (keep v4 view code compiling)
    static var neonCyan: Color     { halRed }
    static var brightCyan: Color   { halFlare }
    static var deepCyan: Color     { halDeep }
    static var criticalGlow: Color { halRed }
    static var warningGlow: Color  { halWarning }
    static var successGlow: Color  { halBrass }

    // MARK: - Gradients
    static let deepSpaceGradient = LinearGradient(
        colors: [surfaceBase, surfaceElevated],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Radial gradient for the HAL lens core: bright white-hot centre,
    /// ramping to saturated red, fading to black.
    static let coreGradient = RadialGradient(
        colors: [
            Color(red: 1.0, green: 0.85, blue: 0.80),
            halFlare,
            halRed,
            halDeep.opacity(0)
        ],
        center: .center,
        startRadius: 0,
        endRadius: 22
    )

    /// Brass border with a subtle inner red echo.
    static let borderGradient = LinearGradient(
        colors: [halBrass.opacity(0.65), halDeep.opacity(0.3)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Chat bubble
    static let userBubble = LinearGradient(
        colors: [halRed.opacity(0.85), halDeep.opacity(0.5)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Monospaced computer-terminal font helper

extension Font {
    /// The HAL-era computer-readout font. Used for countdown / mode label so the
    /// HUD reads like a 1960s control panel.
    static func halTerminal(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}
