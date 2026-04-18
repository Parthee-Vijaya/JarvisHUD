import AppKit
import Foundation

/// Glue layer between the ⌥⇧S hotkey and Gemini. Picks a file, reads it, wraps it
/// in a summary prompt, and routes the result into the HUD.
@MainActor
final class DocumentSummaryService {
    private let geminiClient: GeminiClient
    private let hudController: HUDWindowController
    private let reader = DocumentReader()

    init(geminiClient: GeminiClient, hudController: HUDWindowController) {
        self.geminiClient = geminiClient
        self.hudController = hudController
    }

    /// Run the full flow — called by AppDelegate on ⌥⇧S. The file picker is modal and
    /// must run on main; the network work happens in a Task after.
    func summarizeInteractively() {
        guard let url = DocumentPicker.pickDocument() else { return }
        summarize(url: url)
    }

    /// Summarize a known URL (used by the picker path and any future drag-drop).
    func summarize(url: URL) {
        let document: DocumentReader.ExtractedDocument
        do {
            document = try reader.read(url: url)
        } catch {
            hudController.showError(error.localizedDescription)
            return
        }

        hudController.activeModeName = "Summarize"
        hudController.speechService.reset()
        hudController.showProcessing()
        LoggingService.shared.log("Summarize: \(document.fileName) (\(document.text.count) chars, truncated=\(document.wasTruncated))")

        let prompt = buildPrompt(for: document)

        Task { [weak self] in
            guard let self else { return }
            let result = await geminiClient.sendText(prompt: prompt, mode: BuiltInModes.summarize)
            switch result {
            case .success(let text):
                let decorated = decorate(summary: text, for: document)
                self.hudController.showResult(decorated)
            case .failure(let error):
                self.hudController.showError("Opsummering fejlede: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private

    private func buildPrompt(for document: DocumentReader.ExtractedDocument) -> String {
        let header = """
        Dokument: \(document.fileName)
        Filtype: .\(document.fileExtension)
        """
        let truncatedNote = document.wasTruncated ? "\n(Bemærk: dokumentet er afkortet til \(DocumentReader.maxCharacters) tegn — opsummeringen dækker kun starten.)" : ""
        return """
        \(header)\(truncatedNote)

        -------- BEGIN DOCUMENT --------
        \(document.text)
        -------- END DOCUMENT --------

        Opsummer dokumentet efter instruktionerne i systemprompten.
        """
    }

    /// Tag the HUD output with the filename so the result card stands on its own.
    private func decorate(summary: String, for document: DocumentReader.ExtractedDocument) -> String {
        let header = "📄 **\(document.fileName)**" + (document.wasTruncated ? "  _(afkortet)_" : "")
        return "\(header)\n\n\(summary)"
    }
}
