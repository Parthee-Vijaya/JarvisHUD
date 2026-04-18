import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - UI
    private var statusItem: NSStatusItem!
    private var statusMenu: NSMenu!
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private let settingsHostState = SettingsHostState()

    // Menu items updated in-place
    private var modeMenuItem: NSMenuItem?
    private var usageMenuItem: NSMenuItem?
    private var modesSubmenuItem: NSMenuItem?

    // MARK: - Public (accessed by JarvisApp)
    let modeManager = ModeManager()
    let usageTracker = UsageTracker()
    lazy var hotkeyBindings = HotkeyBindings(store: hotkeyStore, manager: hotkeyManager)

    // MARK: - Services
    private let keychainService = KeychainService()
    private let hotkeyManager = HotkeyManager()
    private let hotkeyStore = HotkeyStore()
    private let hudController = HUDWindowController()
    private var pipeline: RecordingPipeline!
    let chatSession = ChatSession()
    private var chatPipeline: ChatPipeline!
    private lazy var wakeWordDetector: WakeWordDetecting = PorcupineWakeWordDetector(
        accessKeyProvider: { [weak keychainService] in keychainService?.getPorcupineKey() }
    )
    let voiceCommandService = VoiceCommandService()
    let locationService = LocationService()
    lazy var updatesService = UpdatesService(locationService: locationService)
    lazy var infoModeService = InfoModeService(locationService: locationService)
    lazy var errorPresenter = ErrorPresenter(hudController: hudController)
    private lazy var summaryService = DocumentSummaryService(
        geminiClient: geminiClient,
        hudController: hudController,
        errorPresenter: errorPresenter
    )

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
            setupChatPipeline()
            setupMenuBar()
            setupHotkeys()
            hotkeyBindings.applyAll()
            setupCostWarning()
            setupWakeWord()
            setupVoiceCommands()
            checkFirstLaunch()
            LoggingService.shared.log("Jarvis v\(Constants.appVersion) started")
        }
    }

    // MARK: - Pipeline Setup

    private func setupPipeline() {
        // Wire the mic tap's RMS + peak samples into the HUD's live visualisers.
        audioCapture.levelMonitor = hudController.audioLevel
        audioCapture.waveformBuffer = hudController.waveform

        // Ask for on-device speech-recognition auth up front so the first ⌥Q
        // isn't interrupted by a permission prompt.
        Task { await hudController.speechService.requestAuthorization() }

        // Wire the Uptodate + Info panel data sources.
        hudController.updatesService = updatesService
        hudController.infoModeService = infoModeService

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

    // MARK: - Chat Pipeline Setup

    private func setupChatPipeline() {
        hudController.chatSession = chatSession

        chatPipeline = ChatPipeline(
            geminiClient: geminiClient,
            chatSession: chatSession,
            hudController: hudController
        )

        hudController.onChatSend = { [weak self] text in
            self?.chatPipeline.sendTextMessage(text)
        }

        hudController.onPinToggle = { [weak self] in
            guard let self else { return }
            self.hudController.hudState.isPinned.toggle()
        }
    }

    /// Called by `SettingsView` after the user saves a new API key so the chat pipeline
    /// drops its cached SDK Chat (which was constructed with the old key).
    func resetChatPipelineForKeyRotation() {
        chatPipeline?.reset()
        LoggingService.shared.log("Chat pipeline reset after API key rotation")
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

        // Quick-launch panels
        let infoItem = NSMenuItem(title: "Info mode", action: #selector(openInfoModeFromMenu), keyEquivalent: "i")
        infoItem.target = self
        infoItem.keyEquivalentModifierMask = [.option]
        statusMenu.addItem(infoItem)

        let uptodateItem = NSMenuItem(title: "Uptodate (vejr + nyheder)", action: #selector(openUptodateFromMenu), keyEquivalent: "u")
        uptodateItem.target = self
        uptodateItem.keyEquivalentModifierMask = [.option]
        statusMenu.addItem(uptodateItem)

        // Hotkey cheat sheet submenu
        let shortcutsItem = NSMenuItem(title: "Hurtig-genveje", action: nil, keyEquivalent: "")
        shortcutsItem.submenu = buildShortcutsSubmenu()
        statusMenu.addItem(shortcutsItem)

        statusMenu.addItem(NSMenuItem.separator())

        let hotkeysItem = NSMenuItem(title: "Tilpas hotkeys…", action: #selector(openHotkeysSettings), keyEquivalent: "")
        hotkeysItem.target = self
        statusMenu.addItem(hotkeysItem)

        let settingsItem = NSMenuItem(title: "Indstillinger…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        statusMenu.addItem(settingsItem)

        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(NSMenuItem(title: "Afslut Jarvis", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = statusMenu
    }

    /// Read-only "cheat sheet" of active hotkeys so the user can see them at a
    /// glance without opening Settings.
    private func buildShortcutsSubmenu() -> NSMenu {
        let submenu = NSMenu()
        for action in HotkeyAction.allCases {
            let binding = hotkeyBindings.binding(for: action)
            let item = NSMenuItem(
                title: "\(action.displayName)   \(binding.displayString)",
                action: nil,
                keyEquivalent: ""
            )
            item.isEnabled = false
            submenu.addItem(item)
        }
        return submenu
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
        presentSettings(tab: nil)
    }

    @objc private func openHotkeysSettings() {
        presentSettings(tab: .hotkeys)
    }

    @objc private func openInfoModeFromMenu() {
        if hudController.isInfoModeVisible {
            hudController.close()
        } else {
            hudController.showInfoMode()
        }
    }

    @objc private func openUptodateFromMenu() {
        if hudController.isUptodateVisible {
            hudController.close()
        } else {
            hudController.showUptodate()
        }
    }

    private func presentSettings(tab: SettingsTab?) {
        if let tab { settingsHostState.selectedTab = tab }
        if settingsWindow == nil {
            let settingsView = SettingsHost(state: settingsHostState)
                .environment(modeManager)
                .environment(usageTracker)
                .environment(hotkeyBindings)
            let hostingController = NSHostingController(rootView: settingsView)
            // Use the view's own sizing hints — SwiftUI populates the hosting
            // controller's preferredContentSize from the .frame(ideal:) modifiers.
            hostingController.sizingOptions = [.preferredContentSize]

            let window = NSWindow(contentViewController: hostingController)
            window.title = "Jarvis Settings"
            window.styleMask = [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView]
            window.setContentSize(NSSize(
                width: Constants.SettingsWindow.defaultWidth,
                height: Constants.SettingsWindow.defaultHeight
            ))
            window.minSize = NSSize(
                width: Constants.SettingsWindow.minWidth,
                height: Constants.SettingsWindow.minHeight
            )
            // Persist size across launches — AppKit takes care of this automatically
            // when we give the window a frame autosave name.
            window.setFrameAutosaveName("JarvisSettingsWindow")
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

        hotkeyManager.onChatToggle = { [weak self] in
            guard let self else { return }
            if self.hudController.isChatVisible {
                self.hudController.saveChatFrame()
                self.hudController.close()
            } else {
                self.hudController.showChat()
            }
        }

        hotkeyManager.onTranslateKeyDown = { [weak self] in
            self?.pipeline.handleRecordStart(mode: BuiltInModes.translate, captureScreen: false)
        }
        hotkeyManager.onTranslateKeyUp = { [weak self] in
            self?.pipeline.handleRecordStop()
        }

        hotkeyManager.onUptodate = { [weak self] in
            guard let self else { return }
            if self.hudController.isUptodateVisible {
                self.hudController.close()
            } else {
                self.hudController.showUptodate()
            }
        }

        hotkeyManager.onSummarize = { [weak self] in
            self?.summaryService.summarizeInteractively()
        }

        hotkeyManager.onInfoMode = { [weak self] in
            guard let self else { return }
            if self.hudController.isInfoModeVisible {
                self.hudController.close()
            } else {
                self.hudController.showInfoMode()
            }
        }

        // Registration happens after this, via `hotkeyBindings.applyAll()` in applicationDidFinishLaunching.
    }

    // MARK: - Cost Warning

    private func setupCostWarning() {
        usageTracker.onCostWarning = { [weak self] cost in
            self?.hudController.showError(
                "Omkostningsadvarsel: Dit månedlige forbrug har nået $\(String(format: "%.2f", cost))"
            )
        }
    }

    // MARK: - Wake Word

    private func setupWakeWord() {
        NotificationCenter.default.addObserver(
            forName: .jarvisWakeWordSettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshWakeWord()
        }
        refreshWakeWord()
    }

    private func refreshWakeWord() {
        let enabled = UserDefaults.standard.bool(forKey: Constants.Defaults.wakeWordEnabled)
        if enabled {
            startWakeWord()
        } else {
            wakeWordDetector.stop()
        }
    }

    // MARK: - Voice commands (continuous on-device "Jarvis ..." listener)

    private func setupVoiceCommands() {
        voiceCommandService.onCommand = { [weak self] command in
            guard let self else { return }
            switch command {
            case .info:
                if !self.hudController.isInfoModeVisible { self.hudController.showInfoMode() }
            case .uptodate:
                if !self.hudController.isUptodateVisible { self.hudController.showUptodate() }
            case .chat:
                if !self.hudController.isChatVisible { self.hudController.showChat() }
            case .qna:
                self.pipeline.handleRecordStart(mode: BuiltInModes.qna, captureScreen: false)
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(4))
                    self?.pipeline.handleRecordStop()
                }
            case .translate:
                self.pipeline.handleRecordStart(mode: BuiltInModes.translate, captureScreen: false)
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(4))
                    self?.pipeline.handleRecordStop()
                }
            case .summarize:
                self.summaryService.summarizeInteractively()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .jarvisVoiceCommandSettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshVoiceCommands()
        }

        Task { [weak self] in
            guard let self else { return }
            await self.voiceCommandService.prepare()
            self.refreshVoiceCommands()
        }
    }

    private func refreshVoiceCommands() {
        let enabled = UserDefaults.standard.bool(forKey: Constants.Defaults.voiceCommandsEnabled)
        if enabled {
            voiceCommandService.start()
        } else {
            voiceCommandService.stop()
        }
    }

    private func startWakeWord() {
        // Stop before restart so a key change doesn't leave a dangling mic tap.
        wakeWordDetector.stop()
        do {
            try wakeWordDetector.start { [weak self] in
                guard let self else { return }
                // Treat a wake event the same as pressing the Q&A hotkey.
                self.pipeline.handleRecordStart(mode: BuiltInModes.qna, captureScreen: false)
                // Auto-stop 4 s later — no release key to trigger stop in wake-word mode.
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(4))
                    self?.pipeline.handleRecordStop()
                }
            }
        } catch {
            LoggingService.shared.log("Wake word start failed: \(error.localizedDescription)", level: .warning)
            hudController.showError(error.localizedDescription)
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
