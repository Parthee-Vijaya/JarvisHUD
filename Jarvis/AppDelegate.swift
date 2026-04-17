import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - UI
    private var statusItem: NSStatusItem!
    private var statusMenu: NSMenu!
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    // Menu items updated in-place
    private var modeMenuItem: NSMenuItem?
    private var usageMenuItem: NSMenuItem?
    private var modesSubmenuItem: NSMenuItem?

    // MARK: - Public (accessed by JarvisApp)
    let modeManager = ModeManager()
    let usageTracker = UsageTracker()

    // MARK: - Services
    private let keychainService = KeychainService()
    private let hotkeyManager = HotkeyManager()
    private let hudController = HUDWindowController()
    private var pipeline: RecordingPipeline!

    // Supporting services (owned here, injected into pipeline)
    private let audioCapture = AudioCaptureManager()
    private let textInsertion = TextInsertionService()
    private let permissions = PermissionsManager()
    private let screenCapture = ScreenCaptureService()
    private let ttsService = TTSService()
    private lazy var geminiClient = GeminiClient(keychainService: keychainService, usageTracker: usageTracker)

    // MARK: - App Lifecycle

    nonisolated func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            setupPipeline()
            setupMenuBar()
            setupHotkeys()
            setupCostWarning()
            checkFirstLaunch()
            LoggingService.shared.log("Jarvis v\(Constants.appVersion) started")
        }
    }

    // MARK: - Pipeline Setup

    private func setupPipeline() {
        pipeline = RecordingPipeline(
            audioCapture: audioCapture,
            geminiClient: geminiClient,
            textInsertion: textInsertion,
            screenCapture: screenCapture,
            permissions: permissions,
            hudController: hudController,
            ttsService: ttsService,
            modeManager: modeManager
        )

        pipeline.onStateChanged = { [weak self] state in
            self?.updateMenuBarIcon(state: state)
            self?.updateUsageLabel()
        }
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "Jarvis")
            button.image?.isTemplate = true
        }

        buildMenu()
    }

    private func buildMenu() {
        statusMenu = NSMenu()

        let headerItem = NSMenuItem(title: "Jarvis v\(Constants.appVersion)", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        statusMenu.addItem(headerItem)
        statusMenu.addItem(NSMenuItem.separator())

        let modeItem = NSMenuItem(title: "Mode: \(modeManager.activeMode.name)", action: nil, keyEquivalent: "")
        modeItem.isEnabled = false
        self.modeMenuItem = modeItem
        statusMenu.addItem(modeItem)

        let modesItem = NSMenuItem(title: "Switch Mode", action: nil, keyEquivalent: "")
        modesItem.submenu = buildModesSubmenu()
        self.modesSubmenuItem = modesItem
        statusMenu.addItem(modesItem)

        statusMenu.addItem(NSMenuItem.separator())

        let usageItem = NSMenuItem(title: usageTracker.formattedUsage, action: nil, keyEquivalent: "")
        usageItem.isEnabled = false
        self.usageMenuItem = usageItem
        statusMenu.addItem(usageItem)

        statusMenu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        statusMenu.addItem(settingsItem)

        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(NSMenuItem(title: "Quit Jarvis", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = statusMenu
    }

    private func buildModesSubmenu() -> NSMenu {
        let submenu = NSMenu()
        for mode in modeManager.allModes {
            let item = NSMenuItem(title: mode.name, action: #selector(switchMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.id.uuidString
            if mode.id == modeManager.activeMode.id {
                item.state = .on
            }
            submenu.addItem(item)
        }
        return submenu
    }

    // MARK: - Targeted Menu Updates

    private func updateModeCheckmark() {
        modeMenuItem?.title = "Mode: \(modeManager.activeMode.name)"
        modesSubmenuItem?.submenu = buildModesSubmenu()
    }

    private func updateUsageLabel() {
        usageMenuItem?.title = usageTracker.formattedUsage
    }

    // MARK: - Menu Actions

    @objc private func switchMode(_ sender: NSMenuItem) {
        guard let idString = sender.representedObject as? String,
              let uuid = UUID(uuidString: idString) else { return }
        modeManager.setActiveMode(byId: uuid)
        updateModeCheckmark()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
                .environment(modeManager)
                .environment(usageTracker)
            let hostingController = NSHostingController(rootView: settingsView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Jarvis Settings"
            window.styleMask = [.titled, .closable, .resizable]
            window.setContentSize(NSSize(width: 500, height: 450))
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Menu Bar Icon

    private func updateMenuBarIcon(state: RecordingState) {
        guard let button = statusItem.button else { return }
        switch state {
        case .idle:
            button.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "Jarvis")
            button.contentTintColor = nil
        case .recording:
            button.image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Recording")
            button.contentTintColor = .systemRed
        case .processing:
            button.image = NSImage(systemSymbolName: "gear.circle", accessibilityDescription: "Processing")
            button.contentTintColor = .systemOrange
        }
        button.image?.isTemplate = (state == .idle)
    }

    // MARK: - Hotkeys

    private func setupHotkeys() {
        hotkeyManager.onDictationKeyDown = { [weak self] in
            self?.pipeline.handleRecordStart(mode: nil, captureScreen: false)
        }
        hotkeyManager.onDictationKeyUp = { [weak self] in
            self?.pipeline.handleRecordStop()
        }

        hotkeyManager.onQnAKeyDown = { [weak self] in
            self?.pipeline.handleRecordStart(mode: BuiltInModes.qna, captureScreen: false)
        }
        hotkeyManager.onQnAKeyUp = { [weak self] in
            self?.pipeline.handleRecordStop()
        }

        hotkeyManager.onVisionKeyDown = { [weak self] in
            self?.pipeline.handleRecordStart(mode: BuiltInModes.vision, captureScreen: true)
        }
        hotkeyManager.onVisionKeyUp = { [weak self] in
            self?.pipeline.handleRecordStop()
        }

        hotkeyManager.onModeCycle = { [weak self] in
            guard let self else { return }
            self.modeManager.cycleMode()
            self.updateModeCheckmark()
            LoggingService.shared.log("Mode cycled to: \(self.modeManager.activeMode.name)")
        }

        hotkeyManager.registerHotkeys()
    }

    // MARK: - Cost Warning

    private func setupCostWarning() {
        usageTracker.onCostWarning = { [weak self] cost in
            self?.hudController.showError(
                "Omkostningsadvarsel: Dit månedlige forbrug har nået $\(String(format: "%.2f", cost))"
            )
        }
    }

    // MARK: - First Launch

    private func checkFirstLaunch() {
        let hasLaunched = UserDefaults.standard.bool(forKey: Constants.Defaults.hasLaunchedBefore)
        if !hasLaunched {
            UserDefaults.standard.set(true, forKey: Constants.Defaults.hasLaunchedBefore)
            showOnboarding()
        }
    }

    private func showOnboarding() {
        let onboardingView = OnboardingView(
            onComplete: { [weak self] in
                self?.onboardingWindow?.close()
                self?.onboardingWindow = nil
            },
            onOpenSettings: { [weak self] in
                self?.onboardingWindow?.close()
                self?.onboardingWindow = nil
                self?.openSettings()
            }
        )
        let hostingController = NSHostingController(rootView: onboardingView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to Jarvis"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 480, height: 420))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
    }
}

enum RecordingState {
    case idle, recording, processing
}
