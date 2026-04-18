import CoreLocation
import Foundation
import Observation

/// Wraps CLLocationManager for Uptodate mode. Asks for "when in use" permission,
/// exposes an observable `currentCoordinate` + `cityName` (reverse-geocoded), and
/// falls back gracefully to a user-entered city from UserDefaults if the user denies.
@MainActor
@Observable
final class LocationService: NSObject {
    /// Last-known coordinate, or nil if unavailable.
    private(set) var coordinate: CLLocationCoordinate2D?
    /// Reverse-geocoded locality (e.g. "København").
    private(set) var cityName: String?
    /// Current authorization state — the view surfaces "grant access" UI when denied.
    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    /// User-entered fallback city from Settings (e.g. "Aarhus").
    var manualCity: String? {
        get { UserDefaults.standard.string(forKey: Self.manualCityKey) }
        set {
            if let newValue, !newValue.isEmpty {
                UserDefaults.standard.set(newValue, forKey: Self.manualCityKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.manualCityKey)
            }
        }
    }

    /// User's home address — used by Info mode's commute estimate. Free-form string,
    /// gets geocoded on each Info refresh.
    var homeAddress: String? {
        get { UserDefaults.standard.string(forKey: Self.homeAddressKey) }
        set {
            if let newValue, !newValue.isEmpty {
                UserDefaults.standard.set(newValue, forKey: Self.homeAddressKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.homeAddressKey)
            }
        }
    }

    private static let manualCityKey = "jarvisManualCity"
    private static let homeAddressKey = "jarvisHomeAddress"

    private let manager = CLLocationManager()
    private var lastRefresh: Date?
    private var pendingContinuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        authorization = manager.authorizationStatus
    }

    /// Ask for authorization. Safe to call repeatedly — macOS suppresses duplicate prompts.
    func requestAuthorization() {
        guard authorization == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    /// Refresh the current location. Waits up to 5 s for a fix. Returns nil if the user
    /// denied access or no fix is available — in either case the caller should use
    /// `manualCity` instead (or prompt the user to set one).
    func refresh() async -> CLLocationCoordinate2D? {
        // Cache: avoid repeated requests within 60 s.
        if let coordinate, let last = lastRefresh, Date().timeIntervalSince(last) < 60 {
            return coordinate
        }

        switch authorization {
        case .denied, .restricted:
            return nil
        case .notDetermined:
            requestAuthorization()
            return nil
        default:
            break
        }

        return await withCheckedContinuation { continuation in
            self.pendingContinuation = continuation
            self.manager.requestLocation()
            // Safety net — CLLocation can hang on first-run.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(5))
                if let pending = self.pendingContinuation {
                    self.pendingContinuation = nil
                    pending.resume(returning: self.coordinate)
                }
            }
        }
    }

    /// Resolve a manual city string to a coordinate via CLGeocoder.
    func geocodeManual(_ city: String) async -> (CLLocationCoordinate2D, String)? {
        do {
            let placemarks = try await CLGeocoder().geocodeAddressString(city)
            guard let placemark = placemarks.first,
                  let location = placemark.location else { return nil }
            let name = placemark.locality ?? placemark.name ?? city
            return (location.coordinate, name)
        } catch {
            LoggingService.shared.log("Manual geocode failed for '\(city)': \(error)", level: .warning)
            return nil
        }
    }

    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            Task { @MainActor [weak self] in
                self?.cityName = placemarks?.first?.locality ?? placemarks?.first?.name
            }
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coord = locations.last?.coordinate else { return }
        Task { @MainActor in
            self.coordinate = coord
            self.lastRefresh = Date()
            self.reverseGeocode(coord)
            if let pending = self.pendingContinuation {
                self.pendingContinuation = nil
                pending.resume(returning: coord)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            LoggingService.shared.log("Location update failed: \(error.localizedDescription)", level: .warning)
            if let pending = self.pendingContinuation {
                self.pendingContinuation = nil
                pending.resume(returning: self.coordinate)
            }
        }
    }
}
