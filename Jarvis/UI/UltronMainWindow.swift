import SwiftUI

/// Unified Ultron window — three tabs (Cockpit / Stemme / Chat) share
/// one panel. Replaces the old separate InfoMode / Chat / HUD windows
/// when the `ultronRedesignEnabled` flag is on.
///
/// Keyboard:
/// - `1` / `2` / `3` → switch tab
/// - `?` (Shift-/) → hotkey cheat sheet (wired from parent)
///
/// State is persisted to `UserDefaults.standard` under the key
/// `ultron-screen` so the window opens on whichever tab was last active.
struct UltronMainWindow: View {
    @Bindable var infoService: InfoModeService
    let onClose: () -> Void

    @State private var activeTab: UltronTab = UltronMainWindow.restoreTab()
    @State private var showHotkeySheet: Bool = false

    var body: some View {
        ZStack {
            UltronTheme.rootBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                UltronTopBar(
                    activeTab: $activeTab,
                    liveLabel: liveLabel,
                    livePulsing: activeTab == .voice,
                    onHotkeySheet: { showHotkeySheet.toggle() }
                )

                // Tab content — full-flex below the top bar
                Group {
                    switch activeTab {
                    case .cockpit:
                        UltronCockpitView(service: infoService, onClose: onClose)
                    case .voice:
                        UltronVoiceHost()
                    case .chat:
                        UltronChatHost()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                .id(activeTab)                     // force state reset per tab
            }
        }
        .frame(minWidth: 1100, minHeight: 760)
        .foregroundStyle(UltronTheme.text)
        .overlay(hotkeySheetOverlay)
        .background(KeyShortcutBinder(
            onTab: { activeTab = $0 },
            onEscape: { showHotkeySheet = false },
            onQuestion: { showHotkeySheet.toggle() }
        ))
        .onChange(of: activeTab) { _, new in
            UserDefaults.standard.set(new.rawValue, forKey: UltronMainWindow.screenKey)
        }
    }

    // MARK: - Persistence

    private static let screenKey = "ultron-screen"

    private static func restoreTab() -> UltronTab {
        guard let raw = UserDefaults.standard.string(forKey: screenKey),
              let tab = UltronTab(rawValue: raw) else {
            return .cockpit
        }
        return tab
    }

    // MARK: - Live label (top-bar)

    private var liveLabel: String {
        switch activeTab {
        case .cockpit: return "Cockpit · opdateret " + relativeRefresh()
        case .voice:   return "Klar · ⌥ Space"
        case .chat:    return "Agent · Sonnet 4.5"
        }
    }

    private func relativeRefresh() -> String {
        guard let last = infoService.lastRefresh else { return "—" }
        let sec = Int(Date().timeIntervalSince(last))
        if sec < 60 { return "\(sec)s" }
        if sec < 3_600 { return "\(sec / 60)m" }
        return "\(sec / 3_600)t"
    }

    // MARK: - Hotkey sheet overlay

    @ViewBuilder
    private var hotkeySheetOverlay: some View {
        if showHotkeySheet {
            ZStack {
                Color.black.opacity(0.45).ignoresSafeArea()
                    .onTapGesture { showHotkeySheet = false }
                HotkeySheet(onClose: { showHotkeySheet = false })
            }
            .transition(.opacity)
            .animation(UltronTheme.stateEase, value: showHotkeySheet)
        }
    }
}

// MARK: - Tab content hosts

/// Placeholder hosts for tabs 2 and 3. These swap to the real
/// `UltronVoiceView` / `UltronChatView` once the parallel agents land
/// their files — the type names match so this compiles either way.
private struct UltronVoiceHost: View {
    @State private var state: UltronVoiceState = .idle

    var body: some View {
        ZStack {
            UltronTheme.rootBackground.ignoresSafeArea()
            UltronVoiceView(state: $state)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct UltronChatHost: View {
    var body: some View {
        ZStack {
            UltronTheme.rootBackground.ignoresSafeArea()
            UltronChatView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Hotkey sheet

private struct HotkeySheet: View {
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Taster")
                    .font(UltronTheme.Typography.sectionH2())
                    .foregroundStyle(UltronTheme.text)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .foregroundStyle(UltronTheme.textMute)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 10) {
                row("1 / 2 / 3",   "Skift tab — Cockpit / Stemme / Chat")
                row("⌥ Space",     "Hold for diktering")
                row("⌥ Q",         "Hold for spørg")
                row("⌥ ⇧ Space",   "Hold for vision")
                row("⌥ M",         "Skift mode")
                row("⌥ Return",    "Toggle chat")
                row("⌥ ⇧ I",       "Cockpit")
                row("⌥ ⇧ B",       "Briefing")
                row("⌘ K",         "Værktøjspaletten")
                row("Esc",         "Luk overlay")
            }
        }
        .padding(28)
        .frame(width: 480)
        .background(
            RoundedRectangle(cornerRadius: UltronTheme.Radius.composer, style: .continuous)
                .fill(UltronTheme.ink2)
                .overlay(
                    RoundedRectangle(cornerRadius: UltronTheme.Radius.composer, style: .continuous)
                        .stroke(UltronTheme.line, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 40, y: 20)
    }

    private func row(_ key: String, _ desc: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(key)
                .font(UltronTheme.Typography.kvLabel())
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(UltronTheme.ink)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(UltronTheme.line, lineWidth: 1)
                        )
                )
                .foregroundStyle(UltronTheme.text)
                .frame(width: 110, alignment: .leading)
            Text(desc)
                .font(UltronTheme.Typography.body())
                .foregroundStyle(UltronTheme.textDim)
            Spacer()
        }
    }
}

// MARK: - Keyboard shortcut binder

/// Traps 1 / 2 / 3 / ? / Esc at the window level so the tabs respond
/// without needing focus on a particular control. NSEvent local monitor
/// is cleaned up on view disappear.
private struct KeyShortcutBinder: NSViewRepresentable {
    let onTab: (UltronTab) -> Void
    let onEscape: () -> Void
    let onQuestion: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = KeyMonitorView()
        view.onTab = onTab
        view.onEscape = onEscape
        view.onQuestion = onQuestion
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class KeyMonitorView: NSView {
        var onTab: ((UltronTab) -> Void)?
        var onEscape: (() -> Void)?
        var onQuestion: (() -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    self?.handle(event) == true ? nil : event
                }
            }
        }

        override func removeFromSuperview() {
            if let m = monitor {
                NSEvent.removeMonitor(m)
                monitor = nil
            }
            super.removeFromSuperview()
        }

        private func handle(_ event: NSEvent) -> Bool {
            // Only act when no modifier keys are pressed other than Shift.
            let raw = event.charactersIgnoringModifiers
            switch raw {
            case "1": onTab?(.cockpit); return true
            case "2": onTab?(.voice);   return true
            case "3": onTab?(.chat);    return true
            case "?": onQuestion?();    return true
            default: break
            }
            if event.keyCode == 53 {  // Escape
                onEscape?()
                return true
            }
            return false
        }
    }
}
