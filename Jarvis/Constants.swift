import AVFoundation

enum Constants {
    // MARK: - App
    /// Display name shown in UI. Code/bundle uses unstylised "Jarvis" to avoid
    /// breaking Keychain-service IDs and log paths.
    static let displayName = "J.A.R.V.I.S"
    static let appName = "Jarvis"
    static let appVersion = "1.2.0-alpha.1"
    static let bundleID = "pavi.Jarvis"

    // MARK: - Spacing scale (use these instead of magic numbers)
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat  = 4
        static let sm: CGFloat  = 8
        static let md: CGFloat  = 12
        static let lg: CGFloat  = 16
        static let xl: CGFloat  = 20
        static let xxl: CGFloat = 28
    }

    // MARK: - Settings window
    enum SettingsWindow {
        static let defaultWidth: CGFloat = 840
        static let defaultHeight: CGFloat = 620
        static let minWidth: CGFloat = 720
        static let minHeight: CGFloat = 520
        static let sidebarWidth: CGFloat = 200
    }

    // MARK: - Keychain
    static let keychainService = "pavi.Jarvis"
    static let keychainAccount = "GeminiAPIKey"
    static let keychainPorcupineAccount = "PorcupineAccessKey"
    static let keychainAnthropicAccount = "AnthropicAPIKey"

    // MARK: - Recording
    static let maxRecordingDuration: TimeInterval = 60
    static let audioBufferSize: AVAudioFrameCount = 4096
    static let audioBitsPerSample: UInt16 = 16

    // MARK: - HUD Dimensions
    enum HUD {
        static let width: CGFloat = 380
        static let minHeight: CGFloat = 120
        static let maxHeight: CGFloat = 400
        static let padding: CGFloat = 20
        static let cornerRadius: CGFloat = 16
        static let borderOpacity: Double = 0.2
        static let outerShadowRadius: CGFloat = 20
        static let outerShadowY: CGFloat = 10
        static let innerShadowRadius: CGFloat = 4
        static let innerShadowY: CGFloat = 2
    }

    // MARK: - Animation
    enum Animation {
        static let appearDuration: Double = 0.5
        static let appearBounce: Double = 0.6
        static let appearScaleFrom: CGFloat = 0.92
        static let appearOffsetFrom: CGFloat = 8
        static let waveformBarCount = 5
        static let waveformBarWidth: CGFloat = 4
        static let waveformBarMaxHeight: CGFloat = 24
        static let waveformAnimationDuration: Double = 0.4
    }

    // MARK: - Timers
    enum Timers {
        static let confirmationAutoClose: TimeInterval = 3
        static let resultAutoClose: TimeInterval = 30
        static let errorAutoClose: TimeInterval = 10
    }

    // MARK: - Cost
    static let costWarningThresholdUSD: Double = 1.00

    // MARK: - Retry
    enum Retry {
        static let maxAttempts = 3
        static let baseDelay: TimeInterval = 1.0
        static let backoffMultiplier: Double = 2.0
    }

    // MARK: - Crash Recovery
    static let crashRecoveryKey = "JarvisPipelineState"

    // MARK: - Chat HUD Dimensions
    enum ChatHUD {
        /// Default size for the centered Spotlight-style chat window (β.11+).
        static let width: CGFloat = 720
        static let height: CGFloat = 520
        static let minWidth: CGFloat = 520
        static let minHeight: CGFloat = 360
    }

    // MARK: - UserDefaults Keys
    enum Defaults {
        static let hasLaunchedBefore = "hasLaunchedBefore"
        static let ttsEnabled = "ttsEnabled"
        static let hudPinned = "hudPinned"
        // Chat-frame keys removed in β.11 — window is now always centered.
        // Defaults left in place get overwritten by the centering logic.
        static let wakeWordEnabled = "wakeWordEnabled"
        static let voiceCommandsEnabled = "voiceCommandsEnabled"
        static let claudeDailyLimitTokens = "claudeDailyLimitTokens"
        static let claudeWeeklyLimitTokens = "claudeWeeklyLimitTokens"
        static let agentClaudeModel = "agentClaudeModel"
        static let agentWorkspaceRoots = "agentWorkspaceRoots"
        /// v1.1.7: newline-separated list of additional program names the user
        /// trusts for `run_shell` beyond the built-in defaults.
        static let shellCommandWhitelist = "shellCommandWhitelist"

        // MARK: Jarvis voice-assistant layer (v1.3.0)
        /// What happens when the Porcupine wake-word fires.
        /// Stored as `WakeWordAction.rawValue` — see `WakeWordAction` enum.
        static let wakeWordAction = "wakeWordAction"
        /// Silence length (seconds) before VAD auto-stops a wake-word recording.
        static let vadSilenceThreshold = "vadSilenceThreshold"
        /// Toggle for bidirectional Gemini Live Audio sessions. Off by default —
        /// Live-audio models cost more than standard Flash.
        static let liveVoiceEnabled = "liveVoiceEnabled"
        /// Gemini Live model to use when liveVoiceEnabled is on.
        static let liveVoiceModel = "liveVoiceModel"
        /// Prepend a persistent persona preamble + remembered facts to Chat/Q&A
        /// system prompts so Jarvis answers in character and "remembers" you.
        static let personaEnabled = "personaEnabled"
        /// Human name the persona uses to address the user (default: "Sir").
        static let personaAddress = "personaAddress"
        /// Whether stored facts in `memory.json` are injected into the prompt.
        static let memoryInjectionEnabled = "memoryInjectionEnabled"
        /// Proactive morning briefing scheduler.
        static let morningBriefingEnabled = "morningBriefingEnabled"
        /// "HH:mm" 24-hour clock string, default "07:30".
        static let morningBriefingTime = "morningBriefingTime"
        /// ISO-date string of the last briefing run, so we don't double-fire.
        static let morningBriefingLastRun = "morningBriefingLastRun"
    }

    // MARK: - Live voice
    enum LiveVoice {
        /// Default Gemini Live audio model. User-overridable via Settings.
        /// Exposed as a constant so the WebSocket connector, UI picker and
        /// logs all reference the same string.
        static let defaultModel = "gemini-2.5-flash-preview-native-audio-dialog"
        /// Sample rate Gemini expects for PCM16 uplink and downlink.
        static let sampleRate: Int = 16_000
    }

    // MARK: - Claude Code defaults
    enum ClaudeStats {
        /// Default daily budget shown in the Info panel when the user hasn't set one.
        /// 1 M tokens is a rough placeholder for "an intense day".
        static let defaultDailyLimit = 1_000_000
        /// Default weekly budget. Free/Pro users can override in Settings.
        static let defaultWeeklyLimit = 5_000_000
    }


    // MARK: - Gemini Models
    enum GeminiModelName {
        static let flash = "gemini-2.5-flash"
        static let pro = "gemini-2.5-pro"
    }
}
