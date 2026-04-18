import Foundation

enum GeminiModel: String, Codable, CaseIterable {
    case flash = "gemini-2.5-flash"
    case pro = "gemini-2.5-pro"

    var displayName: String {
        switch self {
        case .flash: return "Gemini 2.5 Flash"
        case .pro: return "Gemini 2.5 Pro"
        }
    }
}

enum OutputType: String, Codable, CaseIterable {
    case paste
    case hud
    case chat

    var displayName: String {
        switch self {
        case .paste: return "Paste at cursor"
        case .hud: return "Show in HUD"
        case .chat: return "Chat window"
        }
    }
}

struct Mode: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var systemPrompt: String
    var model: GeminiModel
    var outputType: OutputType
    var maxTokens: Int
    var isBuiltIn: Bool
    /// If true, Gemini runs the `google_search` grounding tool when answering.
    /// Only honoured on non-paste output types (Q&A, Vision, Chat) — dictation-style
    /// rewrite modes are better left un-grounded.
    var webSearch: Bool

    init(
        id: UUID,
        name: String,
        systemPrompt: String,
        model: GeminiModel,
        outputType: OutputType,
        maxTokens: Int,
        isBuiltIn: Bool,
        webSearch: Bool = false
    ) {
        self.id = id
        self.name = name
        self.systemPrompt = systemPrompt
        self.model = model
        self.outputType = outputType
        self.maxTokens = maxTokens
        self.isBuiltIn = isBuiltIn
        self.webSearch = webSearch
    }

    // Custom Codable so older JSON files (v3.0 custom modes without `webSearch`) decode cleanly.
    private enum CodingKeys: String, CodingKey {
        case id, name, systemPrompt, model, outputType, maxTokens, isBuiltIn, webSearch
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        systemPrompt = try c.decode(String.self, forKey: .systemPrompt)
        model = try c.decode(GeminiModel.self, forKey: .model)
        outputType = try c.decode(OutputType.self, forKey: .outputType)
        maxTokens = try c.decode(Int.self, forKey: .maxTokens)
        isBuiltIn = try c.decode(Bool.self, forKey: .isBuiltIn)
        webSearch = try c.decodeIfPresent(Bool.self, forKey: .webSearch) ?? false
    }

    static func == (lhs: Mode, rhs: Mode) -> Bool {
        lhs.id == rhs.id
    }
}
