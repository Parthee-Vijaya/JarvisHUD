import Foundation
import GoogleGenerativeAI

class GeminiClient {
    private let keychainService: KeychainService
    private let usageTracker: UsageTracker

    init(keychainService: KeychainService, usageTracker: UsageTracker) {
        self.keychainService = keychainService
        self.usageTracker = usageTracker
    }

    private func makeModel(modelName: String, systemPrompt: String) -> GenerativeModel? {
        guard let apiKey = keychainService.getAPIKey() else {
            LoggingService.shared.log("No API key found in Keychain", level: .error)
            return nil
        }

        return GenerativeModel(
            name: modelName,
            apiKey: apiKey,
            generationConfig: GenerationConfig(maxOutputTokens: 4096),
            systemInstruction: ModelContent(role: "system", parts: [.text(systemPrompt)])
        )
    }

    func testConnection() async -> Result<String, Error> {
        guard let model = makeModel(
            modelName: Constants.GeminiModelName.flash,
            systemPrompt: "You are a test assistant."
        ) else {
            return .failure(JarvisError.noAPIKey)
        }

        do {
            let response = try await model.generateContent("Say 'Connection successful' in exactly those words.")
            if let text = response.text {
                LoggingService.shared.log("Gemini connection test: OK")
                return .success(text)
            }
            return .failure(JarvisError.emptyResponse)
        } catch {
            LoggingService.shared.log("Gemini connection test failed: \(error)", level: .error)
            return .failure(error)
        }
    }

    func sendAudio(_ audioData: Data, mode: Mode) async -> Result<String, Error> {
        let modelName = mode.model == .pro ? Constants.GeminiModelName.pro : Constants.GeminiModelName.flash

        guard let model = makeModel(modelName: modelName, systemPrompt: mode.systemPrompt) else {
            return .failure(JarvisError.noAPIKey)
        }

        let audioPart = ModelContent.Part.data(mimetype: "audio/wav", audioData)
        return await withRetry {
            try await self.executeGeneration(model: model, parts: [audioPart], mode: mode)
        }
    }

    func sendAudioWithImage(_ audioData: Data, imageData: Data, mode: Mode) async -> Result<String, Error> {
        let modelName = mode.model == .pro ? Constants.GeminiModelName.pro : Constants.GeminiModelName.flash

        guard let model = makeModel(modelName: modelName, systemPrompt: mode.systemPrompt) else {
            return .failure(JarvisError.noAPIKey)
        }

        let audioPart = ModelContent.Part.data(mimetype: "audio/wav", audioData)
        let imagePart = ModelContent.Part.data(mimetype: "image/png", imageData)
        return await withRetry {
            try await self.executeGeneration(model: model, parts: [audioPart, imagePart], mode: mode)
        }
    }

    // MARK: - Chat & Streaming

    /// Create a GenerativeModel and start an SDK Chat for multi-turn conversation.
    func startChat(mode: Mode, history: [ModelContent] = []) -> (GenerativeModel, Chat)? {
        let modelName = mode.model == .pro ? Constants.GeminiModelName.pro : Constants.GeminiModelName.flash
        guard let model = makeModel(modelName: modelName, systemPrompt: mode.systemPrompt) else { return nil }
        let chat = model.startChat(history: history)
        return (model, chat)
    }

    /// Stream a text message through an existing SDK Chat, calling `onDelta` for each token chunk.
    func sendTextStreaming(
        chat: Chat,
        text: String,
        mode: Mode,
        onDelta: @escaping (String) -> Void
    ) async -> Result<String, Error> {
        do {
            var full = ""
            let stream = chat.sendMessageStream(text)
            for try await chunk in stream {
                if let part = chunk.text {
                    full += part
                    onDelta(part)
                }
                if let usage = chunk.usageMetadata {
                    usageTracker.trackUsage(
                        model: mode.model,
                        inputTokens: usage.promptTokenCount ?? 0,
                        outputTokens: usage.candidatesTokenCount ?? 0
                    )
                }
            }
            guard !full.isEmpty else { return .failure(JarvisError.emptyResponse) }
            let cleaned = postProcess(full)
            return .success(cleaned)
        } catch {
            LoggingService.shared.log("Streaming error: \(error)", level: .error)
            return .failure(error)
        }
    }

