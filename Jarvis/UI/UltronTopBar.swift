import Combine
import SwiftUI

/// Top navigation bar per the Ultron handoff. Sits above the tab
/// content — same height + visual weight across all three screens.
///
/// - Traffic lights (inert — this is a panel, not an NSWindow with
///   native titlebar; the dots are purely decorative per the design).
/// - Wordmark: "Ultron" serif + small circular glyph.
/// - Tab switcher: Cockpit / Stemme / Chat (keyboard 1/2/3).
/// - Live pill: accent dot + "Lytter · ⌥ Space" (status-aware).
/// - Time (mono, locale-aware).
/// - "? taster" keycap → opens hotkey cheat sheet overlay.
struct UltronTopBar: View {
    @Binding var activeTab: UltronTab
    var liveLabel: String = "Klar · ⌥ Space"
    var livePulsing: Bool = false
    var onHotkeySheet: () -> Void = {}

    @State private var now = Date()
    private let tick = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            trafficLights
            wordmark
            tabs
            Spacer(minLength: 12)
            livePill
            timeText
            hotkeyHint
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(
            UltronTheme.ink
                .overlay(
                    Rectangle()
                        .fill(UltronTheme.lineSoft)
                        .frame(height: 1)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                )
        )
        .onReceive(tick) { now = $0 }
    }

    // MARK: - Pieces

    private var trafficLights: some View {
        HStack(spacing: 8) {
            Circle().fill(Color(hex: 0x7FBBE6)).frame(width: 12, height: 12)
            Circle().fill(Color(hex: 0xE5C469)).frame(width: 12, height: 12)
            Circle().fill(Color(hex: 0x7FCBAE)).frame(width: 12, height: 12)
        }
    }

    private var wordmark: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            HStack(spacing: 7) {
                UltronGlyph()
                    .frame(width: 16, height: 16)
                Text("Ultron")
                    .font(.custom(UltronTheme.FontName.serifRoman, size: 20).weight(.medium))
                    .tracking(-0.2)
                    .foregroundStyle(UltronTheme.text)
            }
            Text("HUD")
                .font(UltronTheme.Typography.kicker())
                .tracking(1.89)
                .textCase(.uppercase)
                .foregroundStyle(UltronTheme.textMute)
                .padding(.leading, 10)
                .overlay(
                    Rectangle()
                        .fill(UltronTheme.line)
                        .frame(width: 1)
                        .frame(maxHeight: 14),
                    alignment: .leading
                )
        }
    }

    private var tabs: some View {
        HStack(spacing: 2) {
            ForEach(UltronTab.allCases) { tab in
                Button {
                    activeTab = tab
                } label: {
                    Text(tab.title)
                        .font(UltronTheme.Typography.body(size: 12.5))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(activeTab == tab ? UltronTheme.paper : Color.clear)
                        )
                        .foregroundStyle(activeTab == tab ? UltronTheme.ink : UltronTheme.textDim)
                        .animation(UltronTheme.hoverEase, value: activeTab)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(UltronTheme.ink2)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(UltronTheme.lineSoft, lineWidth: 1)
                )
        )
    }

    private var livePill: some View {
        HStack(spacing: 8) {
            PulsingDot(color: UltronTheme.accent, pulsing: livePulsing)
            Text(liveLabel)
                .font(UltronTheme.Typography.kvLabel())
                .foregroundStyle(UltronTheme.textMute)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(
            Capsule().fill(UltronTheme.ink2)
                .overlay(Capsule().stroke(UltronTheme.lineSoft, lineWidth: 1))
        )
    }

    private var timeText: some View {
        Text(Self.timeFormatter.string(from: now))
            .font(UltronTheme.Typography.kvLabel())
            .tracking(0.6)
            .foregroundStyle(UltronTheme.textMute)
    }

    private var hotkeyHint: some View {
        Button(action: onHotkeySheet) {
            HStack(spacing: 6) {
                Text("?")
                    .font(.custom(UltronTheme.FontName.monoRegular, size: 10.5))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(UltronTheme.ink2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(UltronTheme.line, lineWidth: 1)
                            )
                    )
                Text("taster")
                    .font(UltronTheme.Typography.kvLabel())
                    .foregroundStyle(UltronTheme.textMute)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Formatter

    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df
    }()
}

// MARK: - Tab enum

enum UltronTab: String, CaseIterable, Identifiable, Codable {
    case cockpit
    case voice
    case chat
    var id: String { rawValue }

    var title: String {
        switch self {
        case .cockpit: return "Cockpit"
        case .voice:   return "Stemme"
        case .chat:    return "Chat"
        }
    }
}

// MARK: - Small decorative views

private struct UltronGlyph: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(UltronTheme.text, lineWidth: 1.25)
            Circle()
                .fill(UltronTheme.accent)
                .frame(width: 7, height: 7)
        }
    }
}

private struct PulsingDot: View {
    let color: Color
    let pulsing: Bool
    @State private var phase = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .opacity(phase ? 0.55 : 1.0)
            .scaleEffect(phase ? 1.15 : 1.0)
            .onAppear {
                guard pulsing else { return }
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    phase = true
                }
            }
    }
}
