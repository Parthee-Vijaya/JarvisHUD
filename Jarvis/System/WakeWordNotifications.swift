import Foundation

extension Notification.Name {
    /// Fired when the user toggles the wake-word setting or saves a new AccessKey.
    /// AppDelegate listens and restarts (or stops) the detector accordingly.
    static let jarvisWakeWordSettingsChanged = Notification.Name("jarvisWakeWordSettingsChanged")

    /// Fired when the continuous "Jarvis ..." voice-command toggle flips.
    static let jarvisVoiceCommandSettingsChanged = Notification.Name("jarvisVoiceCommandSettingsChanged")
}