    /// Stream audio through generateContentStream (single-turn, for voice-in-chat).
    func sendAudioStreaming(
        _ audioData: Data,
        mode: Mode,
        onDelta: @escaping (String) -> Void
    ) async -> Result<String, Error> {
        let modelName = mode.model == .pro ? Constants.GeminiModelName.pro : Constants.GeminiModelName.flash
        guard let model = makeModel(modelName: modelName, systemPrompt: mode.systemPrompt) else {
            return .failure(JarvisError.noAPIKey)
        }

        do {
            let audioPart = ModelContent.Part.data(mimetype: "audio/wav", audioData)
            let content = [ModelContent(role: "user", parts: [audioPart])]
            var full = ""
            let stream = model.generateContentStream(content)
            for try await chunk in stream {
                if let part = chunk.text {
                    full += part
                    onDelta(part)
                }
                if let usage = chunk.usageMetadata {
                    usageTracker.trackUsage(
                        model: mode.model,
                        inputTokens: usage.promptTokenCount ?? 0,
                        outputTokens: usage.candidatesTokenCount ?? 0
                    )
                }
            }
            guard !full.isEmpty else { return .failure(JarvisError.emptyResponse) }
            let cleaned = postProcess(full)
            return .success(cleaned)
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Core Generation

    private func executeGeneration(model: GenerativeModel, parts: [ModelContent.Part], mode: Mode) async throws -> String {
        let content = [ModelContent(role: "user", parts: parts)]
        let response = try await model.generateContent(content)

        if let usage = response.usageMetadata {
            usageTracker.trackUsage(
                model: mode.model,
                inputTokens: usage.promptTokenCount ?? 0,
                outputTokens: usage.candidatesTokenCount ?? 0
            )
        }

        guard let text = response.text else {
            throw JarvisError.emptyResponse
        }

        let cleaned = postProcess(text)
        LoggingService.shared.log("Gemini response received (\(cleaned.count) chars)")
        return cleaned
    }

    // MARK: - Retry with Exponential Backoff

    private func withRetry(
        maxAttempts: Int = Constants.Retry.maxAttempts,
        operation: @escaping () async throws -> String
    ) async -> Result<String, Error> {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                let result = try await operation()
                return .success(result)
            } catch {
                lastError = error

                // Only retry on transient network errors
                guard isTransientError(error), attempt < maxAttempts else {
                    LoggingService.shared.log("Gemini API error (attempt \(attempt)/\(maxAttempts), not retrying): \(error)", level: .error)
                    break
                }

                let delay = Constants.Retry.baseDelay * pow(Constants.Retry.backoffMultiplier, Double(attempt - 1))
                LoggingService.shared.log("Gemini API error (attempt \(attempt)/\(maxAttempts)), retrying in \(delay)s: \(error)", level: .warning)
                try? await Task.sleep(for: .seconds(delay))
            }
        }

        return .failure(lastError ?? JarvisError.emptyResponse)
    }

    private func isTransientError(_ error: Error) -> Bool {
        let nsError = error as NSError
        // Network-related error domains
        if nsError.domain == NSURLErrorDomain {
            return true
        }
        // HTTP 5xx or timeout-like errors
        let transientCodes = [NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost, NSURLErrorNotConnectedToInternet]
        return transientCodes.contains(nsError.code)
    }

    // MARK: - Post Processing

    private func postProcess(_ text: String) -> String {
        var result = text
        let patterns = [
            "^(Here'?s?|Her er) (the |din |your )?(cleaned[- ]?up |rensede )?te[xk]st?:?\\s*",
            "^Sure[,!]?\\s*(here'?s?)?\\s*",
            "^Of course[,!]?\\s*",
            "^Certainly[,!]?\\s*"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum JarvisError: LocalizedError {
    case noAPIKey
    case emptyResponse
    case audioCaptureFailed
    case audioFormatInvalid
    case accessibilityDenied
    case screenCaptureDenied
    case networkError(underlying: Error)
    case permissionDenied(permission: String, instructions: String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "No Gemini API key found. Please add it in Settings."
        case .emptyResponse: return "Gemini returned an empty response."
        case .audioCaptureFailed: return "Failed to capture audio from microphone."
        case .audioFormatInvalid: return "Audio input format is invalid (sample rate is 0)."
        case .accessibilityDenied: return "Accessibility permission is required for text insertion."
        case .screenCaptureDenied: return "Screen Recording permission is required for Vision mode."
        case .networkError(let underlying): return "Network error: \(underlying.localizedDescription)"
        case .permissionDenied(let permission, _): return "\(permission) permission is required."
        }
    }
}
