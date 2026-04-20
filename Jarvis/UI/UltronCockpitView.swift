import CoreLocation
import SwiftUI

/// v2.0 Cockpit root — Ultron design. Four-section editorial layout:
///
/// - **Udenfor**: Vejr · Sol · Luft & Måne (3-col)
/// - **Din rute**: Hjem · Rute — Trafikinfo nær dig (2-col, equal)
/// - **Over & omkring**: Fly over dig — Nyheder (2-col, equal)
/// - **Din maskine**: System · Netværk · Claude Code (3-col)
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
                    dinRuteSection
                    overOgOmkringSection
                    dinMaskineSection
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

    // MARK: - Greeting

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

    // MARK: - Sections

    private var udenforSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(title: "Udenfor", english: "Outside", count: 3)
            LazyVGrid(columns: threeCol, alignment: .leading, spacing: UltronTheme.Spacing.gridGap) {
                UltronVejrTile(weather: service.weather)
                UltronSolTile(
                    weather: service.weather,
                    latitude: service.userCoordinate?.latitude
                )
                UltronLuftMaaneTile(
                    airQuality: service.airQuality,
                    moon: service.moon
                )
            }
        }
    }

    private var dinRuteSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(title: "Din rute", english: "Your route", count: 2)
            LazyVGrid(columns: twoCol, alignment: .leading, spacing: UltronTheme.Spacing.gridGap) {
                UltronHjemRuteTile(
                    commute: service.commute,
                    chargers: service.chargers,
                    destinationWeather: service.destinationWeather
                )
                UltronTrafikInfoTile(
                    events: service.trafficEvents,
                    totalCount: service.trafficEventsTotalCount,
                    countByCategory: service.trafficEventsCountByCategory
                )
            }
        }
    }

    private var overOgOmkringSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(title: "Over & omkring", english: "Overhead & around", count: 2)
            LazyVGrid(columns: twoCol, alignment: .leading, spacing: UltronTheme.Spacing.gridGap) {
                UltronFlyTile(aircraft: service.aircraftNearby)
                UltronNyhederTile(newsBySource: service.newsBySource)
            }
        }
    }

    private var dinMaskineSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(title: "Din maskine", english: "Your machine", count: 3)
            LazyVGrid(columns: threeCol, alignment: .leading, spacing: UltronTheme.Spacing.gridGap) {
                UltronSystemTile(system: service.systemInfo)
                UltronNetvaerkTile(system: service.systemInfo)
                UltronClaudeCodeTile(stats: service.claudeStats)
            }
        }
    }

    // MARK: - Grid columns

    private var threeCol: [GridItem] {
        [
            GridItem(.flexible(minimum: 260), spacing: UltronTheme.Spacing.gridGap),
            GridItem(.flexible(minimum: 260), spacing: UltronTheme.Spacing.gridGap),
            GridItem(.flexible(minimum: 260), spacing: UltronTheme.Spacing.gridGap),
        ]
    }

    private var twoCol: [GridItem] {
        [
            GridItem(.flexible(minimum: 380), spacing: UltronTheme.Spacing.gridGap),
            GridItem(.flexible(minimum: 380), spacing: UltronTheme.Spacing.gridGap),
        ]
    }

    // MARK: - Section header

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
