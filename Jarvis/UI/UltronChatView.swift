import SwiftUI

// MARK: - Demo data models

/// Status for a tool-call card. `.running` drives a pulsing warn dot; `.done`
/// shows the timing in an ok-teal pill. Both are static visual variants —
/// real streaming state will plug in alongside `ChatSession` later.
enum ToolStatus: Equatable {
    case running
    case done(String) // e.g. "240ms", "1,2s"
}

/// A single tool invocation row inside an assistant message.
struct ChatToolCall: Identifiable, Equatable {
    let id = UUID()
    let name: String        // e.g. "fetch_traffic_events"
    let sub: String         // e.g. "73 aktive · 18 uheld · DATEX II"
    let status: ToolStatus
    let icon: String        // SF Symbol name
}

/// Demo message shape for the visual iteration. Mirrors the eventual
/// `ChatSession.messages` split once we wire real data.
enum ChatMessageDemo: Identifiable {
    case user(text: String, time: String)
    case assistant(tools: [ChatToolCall], text: String, footer: String?)

    var id: UUID {
        switch self {
        case .user: return UUID()
        case .assistant: return UUID()
        }
    }
}

/// Mock conversation row for the sidebar.
struct MockConversation: Identifiable {
    let id: UUID
    let title: String
    let sub: String
    let active: Bool
}

// MARK: - UltronChatView

/// v2.0 Chat screen per the Ultron handoff (Screen 3).
///
/// Pure visual layout — real data wiring (ChatSession + ConversationStore)
/// lands in a subsequent step. The public `messages` default is the static
/// demo seed from `demoMessages`, so `#Preview { UltronChatView() }` renders.
struct UltronChatView: View {
    var messages: [ChatMessageDemo] = UltronChatView.demoMessages
    var conversationTitle: String = "Omrute forbi Køge"
    var modelMeta: String = "Sonnet 4.5 · 4 værktøjer"

    @State private var composerText: String = ""
    @State private var hoveredConversationID: UUID? = nil

    private let conversationsToday: [MockConversation] = [
        .init(id: UUID(), title: "Omrute forbi Køge",              sub: "4 værktøjskald · 2m siden",  active: true),
        .init(id: UUID(), title: "Pending release notes",          sub: "3 værktøjskald · 1t 12m siden", active: false),
        .init(id: UUID(), title: "Weekend hike-planlægning",       sub: "1 værktøjskald · 3t siden",  active: false),
    ]
    private let conversationsEarlier: [MockConversation] = [
        .init(id: UUID(), title: "Flow-diagram til ladeløsning",   sub: "8 beskeder · i går",         active: false),
        .init(id: UUID(), title: "Rejseplanen deep-link",          sub: "2 værktøjskald · onsdag",    active: false),
        .init(id: UUID(), title: "DATEX II abonnement",            sub: "12 beskeder · tirsdag",      active: false),
        .init(id: UUID(), title: "Tesla prisestimat",              sub: "4 beskeder · mandag",        active: false),
    ]

    var body: some View {
        // HStack (not HSplitView) — renders cleanly in previews and matches
        // the handoff's fixed 280pt sidebar. HSplitView can be swapped in
        // later once we want drag-to-resize.
        HStack(spacing: 0) {
            sidebar
                .frame(width: 280)
                .background(UltronTheme.ink)
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(UltronTheme.lineSoft)
                        .frame(width: 1)
                }
            mainColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(UltronTheme.rootBackground)
        }
        .frame(minWidth: 960, minHeight: 640)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                newConversationButton

                Text("I dag")
                    .font(.custom(UltronTheme.FontName.monoRegular, size: 9.5))
                    .tracking(1.9)
                    .textCase(.uppercase)
                    .foregroundStyle(UltronTheme.textFaint)
                    .padding(.top, 18)
                    .padding(.bottom, 6)

                ForEach(conversationsToday) { conv in
                    conversationRow(conv)
                }

                Text("Tidligere denne uge")
                    .font(.custom(UltronTheme.FontName.monoRegular, size: 9.5))
                    .tracking(1.9)
                    .textCase(.uppercase)
                    .foregroundStyle(UltronTheme.textFaint)
                    .padding(.top, 18)
                    .padding(.bottom, 6)

