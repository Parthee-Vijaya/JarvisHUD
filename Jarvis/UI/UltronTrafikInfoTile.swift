import SwiftUI

/// Trafikinfo nær dig (Traffic info near you) tile — Ultron redesign.
///
/// Matches the handoff spec:
/// - Tone: amber (top border)
/// - 6-col span, no big number
/// - List of up to 5 events: 28×28 tinted icon badge, serif header
///   (bold first word + rest), right-aligned mono relative time.
/// - Meta: "DK · N aktive · M uheld"
struct UltronTrafikInfoTile: View {
    let events: [TrafficEvent]
    let totalCount: Int
    let countByCategory: [(TrafficEvent.Category, Int)]

    private var visibleEvents: [TrafficEvent] {
        Array(events.prefix(5))
    }

    var body: some View {
        UltronTile(
            title: "Trafikinfo nær dig",
            english: "Traffic · nearby",
            tone: .amber
        ) {
            if visibleEvents.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(visibleEvents.enumerated()), id: \.offset) { _, event in
                        row(for: event)
                    }
                }
            }
        } meta: {
            EmptyView()
        } footer: {
            UltronMetaRow(
                text: footerText,
                dotColor: UltronTheme.warn,
                pulsing: false
            )
        }
    }

    // MARK: - Row

    private func row(for event: TrafficEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            iconBadge(for: event.category)
            headerText(for: event)
                .font(.custom(UltronTheme.FontName.serifRoman, size: 14))
                .foregroundStyle(UltronTheme.text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let ago = event.timeAgoLabel() {
                Text(ago)
                    .font(.custom(UltronTheme.FontName.monoRegular, size: 11))
                    .foregroundStyle(UltronTheme.textMute)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    // Bold first word + rest of header, e.g. "**Uheld**, E20 østgående …".
    private func headerText(for event: TrafficEvent) -> Text {
        let raw = event.header.isEmpty ? event.title : event.header
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard let splitIndex = trimmed.firstIndex(where: { $0 == " " || $0 == "," }) else {
            return Text(trimmed).fontWeight(.semibold)
        }
        let first = String(trimmed[..<splitIndex])
        let rest = String(trimmed[splitIndex...])
        return Text(first).fontWeight(.semibold) + Text(rest)
    }

    // MARK: - Icon badge

    private func iconBadge(for category: TrafficEvent.Category) -> some View {
        let tint = tintColor(for: category)
        return ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(tint.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(tint.opacity(0.45), lineWidth: 1)
                )
            Image(systemName: symbolName(for: category))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: 28, height: 28)
    }

    private func tintColor(for category: TrafficEvent.Category) -> Color {
        switch category {
        case .accident:      return UltronTheme.accent
        case .animal:        return UltronTheme.warn
        case .obstruction:   return UltronTheme.warn
        case .roadCondition: return UltronTheme.ok
        case .publicEvent:   return UltronTheme.TileTone.cream.color
        case .other:         return UltronTheme.textMute
        }
    }

    private func symbolName(for category: TrafficEvent.Category) -> String {
        switch category {
        case .accident:      return "exclamationmark.triangle.fill"
        case .animal:        return "hare.fill"
        case .obstruction:   return "xmark.octagon.fill"
        case .roadCondition: return "drop.triangle.fill"
        case .publicEvent:   return "flag.fill"
        case .other:         return "exclamationmark.circle.fill"
        }
    }

    // MARK: - Footer

    private var footerText: String {
        let accidentCount = countByCategory
            .first(where: { $0.0 == .accident })?.1 ?? 0
        return "DK · \(totalCount) aktive · \(accidentCount) uheld"
    }

    // MARK: - Empty

    private var emptyState: some View {
        Text("Ingen aktive hændelser i nærheden.")
            .font(UltronTheme.Typography.caption(size: 14))
            .foregroundStyle(UltronTheme.textDim)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
