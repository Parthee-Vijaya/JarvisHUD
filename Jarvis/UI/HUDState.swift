import Foundation
import Observation

@Observable
class HUDState {
    enum Phase: Equatable {
        case recording(elapsed: TimeInterval)
        case processing
        case result(text: String)
        case confirmation(message: String)
        case error(message: String)
        case permissionError(permission: String, instructions: String)
        case chat
        case uptodate
        case infoMode
        case agentChat

        static func == (lhs: Phase, rhs: Phase) -> Bool {
            switch (lhs, rhs) {
            case (.recording(let a), .recording(let b)): return a == b
            case (.processing, .processing): return true
            case (.result(let a), .result(let b)): return a == b
            case (.confirmation(let a), .confirmation(let b)): return a == b
            case (.error(let a), .error(let b)): return a == b
            case (.permissionError(let p1, let i1), .permissionError(let p2, let i2)):
                return p1 == p2 && i1 == i2
            case (.chat, .chat): return true
            case (.uptodate, .uptodate): return true
            case (.infoMode, .infoMode): return true
            case (.agentChat, .agentChat): return true
            default: return false
            }
        }
    }

    var currentPhase: Phase = .processing
    var isVisible = false
    var isPinned = false
}
