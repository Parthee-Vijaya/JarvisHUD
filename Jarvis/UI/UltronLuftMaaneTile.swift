import SwiftUI

/// Luft & Måne (Air & Moon) tile — Ultron redesign.
///
/// Matches the handoff spec:
/// - Tone: lilac (top border + icon-box tint)
/// - Icon: moon-phase SF Symbol
/// - Big number: AQI value ("28 AQI")
/// - Italic caption: "Luft god · måne tiltagende" (derived from current bands)
/// - 2-col KV grid: PM 2.5, UV-indeks, Måne %, Næste fuldmåne
struct UltronLuftMaaneTile: View {
    let airQuality: AirQualitySnapshot?
    let moon: MoonSnapshot

    var body: some View {
        UltronTile(
            title: "Luft & Måne",
            english: "Air & Moon",
            tone: .lilac
        ) {
            VStack(alignment: .leading, spacing: 14) {
                UltronBigNumberBlock(
                    number: aqiNumberText,
                    unit: "AQI",
                    tone: .lilac
                ) {
                    Image(systemName: moon.phase.symbol)
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(UltronTheme.TileTone.lilac.color)
                        .symbolRenderingMode(.hierarchical)
                }
                Text(caption)
                    .font(UltronTheme.Typography.caption(size: 13))
                    .foregroundStyle(UltronTheme.textDim)
                    .fixedSize(horizontal: false, vertical: true)
                UltronKVGrid(pairs: kvPairs)
            }
        }
    }

    // MARK: - Big number

    private var aqiNumberText: String {
        if let aqi = airQuality?.europeanAQI {
            return "\(aqi)"
        }
        return "—"
    }

    // MARK: - Caption

    /// "Luft god · måne tiltagende" — derived from the AQI band label and the
    /// moon phase label, both lowercased. Falls back to a neutral default.
    private var caption: String {
        let airLabel: String? = {
            guard let aq = airQuality, aq.aqiBand != .unknown else { return nil }
            return aq.aqiBand.label.lowercased()
        }()
        let moonLabel = moon.phase.label.lowercased()
        if let air = airLabel {
            return "Luft \(air) · måne \(moonLabel)"
        }
        return "Måne \(moonLabel)"
    }

    // MARK: - KV pairs

    private var kvPairs: [(label: String, value: String)] {
        var pairs: [(label: String, value: String)] = []

        if let pm25 = airQuality?.pm25 {
            pairs.append(("PM 2.5", String(format: "%.0f µg/m³", pm25)))
        } else {
            pairs.append(("PM 2.5", "—"))
        }

        if let uv = airQuality?.uvIndex {
            let band = airQuality?.uvBand.label.lowercased() ?? ""
            let value = String(format: "%.1f", uv)
            pairs.append(("UV-indeks", band.isEmpty ? value : "\(value) \(band)"))
        } else {
            pairs.append(("UV-indeks", "—"))
        }

        let direction = moonDirectionWord(phase: moon.phase)
        pairs.append(("Måne", "\(moon.illuminationPercent) % \(direction)"))

        let df = DateFormatter()
        df.locale = Locale(identifier: "da_DK")
        df.dateFormat = "d. MMM"
        pairs.append(("Næste fuldmåne", df.string(from: moon.nextFullMoon)))

        return pairs
    }

    /// Map the moon phase to a short Danish direction word used in the KV grid
    /// ("74 % tiltagende" / "32 % aftagende").
    private func moonDirectionWord(phase: MoonSnapshot.Phase) -> String {
        switch phase {
        case .newMoon, .waxingCrescent, .firstQuarter, .waxingGibbous:
            return "tiltagende"
        case .fullMoon:
            return "fuld"
        case .waningGibbous, .lastQuarter, .waningCrescent:
            return "aftagende"
        }
    }
}
