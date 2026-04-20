import SwiftUI

/// Hjem · Rute (Home · Route) tile — Ultron redesign.
///
/// Matches the handoff spec:
/// - Tone: rose (top border + icon-box tint)
/// - 6-col span, 2-col internal: 200pt spec column + live MapKit view
/// - Big number: expected travel time in minutes, italic ETA caption
/// - KV grid: Afstand / Normal / Tesla / Dest. / Ladere
/// - Meta: warn-dot + "+N min forsinkelse" when delayed, else ok-dot "Fri bane"
struct UltronHjemRuteTile: View {
    let commute: CommuteEstimate?
    let chargers: [ChargerLocation]
    let destinationWeather: WeatherSnapshot?

    var body: some View {
        UltronTile(
            title: "Hjem · Rute",
            english: "Home · Route",
            tone: .rose
        ) {
            if let c = commute {
                HStack(alignment: .top, spacing: 18) {
                    specColumn(c)
                        .frame(width: 200, alignment: .leading)
                    mapColumn(c)
                        .frame(maxWidth: .infinity)
                }
            } else {
                loadingPlaceholder
            }
        } meta: {
            EmptyView()
        } footer: {
            if let c = commute {
                footerMeta(for: c)
            }
        }
    }

    // MARK: - Spec column (200pt)

    private func specColumn(_ c: CommuteEstimate) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            UltronBigNumberBlock(
                number: "\(Int((c.expectedTravelTime / 60).rounded()))",
                unit: "min",
                tone: .rose
            ) {
                Image(systemName: "house.fill")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(UltronTheme.TileTone.rose.color)
                    .symbolRenderingMode(.hierarchical)
            }
            Text("ETA \(etaString(for: c))")
                .font(UltronTheme.Typography.caption(size: 15))
                .foregroundStyle(UltronTheme.textDim)
                .fixedSize(horizontal: false, vertical: true)
            UltronKVGrid(pairs: kvPairs(for: c), columns: 1)
        }
    }

    // MARK: - Map column

    private func mapColumn(_ c: CommuteEstimate) -> some View {
        CommuteMapView(
            origin: c.origin,
            destination: c.destination,
            coordinates: c.routeCoordinates,
            chargers: chargers
        )
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(UltronTheme.lineSoft, lineWidth: 1)
        )
    }

    // MARK: - KV pairs

    private func kvPairs(for c: CommuteEstimate) -> [(label: String, value: String)] {
        var pairs: [(label: String, value: String)] = []
        pairs.append(("Afstand", c.prettyDistance))
        if let baseline = c.baselineTravelTime {
            let baselineMin = Int((baseline / 60).rounded())
            pairs.append(("Normal", "\(baselineMin) min"))
        }
        pairs.append((
            "Tesla",
            String(format: "%.1f kWh · %.0f kr", c.teslaKWh, c.teslaKWh * 3.5)
        ))
        if let w = destinationWeather {
            let temp = Int(w.current.temperature.rounded())
            let label = WeatherCode.label(for: w.current.weatherCode).lowercased()
            pairs.append(("Dest.", "\(temp)° \(label)"))
        } else if !c.toLabel.isEmpty {
            pairs.append(("Dest.", c.toLabel))
        }
        pairs.append(("Ladere", "\(chargers.count) på ruten"))
        return pairs
    }

    // MARK: - Helpers

    private func etaString(for c: CommuteEstimate) -> String {
        let arrival = Date().addingTimeInterval(c.expectedTravelTime)
        let df = DateFormatter()
        df.locale = Locale(identifier: "da_DK")
        df.dateFormat = "HH:mm"
        return df.string(from: arrival)
    }

    @ViewBuilder
    private func footerMeta(for c: CommuteEstimate) -> some View {
        if let baseline = c.baselineTravelTime,
           c.expectedTravelTime - baseline > 120 {
            let delayMin = Int(((c.expectedTravelTime - baseline) / 60).rounded())
            UltronMetaRow(
                text: "+\(delayMin) min forsinkelse",
                dotColor: UltronTheme.warn,
                pulsing: false
            )
        } else {
            UltronMetaRow(
                text: "Fri bane",
                dotColor: UltronTheme.ok,
                pulsing: false
            )
        }
    }

    // MARK: - Loading placeholder

    private var loadingPlaceholder: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 10).fill(UltronTheme.ink3)
                    .frame(width: 160, height: 56)
                RoundedRectangle(cornerRadius: 4).fill(UltronTheme.ink3)
                    .frame(height: 14).frame(maxWidth: 140)
                ForEach(0..<4) { _ in
                    RoundedRectangle(cornerRadius: 4).fill(UltronTheme.ink3)
                        .frame(height: 12)
                }
            }
            .frame(width: 200, alignment: .leading)
            RoundedRectangle(cornerRadius: 10).fill(UltronTheme.ink3)
                .frame(height: 220)
        }
        .redacted(reason: .placeholder)
    }
}
