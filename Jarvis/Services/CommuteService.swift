import CoreLocation
import Foundation
import MapKit

/// Reverse-distance commute estimate + Tesla Model 3 AWD 2025 energy usage.
struct CommuteEstimate: Equatable {
    /// Driving time as Apple Maps estimates it, accounting for typical traffic.
    let expectedTravelTime: TimeInterval
    /// Driving distance in meters.
    let distanceMeters: Double
    /// Human-readable from/to labels.
    let fromLabel: String
    let toLabel: String
    /// Tesla Model 3 AWD 2025 energy needed in kWh.
    let teslaKWh: Double

    var distanceKm: Double { distanceMeters / 1000 }

    var prettyTravelTime: String {
        let minutes = Int((expectedTravelTime / 60).rounded())
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60)t \(minutes % 60)m"
    }

    var prettyDistance: String {
        if distanceMeters < 1000 { return "\(Int(distanceMeters)) m" }
        return String(format: "%.1f km", distanceKm)
    }
}

enum CommuteError: LocalizedError {
    case missingHomeAddress
    case missingCurrentLocation
    case geocodeFailed(String)
    case routeFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .missingHomeAddress:
            return "Sæt din hjemadresse i Settings → General for at beregne køretid."
        case .missingCurrentLocation:
            return "Kunne ikke bestemme din nuværende lokation."
        case .geocodeFailed(let address):
            return "Kunne ikke finde adressen '\(address)' på kortet."
        case .routeFailed(let error):
            return "Ruteberegning fejlede: \(error.localizedDescription)"
        }
    }
}

final class CommuteService {
    /// Tesla Model 3 Long Range AWD 2025 — mixed real-world consumption baseline.
    /// EPA rates it at roughly 4.0 mi/kWh (155 Wh/km); real-world mixed driving
    /// tends to be 170–200 Wh/km depending on temperature and speed. 180 Wh/km is
    /// a defensible middle estimate. Cold-weather + highway corrections are a
    /// future refinement (log them here, then add a settings toggle).
    static let teslaModel3AWD2025Efficiency: Double = 0.180  // kWh per km

    func estimate(from origin: CLLocationCoordinate2D, originLabel: String, toAddress address: String) async throws -> CommuteEstimate {
        // 1) Geocode the home address → coordinate.
        let placemarks: [CLPlacemark]
        do {
            placemarks = try await CLGeocoder().geocodeAddressString(address)
        } catch {
            throw CommuteError.geocodeFailed(address)
        }
        guard let destination = placemarks.first?.location?.coordinate else {
            throw CommuteError.geocodeFailed(address)
        }
        let toLabel = placemarks.first?.locality ?? placemarks.first?.name ?? address

        // 2) Ask MapKit for a driving route.
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile
        request.requestsAlternateRoutes = false

        let directions = MKDirections(request: request)
        let response: MKDirections.Response
        do {
            response = try await directions.calculate()
        } catch {
            throw CommuteError.routeFailed(underlying: error)
        }
        guard let route = response.routes.first else {
            throw CommuteError.routeFailed(underlying: NSError(domain: "MapKit", code: 1))
        }

        let distanceKm = route.distance / 1000
        let teslaKWh = distanceKm * Self.teslaModel3AWD2025Efficiency

        return CommuteEstimate(
            expectedTravelTime: route.expectedTravelTime,
            distanceMeters: route.distance,
            fromLabel: originLabel,
            toLabel: toLabel,
            teslaKWh: teslaKWh
        )
    }
}
