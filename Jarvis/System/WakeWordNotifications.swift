import Foundation

extension Notification.Name {
    /// Fired when the user toggles the wake-word setting or saves a new AccessKey.
    /// AppDelegate listens and restarts (or stops) the detector accordingly.
    static let jarvisWakeWordSettingsChanged = Notification.Name("jarvisWakeWordSettingsChanged")

    /// Fired when the continuous "Jarvis ..." voice-command toggle flips.
    static let jarvisVoiceCommandSettingsChanged = Notification.Name("jarvisVoiceCommandSettingsChanged")

    /// Fired when the morning-briefing scheduler is toggled or its time is changed.
    static let jarvisMorningBriefingSettingsChanged = Notification.Name("jarvisMorningBriefingSettingsChanged")

    /// Fired when the Live Voice toggle flips in Settings — lets AppDelegate
    /// surface a brief status HUD next wake event.
    static let jarvisLiveVoiceSettingsChanged = Notification.Name("jarvisLiveVoiceSettingsChanged")
}