                ForEach(conversationsEarlier) { conv in
                    conversationRow(conv)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
        }
    }

    private var newConversationButton: some View {
        Button {
            // Hook for new-conversation action — wires to ChatSession.clear() later.
        } label: {
            HStack {
                Text("Ny samtale")
                    .font(.custom(UltronTheme.FontName.sansRegular, size: 13))
                    .foregroundStyle(UltronTheme.text)
                Spacer()
                Text("⌘N")
                    .font(.custom(UltronTheme.FontName.monoRegular, size: 10))
                    .foregroundStyle(UltronTheme.textFaint)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(UltronTheme.ink3)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(UltronTheme.line, lineWidth: 1)
                            )
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(UltronTheme.ink2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(UltronTheme.lineSoft, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func conversationRow(_ conv: MockConversation) -> some View {
        let hovering = hoveredConversationID == conv.id
        let bg: Color = {
            if conv.active { return UltronTheme.ink2 }
            if hovering { return UltronTheme.ink2.opacity(0.5) }
            return .clear
        }()
        let borderColor: Color = conv.active ? UltronTheme.lineSoft : .clear
        return VStack(alignment: .leading, spacing: 2) {
            Text(conv.title)
                .font(.custom(UltronTheme.FontName.serifRoman, size: 14).weight(.medium))
                .foregroundStyle(UltronTheme.text)
                .lineLimit(2)
            Text(conv.sub)
                .font(.custom(UltronTheme.FontName.monoRegular, size: 10.5))
                .tracking(0.6)
                .foregroundStyle(UltronTheme.textMute)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(bg)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
        )
        .padding(.bottom, 2)
        .contentShape(Rectangle())
        .onHover { hoveredConversationID = $0 ? conv.id : nil }
    }

    // MARK: - Main column

    private var mainColumn: some View {
        VStack(spacing: 0) {
            headerBar
            messageStream
            composer
        }
    }

    private var headerBar: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(conversationTitle)
                .font(UltronTheme.Typography.sectionH2())
                .foregroundStyle(UltronTheme.text)
            Spacer(minLength: 12)
            Text("agent")
                .font(UltronTheme.Typography.bodySemibold(size: 11))
                .foregroundStyle(UltronTheme.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Capsule().fill(UltronTheme.accent))
            Text(modelMeta)
                .font(.custom(UltronTheme.FontName.monoRegular, size: 10.5))
                .foregroundStyle(UltronTheme.textMute)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(UltronTheme.ink)
        .overlay(alignment: .bottom) {
            Rectangle().fill(UltronTheme.lineSoft).frame(height: 1)
        }
    }

    private var messageStream: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                ForEach(Array(messages.enumerated()), id: \.offset) { _, msg in
                    messageRow(msg)
                }
            }
            .frame(maxWidth: 880, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func messageRow(_ msg: ChatMessageDemo) -> some View {
        switch msg {
        case .user(let text, let time):
            userMessage(text: text, time: time)
        case .assistant(let tools, let text, let footer):
            assistantMessage(tools: tools, text: text, footer: footer)
        }
    }

    private func userMessage(text: String, time: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dig · \(time)")
                .font(.custom(UltronTheme.FontName.monoRegular, size: 9.5))
                .tracking(1.9)
                .textCase(.uppercase)
                .foregroundStyle(UltronTheme.textMute)
            Text(text)
                .font(.custom(UltronTheme.FontName.sansRegular, size: 14.5))
                .foregroundStyle(UltronTheme.text)
                .lineSpacing(3)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(UltronTheme.ink2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(UltronTheme.lineSoft, lineWidth: 1)
                        )
                )
                .frame(maxWidth: 520, alignment: .leading)
        }
    }

    private func assistantMessage(tools: [ChatToolCall], text: String, footer: String?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with tool count chip
            HStack(spacing: 8) {
                Text("Ultron · agent-mode")
                    .font(.custom(UltronTheme.FontName.monoRegular, size: 9.5))
                    .tracking(1.9)
                    .textCase(.uppercase)
                    .foregroundStyle(UltronTheme.textMute)
                Text("\(tools.count) værktøjer")
                    .font(.custom(UltronTheme.FontName.monoRegular, size: 9.5))
                    .tracking(0.4)
                    .foregroundStyle(UltronTheme.textDim)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 1)
                    .background(
                        Capsule()
                            .fill(UltronTheme.ink2)
                            .overlay(Capsule().stroke(UltronTheme.lineSoft, lineWidth: 1))
                    )
            }

            ForEach(tools) { tool in
                toolCard(tool)
            }

            Text(text)
                .font(.custom(UltronTheme.FontName.serifRoman, size: 16))
                .foregroundStyle(UltronTheme.text)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            if let footer {
                Text(footer)
                    .font(.custom(UltronTheme.FontName.monoRegular, size: 11))
                    .tracking(0.9)
                    .foregroundStyle(UltronTheme.textFaint)
                    .padding(.top, 4)
            }
        }
    }

    private func toolCard(_ tool: ChatToolCall) -> some View {
        HStack(alignment: .center, spacing: 12) {
            // Icon box
            Image(systemName: tool.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(UltronTheme.text)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(UltronTheme.ink3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(UltronTheme.line, lineWidth: 1)
                        )
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(tool.name)
                    .font(.custom(UltronTheme.FontName.monoRegular, size: 11.5))
                    .tracking(0.4)
                    .foregroundStyle(UltronTheme.text)
                Text(tool.sub)
                    .font(.custom(UltronTheme.FontName.monoRegular, size: 10.5))
                    .tracking(0.4)
                    .foregroundStyle(UltronTheme.textFaint)
            }

            Spacer(minLength: 8)

            statusPill(tool.status)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(UltronTheme.ink2)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(UltronTheme.lineSoft, lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func statusPill(_ status: ToolStatus) -> some View {
        switch status {
        case .done(let ms):
            Text("FÆRDIG · \(ms)")
                .font(.custom(UltronTheme.FontName.monoRegular, size: 10))
                .tracking(1.0)
                .foregroundStyle(UltronTheme.ok)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(UltronTheme.ok.opacity(0.15))
                        .overlay(Capsule().stroke(UltronTheme.ok.opacity(0.55), lineWidth: 1))
                )
        case .running:
            HStack(spacing: 6) {
                PulsingDot(color: UltronTheme.warn)
                Text("RUNNING")
                    .font(.custom(UltronTheme.FontName.monoRegular, size: 10))
                    .tracking(1.0)
                    .foregroundStyle(UltronTheme.warn)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(UltronTheme.warn.opacity(0.12))
                    .overlay(Capsule().stroke(UltronTheme.warn.opacity(0.55), lineWidth: 1))
            )
        }
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(spacing: 0) {
            Rectangle().fill(UltronTheme.lineSoft).frame(height: 1)
            VStack(alignment: .leading, spacing: 10) {
                // Custom text-field with placeholder overlay. TextEditor would
                // show a system focus ring; a plain TextField keeps the cream
                // look matching the handoff.
                ZStack(alignment: .topLeading) {
                    if composerText.isEmpty {
                        Text("Svar, eller tryk ⌥ Retur for at diktere…")
                            .font(.custom(UltronTheme.FontName.sansRegular, size: 14.5))
                            .foregroundStyle(UltronTheme.textFaint)
                            .padding(.vertical, 2)
                            .allowsHitTesting(false)
                    }
                    TextField("", text: $composerText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.custom(UltronTheme.FontName.sansRegular, size: 14.5))
                        .foregroundStyle(UltronTheme.text)
                        .lineLimit(2...6)
                }
                .frame(minHeight: 40, alignment: .topLeading)

                HStack(spacing: 10) {
                    ghostButton("📎 Vedhæft") {}
                    ghostButton("⌘K Værktøjer") {}
                    ghostButton("⇧⌘F Søg historik") {}
                    Spacer(minLength: 8)
                    sendButton
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: UltronTheme.Radius.composer, style: .continuous)
                    .fill(UltronTheme.ink2)
                    .overlay(
                        RoundedRectangle(cornerRadius: UltronTheme.Radius.composer, style: .continuous)
                            .stroke(UltronTheme.lineSoft, lineWidth: 1)
                    )
            )
            .frame(maxWidth: 880)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 28)
            .padding(.top, 14)
            .padding(.bottom, 22)
        }
        .background(UltronTheme.ink)
    }

    private func ghostButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.custom(UltronTheme.FontName.sansRegular, size: 12.5))
                .foregroundStyle(UltronTheme.textDim)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(UltronTheme.lineSoft, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var sendButton: some View {
        Button {
            // Hook for submit — wires to commandRouter.run(...) later.
            composerText = ""
        } label: {
            Text("Send ⌘⏎")
                .font(UltronTheme.Typography.bodySemibold(size: 13))
                .foregroundStyle(UltronTheme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(UltronTheme.paper))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pulsing dot

/// Small animated warn-coloured dot used inside the "running" status pill.
/// Extracted so the animation lives on its own lifecycle and doesn't
/// re-trigger on every parent redraw.
private struct PulsingDot: View {
    let color: Color
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .opacity(pulse ? 0.4 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}

// MARK: - Demo seed

extension UltronChatView {
    static let demoMessages: [ChatMessageDemo] = [
        .user(
            text: "Jeg tror jeg kører hjem nu. Er der noget på rute E47 mod Næstved?",
            time: "16:38"
        ),
        .assistant(
            tools: [
                ChatToolCall(name: "fetch_traffic_events",     sub: "73 aktive · 18 uheld · DATEX II",          status: .done("240ms"), icon: "network"),
                ChatToolCall(name: "route_compare",            sub: "MapKit · 2 ruter · direkte trafik",        status: .done("612ms"), icon: "map"),
                ChatToolCall(name: "charger_availability",     sub: "supercharge.info · 6 stationer forespurgt", status: .done("310ms"), icon: "bolt.fill"),
                ChatToolCall(name: "weather_at_destination",   sub: "Open-Meteo · 9°C overskyet",               status: .done("188ms"), icon: "cloud.sun"),
            ],
            text: "Jeg kigger på Vejdirektoratets direkte feed — ét uheld ved Køge spærrer højre spor, estimeret 6 minutter ekstra. Omrute forbi Gl. Landevej sparer 3 minutter netto, og dine pinnede ladepunkter i Køge har alle fri kapacitet. Vejret i Næstved er 9 grader og let overskyet.",
            footer: "⏎ tryk [R] for at åbne ruten i Kort"
        ),
    ]
}

// MARK: - Preview

#Preview("Ultron Chat") {
    UltronChatView()
        .frame(width: 1200, height: 780)
}
