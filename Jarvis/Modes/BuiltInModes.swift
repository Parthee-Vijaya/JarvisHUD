import Foundation

enum BuiltInModes {
    static let dictation = Mode(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Dictation",
        systemPrompt: """
        Transkriber følgende audio til skreven tekst. Ryd op i pausord, 'øh', gentagelser og tyde-fejl. \
        Bevar brugerens tone og sprog. Returnér kun den rensede tekst, ingen meta-kommentar.
        """,
        model: .flash,
        outputType: .paste,
        maxTokens: 2048,
        isBuiltIn: true
    )

    static let vibeCode = Mode(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "VibeCode",
        systemPrompt: """
        Du er en teknisk prompt-ingeniør. Tag brugerens talte idé og omskriv den til en præcis, \
        struktureret prompt målrettet en AI-coding agent (Claude Code, Cursor, Lovable). \
        Inkluder: mål, acceptkriterier, teknisk kontekst, edge cases. \
        Brug engelsk medmindre brugeren taler dansk specifikt. Returnér kun den færdige prompt.
        """,
        model: .pro,
        outputType: .paste,
        maxTokens: 4096,
        isBuiltIn: true
    )

    static let professional = Mode(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        name: "Professional",
        systemPrompt: """
        Omskriv følgende dikteret tekst til en professionel, klar formulering egnet til \
        arbejdskommunikation (email, Slack til ledelse, formelt notat). Bevar indhold og intention. \
        Brug samme sprog som input.
        """,
        model: .flash,
        outputType: .paste,
        maxTokens: 2048,
        isBuiltIn: true
    )

    static let qna = Mode(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
        name: "Q&A",
        systemPrompt: """
        Svar direkte på brugerens spørgsmål. Vær kortfattet. Undgå indledende høfligheder. \
        Maks 150 ord medmindre spørgsmålet kræver dybde. Hvis spørgsmålet kræver aktuel eller \
        faktuel information, brug Google Search til at finde opdaterede svar og cite kilder kort.
        """,
        model: .flash,
        outputType: .hud,
        maxTokens: 1024,
        isBuiltIn: true,
        webSearch: true
    )

    static let vision = Mode(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
        name: "Vision",
        systemPrompt: """
        Du ser et screenshot af brugerens skærm. Svar konkret på deres spørgsmål baseret på hvad \
        der er synligt. Hvis de peger på en fejl, forklar hvad der er galt og hvordan det fikses. \
        Hvis svaret kræver opdateret viden udenfor billedet, brug Google Search.
        """,
        model: .flash,
        outputType: .hud,
        maxTokens: 2048,
        isBuiltIn: true,
        webSearch: true
    )

    static let chat = Mode(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
        name: "Chat",
        systemPrompt: """
        Du er Jarvis, en hjælpsom AI-assistent. Svar præcist og hjælpsomt på brugerens besked. \
        Brug markdown formatting til at strukturere dine svar. Hold svarene kortfattede medmindre \
        brugeren beder om detaljer. Svar på samme sprog som brugeren skriver.
        """,
        model: .flash,
        outputType: .chat,
        maxTokens: 4096,
        isBuiltIn: true
    )

    static let translate = Mode(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000007")!,
        name: "Translate",
        systemPrompt: """
        Du er en oversætter. Hvis brugerens tekst er på dansk, oversæt til engelsk. \
        Hvis teksten er på engelsk, oversæt til dansk. Returnér KUN oversættelsen, \
        ingen forklaring eller meta-kommentar. Bevar tone og stil.
        """,
        model: .flash,
        outputType: .paste,
        maxTokens: 2048,
        isBuiltIn: true
    )

    static let summarize = Mode(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000008")!,
        name: "Summarize",
        systemPrompt: """
        Du modtager indholdet af et dokument. Lav en klar, struktureret opsummering:

        • **TL;DR** — én sætning der fanger essensen.
        • **Hovedpunkter** — 3–6 bullet points med de vigtigste pointer, konklusioner eller beslutninger.
        • **Action items** — kun hvis dokumentet indeholder konkrete opgaver, deadlines eller næste skridt.
        • **Kilder / tal** — hvis dokumentet bygger på specifikke tal eller citater, marker dem kort.

        Svar på samme sprog som dokumentet. Brug markdown. Ingen indledende høfligheder. \
        Hvis dokumentet er kode eller teknisk, fokuser på arkitektur, API-overflade og kendte \
        gotchas i stedet for bullet-points.
        """,
        model: .flash,
        outputType: .hud,
        maxTokens: 2048,
        isBuiltIn: true
    )

    static let all: [Mode] = [dictation, vibeCode, professional, qna, vision, chat, translate, summarize]
}
