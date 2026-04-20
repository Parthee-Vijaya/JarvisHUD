import SwiftUI

/// Sol (Sun) tile — Ultron redesign.
///
/// Matches the handoff spec:
/// - Tone: cream (top border + icon-box tint)
/// - Icon: `sun.max.fill` in accent cyan-blue
/// - Big number: daylight length ("13h 46m")
/// - Italic caption: "Dagslys i dag"
/// - Mono sunrise · transit · sunset row
/// - 2-col KV grid: Solopgang, Solnedgang, Næste helligdag
/// - Meta: solstice delta ("Forår · +3m 42s" / "Vinter · −2m 10s")
struct UltronSolTile: View {
    let weather: WeatherSnapshot?
    /// Latitude used for the solstice daylight-delta calculation. If nil the
    /// meta row falls back to a neutral label.
    let latitude: Double?

    var body: some View {
        UltronTile(
            title: "Sol",
            english: "Sun",
            tone: .cream
        ) {
            if let today = weather?.daily.first, let daylight = today.daylight {
                VStack(alignment: .leading, spacing: 14) {
                    UltronBigNumberBlock(
                        number: formattedDaylight(daylight),
                        unit: nil,
                        tone: .cream
                    ) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(UltronTheme.accent)
                            .symbolRenderingMode(.hierarchical)
                    }
                    Text("Dagslys i dag")
                        .font(UltronTheme.Typography.caption(size: 13))
                        .foregroundStyle(UltronTheme.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                    if let sunrise = today.sunrise, let sunset = today.sunset {
                        sunTimesRow(sunrise: sunrise, sunset: sunset)
                    }
                    UltronKVGrid(pairs: kvPairs(today: today))
                }
            } else {
                loadingPlaceholder
            }
        } meta: {
            EmptyView()
        } footer: {
            if let metaText = solsticeMetaText() {
                UltronMetaRow(
                    text: metaText,
                    dotColor: UltronTheme.accent,
                    pulsing: false
                )
            }
        }
    }

    // MARK: - Sun-times row (sunrise · transit · sunset)

    private func sunTimesRow(sunrise: Date, sunset: Date) -> some View {
        let transit = Date(timeIntervalSince1970:
            (sunrise.timeIntervalSince1970 + sunset.timeIntervalSince1970) / 2)
        let format: (Date) -> String = { date in
            let df = DateFormatter()
            df.locale = Locale(identifier: "da_DK")
            df.dateFormat = "HH:mm"
            return df.string(from: date)
        }
        return Text("\(format(sunrise))  ·  \(format(transit))  ·  \(format(sunset))")
            .font(UltronTheme.Typography.kvLabel())
            .foregroundStyle(UltronTheme.textMute)
    }

    // MARK: - KV pairs

    private func kvPairs(today: WeatherSnapshot.DailyPoint) -> [(label: String, value: String)] {
        var pairs: [(label: String, value: String)] = []
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "da_DK")
        timeFormatter.dateFormat = "HH:mm"

        if let sunrise = today.sunrise {
            pairs.append(("Solopgang", timeFormatter.string(from: sunrise)))
        }
        if let sunset = today.sunset {
            pairs.append(("Solnedgang", timeFormatter.string(from: sunset)))
        }
        if let next = DanishHolidays.next() {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "da_DK")
            dateFormatter.dateFormat = "d. MMM"
            pairs.append(("Næste helligdag",
                          "\(next.name) · \(dateFormatter.string(from: next.date))"))
        }
        return pairs
    }

    // MARK: - Solstice delta

    /// Builds "Forår · +3m 42s" or "Vinter · −2m 10s" from today's daylight vs
    /// the most recent solstice's daylight at the user's latitude.
    private func solsticeMetaText() -> String? {
        guard let today = weather?.daily.first,
              let todayDaylight = today.daylight,
              let latitude else { return nil }
        let solstice = SolarDateMath.lastSolstice(before: Date(), latitude: latitude)
        let delta = todayDaylight - solstice.daylightSeconds
        let season = solstice.isWinter ? "Forår" : "Vinter"
        let absSeconds = Int(abs(delta))
        let mins = absSeconds / 60
        let secs = absSeconds % 60
        let sign = delta >= 0 ? "+" : "−"
        return "\(season) · \(sign)\(mins)m \(secs)s"
    }

    // MARK: - Helpers

    private func formattedDaylight(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hrs = total / 3600
        let mins = (total % 3600) / 60
        return "\(hrs)h \(mins)m"
    }

    // MARK: - Loading placeholder

    private var loadingPlaceholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10).fill(UltronTheme.ink3)
                    .frame(width: 56, height: 56)
                RoundedRectangle(cornerRadius: 4).fill(UltronTheme.ink3)
                    .frame(width: 140, height: 44)
            }
            RoundedRectangle(cornerRadius: 4).fill(UltronTheme.ink3)
                .frame(height: 14)
                .frame(maxWidth: 180)
            RoundedRectangle(cornerRadius: 4).fill(UltronTheme.ink3)
                .frame(height: 14)
                .frame(maxWidth: 220)
        }
        .redacted(reason: .placeholder)
    }
}
