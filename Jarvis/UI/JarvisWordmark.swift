import SwiftUI

/// Branded wordmark rendered above the chat greeting — the classic Stark
/// "circle with text cutting through" identity. v1.4 Fase 2c iteration:
/// two arc segments with gaps on the left and right sides, and the
/// wordmark centred so the text visually interrupts the ring.
///
/// Everything is pure SwiftUI + the system SF Compact font (best available
/// built-in match for the sci-fi-tech feel of the source design; a custom
/// Orbitron / Michroma face could come later if we want a closer match).
struct JarvisWordmark: View {
    /// Diameter of the ring. 150pt reads comfortably in the chat empty-
    /// state column without crowding the greeting directly below.
    var diameter: CGFloat = 150

    var body: some View {
        ZStack {
            ring
            Text("J.A.R.V.I.S")
                .font(.system(size: 22, weight: .semibold, design: .default).width(.standard))
                .kerning(3)
                .foregroundStyle(Color.white)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("J.A.R.V.I.S")
    }

    // MARK: - Two-arc ring

    /// Top + bottom arcs with symmetric gaps at 9 o'clock and 3 o'clock. In
    /// SwiftUI's Y-down coordinate space, 0° = right, 90° = bottom,
    /// 180° = left, 270° = top; `clockwise: true` traverses in the same
    /// direction the eye reads (right → bottom → left → top).
    ///
    /// The 40°-wide gaps on each side visually land where the text row
    /// enters and exits the ring, matching the Stark logo pattern.
    private var ring: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 1
            let gap: CGFloat = 40  // half-width of each opening in degrees

            // Top arc: passes through 270° (12 o'clock). Goes from 200° over
            // the top to 340°.
            var top = Path()
            top.addArc(center: center, radius: radius,
                       startAngle: .degrees(180 + gap / 2),
                       endAngle: .degrees(360 - gap / 2),
                       clockwise: true)

            // Bottom arc: mirror, passes through 90° (6 o'clock).
            var bottom = Path()
            bottom.addArc(center: center, radius: radius,
                          startAngle: .degrees(0 + gap / 2),
                          endAngle: .degrees(180 - gap / 2),
                          clockwise: true)

            context.stroke(top, with: .color(.white), lineWidth: 1.2)
            context.stroke(bottom, with: .color(.white), lineWidth: 1.2)
        }
    }
}
