import SwiftUI

/// Vejr (Weather) tile — Ultron redesign.
///
/// Matches the handoff spec exactly:
/// - Tone: amber (top border + icon-box tint)
/// - 56pt icon box · serif 44pt "7°C" · italic caption
/// - 2-col KV grid: Føles / Vind / Fugtighed / Høj-Lav
/// - Meta: live-dot + location
struct UltronVejrTile: View {
    let weather: WeatherSnapshot?

    var body: some View {
        UltronTile(
            title: "Vejr",
            english: "Weather",
            tone: .amber
        ) {
            if let w = weather {
                VStack(alignment: .leading, spacing: 14) {
                    UltronBigNumberBlock(
                        number: "\(Int(w.current.temperature.rounded()))°",
                        unit: "C",
                        tone: .amber
                    ) {
                        Image(systemName: WeatherCode.symbol(for: w.current.weatherCode))
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(UltronTheme.TileTone.amber.color)
                            .symbolRenderingMode(.hierarchical)
                    }
                    Text(caption(for: w.current.weatherCode))
                        .font(UltronTheme.Typography.caption(size: 13))
                        .foregroundStyle(UltronTheme.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                    UltronKVGrid(pairs: kvPairs(for: w))
                }
            } else {
                loadingPlaceholder
            }
        } meta: {
            if let w = weather {
                UltronMetaRow(text: w.locationLabel, dotColor: UltronTheme.accent, pulsing: true)
            }
        }
    }

    // MARK: - Content helpers

    private func caption(for code: Int) -> String {
        // Elevated, serif-italic style prose. Reuses the existing WMO map
        // but with a slightly more poetic tone than the stock labels.
        switch code {
        case 0:           return "Klart og tørt."
        case 1, 2:        return "Let skyet, ellers roligt."
        case 3:           return "Overskyet, let regn senere."
        case 45, 48:      return "Tåge ligger lavt."
        case 51, 53, 55:  return "Støvregn i luften."
        case 61, 63, 65:  return "Regn gennem dagen."
        case 71, 73, 75:  return "Sne falder stille."
        case 80, 81, 82:  return "Byger på vej."
        case 95, 96, 99:  return "Tordenvejr trækker over."
        default:          return WeatherCode.label(for: code) + "."
        }
    }

    private func kvPairs(for w: WeatherSnapshot) -> [(label: String, value: String)] {
        var pairs: [(label: String, value: String)] = [
            ("Føles",     "\(Int(w.current.feelsLike.rounded()))°"),
            ("Vind",      windDescription(w.current.windSpeed)),
            ("Fugtighed", "\(w.current.humidity) %"),
        ]
        if let today = w.daily.first {
            pairs.append((
                "Høj / Lav",
                "\(Int(today.tempMax.rounded()))° · \(Int(today.tempMin.rounded()))°"
            ))
        }
        return pairs
    }

    private func windDescription(_ mps: Double) -> String {
        // No wind-direction yet on current Weather snapshot — keep it
        // compact until the service gains `windDirection`.
        String(format: "%.0f m/s", mps)
    }

    // MARK: - Loading placeholder

    private var loadingPlaceholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10).fill(UltronTheme.ink3)
                    .frame(width: 56, height: 56)
                RoundedRectangle(cornerRadius: 4).fill(UltronTheme.ink3)
                    .frame(width: 120, height: 44)
            }
            RoundedRectangle(cornerRadius: 4).fill(UltronTheme.ink3)
                .frame(height: 14)
                .frame(maxWidth: 200)
            RoundedRectangle(cornerRadius: 4).fill(UltronTheme.ink3)
                .frame(height: 14)
                .frame(maxWidth: 240)
        }
        .redacted(reason: .placeholder)
    }
}
