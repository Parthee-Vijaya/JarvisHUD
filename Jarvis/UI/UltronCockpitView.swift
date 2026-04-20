import CoreLocation
import SwiftUI

/// v2.0 Cockpit root — Ultron design. Replaces `InfoModeView` once all
/// tiles are ported. Today only `UltronVejrTile` is real; the rest are
/// still rendered in `InfoModeView` (legacy). This view exists as a
/// live showcase so we can verify fonts / tones / layout as each tile
/// lands.
///
/// Access via `⌥⇧U` (hotkey to be wired separately) or by flipping the
/// entry point in `HUDWindow.presentInfoPanel` to `UltronCockpitView`
/// instead of `InfoModeView`.
struct UltronCockpitView: View {
    @Bindable var service: InfoModeService
    let onClose: () -> Void

    var body: some View {
        ZStack {
            UltronTheme.rootBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    greetingHeader
                    udenforSection
                    portedTileFooter
                }
                .padding(.horizontal, 28)
                .padding(.top, 28)
                .padding(.bottom, 40)
                .frame(maxWidth: 1440, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .foregroundStyle(UltronTheme.text)
        .task { await service.refresh() }
    }

    // MARK: - Sections

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(greeting())
                .font(UltronTheme.Typography.heroH1())
                .foregroundStyle(UltronTheme.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(metaLine())
                .font(UltronTheme.Typography.kvLabel())
                .tracking(0.5)
                .foregroundStyle(UltronTheme.textMute)
        }
    }

    private var udenforSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(title: "Udenfor", english: "Outside", count: 1)
            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: 260), spacing: UltronTheme.Spacing.gridGap),
                    GridItem(.flexible(minimum: 260), spacing: UltronTheme.Spacing.gridGap),
                    GridItem(.flexible(minimum: 260), spacing: UltronTheme.Spacing.gridGap),
                ],
                alignment: .leading,
                spacing: UltronTheme.Spacing.gridGap
            ) {
                UltronVejrTile(weather: service.weather)
                // Sol and Luft & Måne tiles come next — placeholder for now
                // so the 3-col grid layout is visible.
                placeholderTile(title: "Sol",        english: "Sun",         tone: .cream)
                placeholderTile(title: "Luft & Måne", english: "Air & Moon",  tone: .lilac)
            }
        }
    }

    private func sectionHeader(title: String, english: String, count: Int) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 14) {
            Text(title)
                .font(UltronTheme.Typography.sectionH2())
                .foregroundStyle(UltronTheme.text)
            Text(english)
                .font(UltronTheme.Typography.tileSubhead())
                .tracking(1.26)
                .textCase(.uppercase)
                .foregroundStyle(UltronTheme.textFaint)
            Rectangle()
                .fill(UltronTheme.lineSoft)
                .frame(height: 1)
                .frame(maxWidth: .infinity)
            Text("\(count) tiles")
                .font(UltronTheme.Typography.kicker())
                .tracking(2.31)
                .textCase(.uppercase)
                .foregroundStyle(UltronTheme.textFaint)
        }
    }

    /// Temporary placeholder for tiles not yet ported — keeps the grid
    /// rhythm visible while each real tile lands.
    private func placeholderTile(title: String, english: String, tone: UltronTheme.TileTone) -> some View {
        UltronTile(title: title, english: english, tone: tone) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Porteres i næste commit")
                    .font(UltronTheme.Typography.caption(size: 14))
                    .foregroundStyle(UltronTheme.textMute)
                Text("WIP · Ultron port")
                    .font(UltronTheme.Typography.kicker())
                    .tracking(2.31)
                    .textCase(.uppercase)
                    .foregroundStyle(UltronTheme.textFaint)
            }
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        }
    }

    private var portedTileFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ultron port — iteration 1")
                .font(UltronTheme.Typography.kicker())
                .tracking(2.31)
                .textCase(.uppercase)
                .foregroundStyle(UltronTheme.textFaint)
            Text("Theme + TileView + Vejr tile landet. Resten af grid'et porteres tile for tile.")
                .font(UltronTheme.Typography.body())
                .foregroundStyle(UltronTheme.textDim)
        }
        .padding(.top, 12)
    }

    // MARK: - Header copy

    private func greeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<10:   return "God morgen. Dagen er klar."
        case 10..<12:  return "God formiddag."
        case 12..<17:  return "God eftermiddag. Du er hjemme før det bliver mørkt, lige netop."
        case 17..<21:  return "God aften. Roen lander snart."
        default:       return "Nat. Skærmen er dæmpet for dig."
        }
    }

    private func metaLine() -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "da_DK")
        df.dateFormat = "EEEE, d. MMMM"
        let date = df.string(from: Date()).capitalized
        let timeDF = DateFormatter()
        timeDF.dateFormat = "HH:mm"
        let time = timeDF.string(from: Date())
        let loc = service.userCoordinate.map {
            String(format: "%.3f° N", $0.latitude)
        } ?? "—"
        return "\(date) · \(time) CET · \(loc)"
    }
}
