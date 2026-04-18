import SwiftUI

/// Iron Man / arc-reactor palette. Centralises every colour used in the HUD so the
/// aesthetic can be tuned from one file. Prefer these tokens over inline `.red`/`.orange`/etc.
enum JarvisTheme {
    // MARK: - Primary palette
    static let neonCyan       = Color(red: 0.255, green: 0.941, blue: 0.984)  // #41F0FB
    static let brightCyan     = Color(red: 0.494, green: 0.976, blue: 1.0)    // #7EF9FF — highlights
    static let deepCyan       = Color(red: 0.145, green: 0.588, blue: 0.647)  // #2596A5 — muted accents

    // MARK: - Surfaces
    static let surfaceBase    = Color(red: 0.027, green: 0.055, blue: 0.086)  // #070E16 — HUD background start
    static let surfaceElevated = Color(red: 0.055, green: 0.102, blue: 0.157) // #0E1A28 — HUD background end

    // MARK: - Semantic (still themed)
    /// Cyan-shifted error tone — avoids the generic system red on the HUD.
    static let criticalGlow   = Color(red: 1.0, green: 0.357, blue: 0.451)    // #FF5B73
    /// Warm amber for processing/confirmation — reads clearly against dark cyan.
    static let warningGlow    = Color(red: 1.0, green: 0.749, blue: 0.341)    // #FFBF57
    /// Matches the arc-reactor core for success/confirmation.
    static let successGlow    = brightCyan

    // MARK: - Gradients
    static let deepSpaceGradient = LinearGradient(
        colors: [surfaceBase, surfaceElevated],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let coreGradient = RadialGradient(
        colors: [brightCyan, neonCyan, neonCyan.opacity(0.0)],
        center: .center,
        startRadius: 0,
        endRadius: 18
    )

    static let borderGradient = LinearGradient(
        colors: [neonCyan.opacity(0.65), deepCyan.opacity(0.3)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - User message bubble (chat)
    static let userBubble = LinearGradient(
        colors: [deepCyan.opacity(0.85), neonCyan.opacity(0.5)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
