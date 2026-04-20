import Combine
import CoreLocation
import SwiftUI

/// v2.0 Cockpit root — Ultron design. Four-section editorial layout.
///
/// - **Udenfor**: Vejr · Sol · Luft & Måne (3-col)
/// - **Din rute**: Hjem · Rute — Trafikinfo nær dig (2-col, equal)
/// - **Over & omkring**: Fly over dig — Nyheder (2-col, equal)
/// - **Din maskine**: System · Netværk · Claude Code (3-col)
///
/// Symmetric rows: uses `Grid` + `GridRow` + `.frame(maxHeight: .infinity)`
/// so each tile in a row matches the tallest sibling's height.
///
/// Live refresh: three `.task` loops keep system metrics (5 s), Claude
/// stats (15 s), and aircraft / ISS (30 s) current while the panel is
/// visible — mirroring the cadence the legacy `InfoModeView` uses.
///
/// Greeting: time-of-day hero line + rotating sub-line from the 200-line
/// `GreetingProvider` library, half the hero font size. Re-rolls every
/// 20 seconds so the Cockpit never feels scripted.
struct UltronCockpitView: View {
    @Bindable var service: InfoModeService
    let onClose: () -> Void

    @State private var greetingSeed = Int(Date().timeIntervalSince1970)
    private let greetingTick = Timer.publish(every: 20, on: .main, in: .common).autoconnect()

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
        // Claude Code tile — 15 s cadence so totals/projects/tools stay
        // fresh without waiting on the 2-min full-panel refresh.
        .task {
            while !Task.isCancelled {
                await service.refreshClaudeStats()
                try? await Task.sleep(nanoseconds: 15_000_000_000)
            }
        }
        // CPU / RAM / WiFi / Bluetooth live metrics — 5 s cadence.
        .task {
            while !Task.isCancelled {
                await service.refreshLiveMetrics()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
        // Aircraft + ISS — 30 s cadence (adsb.lol rate-limit friendly).
        .task {
            while !Task.isCancelled {
                await service.refreshAircraft()
                await service.refreshISS()
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
        .onReceive(greetingTick) { _ in
            greetingSeed = Int(Date().timeIntervalSince1970)
        }
    }

    // MARK: - Greeting

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(greetingHero())
                .font(UltronTheme.Typography.heroH1())
                .foregroundStyle(UltronTheme.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(greetingSubline())
                .font(.custom(UltronTheme.FontName.serifRoman, size: 27).weight(.light))
                .foregroundStyle(UltronTheme.textDim)
                .fixedSize(horizontal: false, vertical: true)
                .id(greetingSeed)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.5), value: greetingSeed)
            Text(metaLine())
                .font(UltronTheme.Typography.kvLabel())
                .tracking(0.5)
                .foregroundStyle(UltronTheme.textMute)
        }
    }

    // MARK: - Sections

    private var udenforSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(title: "Udenfor", english: "Outside")
            Grid(alignment: .topLeading,
                 horizontalSpacing: UltronTheme.Spacing.gridGap,
                 verticalSpacing: UltronTheme.Spacing.gridGap) {
                GridRow {
                    UltronVejrTile(weather: service.weather)
                        .gridCellFilling()
                    UltronSolTile(
                        weather: service.weather,
                        latitude: service.userCoordinate?.latitude
                    )
                    .gridCellFilling()
                    UltronLuftMaaneTile(
                        airQuality: service.airQuality,
                        moon: service.moon
                    )
                    .gridCellFilling()
                }
            }
        }
    }

    private var dinRuteSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(title: "Din rute", english: "Your route")
            Grid(alignment: .topLeading,
                 horizontalSpacing: UltronTheme.Spacing.gridGap,
                 verticalSpacing: UltronTheme.Spacing.gridGap) {
                GridRow {
                    UltronHjemRuteTile(
                        commute: service.commute,
                        chargers: service.chargers,
                        destinationWeather: service.destinationWeather
                    )
                    .gridCellFilling()
                    UltronTrafikInfoTile(
                        events: service.trafficEvents,
                        totalCount: service.trafficEventsTotalCount,
                        countByCategory: service.trafficEventsCountByCategory
                    )
                    .gridCellFilling()
                }
            }
        }
    }

    private var overOgOmkringSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(title: "Over & omkring", english: "Overhead & around")
            Grid(alignment: .topLeading,
                 horizontalSpacing: UltronTheme.Spacing.gridGap,
                 verticalSpacing: UltronTheme.Spacing.gridGap) {
                GridRow {
                    UltronFlyTile(aircraft: service.aircraftNearby)
                        .gridCellFilling()
                    UltronNyhederTile(newsBySource: service.newsBySource)
                        .gridCellFilling()
                }
            }
        }
    }

    private var dinMaskineSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(title: "Din maskine", english: "Your machine")
            Grid(alignment: .topLeading,
                 horizontalSpacing: UltronTheme.Spacing.gridGap,
                 verticalSpacing: UltronTheme.Spacing.gridGap) {
                GridRow {
                    UltronSystemTile(system: service.systemInfo)
                        .gridCellFilling()
                    UltronNetvaerkTile(system: service.systemInfo)
                        .gridCellFilling()
                    UltronClaudeCodeTile(stats: service.claudeStats)
                        .gridCellFilling()
                }
            }
        }
    }

    // MARK: - Section header

    private func sectionHeader(title: String, english: String) -> some View {
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
        }
    }

    // MARK: - Header copy

    private func greetingHero() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<10:   return "God morgen."
        case 10..<12:  return "God formiddag."
        case 12..<17:  return "God eftermiddag."
        case 17..<21:  return "God aften."
        default:       return "Nat."
        }
    }

    /// Rotating sub-line — picks one of the 200 entries in `GreetingProvider`
    /// via the current `greetingSeed`. Re-rolled by the 20-second timer.
    private func greetingSubline() -> String {
        let nickname = UserDefaults.standard.string(forKey: "userNickname") ?? "P"
        return GreetingProvider.random(name: nickname, seed: greetingSeed).line
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

// MARK: - Grid cell helper

private extension View {
    /// Make a tile stretch to fill the row height its `Grid`-sibling sets,
    /// and take its column's full width. Without this, `Grid` items keep
    /// their intrinsic size and tiles in the same row end up uneven.
    func gridCellFilling() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
