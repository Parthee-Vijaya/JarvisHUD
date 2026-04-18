import CoreLocation
import Foundation
import Observation

/// Coordinates weather + news fetches for Uptodate mode. Kicks off both in parallel
/// so the panel pops in quickly. Caches the last snapshot in memory so re-opening
/// within 5 min doesn't refetch.
@MainActor
@Observable
final class UpdatesService {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var state: LoadState = .idle
    private(set) var weather: WeatherSnapshot?
    private(set) var news: [NewsHeadline.Source: [NewsHeadline]] = [:]
    private(set) var lastRefresh: Date?

    private let locationService: LocationService
    private let weatherService = WeatherService()
    private let newsService = NewsService()
    private let cacheTTL: TimeInterval = 5 * 60

    init(locationService: LocationService) {
        self.locationService = locationService
    }

    /// Refresh everything. `force=true` bypasses the in-memory cache.
    func refresh(force: Bool = false) async {
        if !force, let last = lastRefresh, Date().timeIntervalSince(last) < cacheTTL, state == .loaded {
            return
        }
        state = .loading

        async let weatherTask = loadWeather()
        async let newsTask = newsService.fetchAll()

        let (weatherResult, newsResult) = await (weatherTask, newsTask)

        self.weather = weatherResult
        self.news = newsResult
        self.lastRefresh = Date()
        self.state = .loaded
    }

    private func loadWeather() async -> WeatherSnapshot? {
        // 1) Manual city overrides everything if set.
        if let manual = locationService.manualCity, !manual.isEmpty {
            if let (coord, label) = await locationService.geocodeManual(manual) {
                return try? await weatherService.fetch(for: coord, locationLabel: label)
            }
        }
        // 2) Try CoreLocation.
        if let coord = await locationService.refresh() {
            let label = locationService.cityName ?? "Din lokation"
            return try? await weatherService.fetch(for: coord, locationLabel: label)
        }
        // 3) Default to Copenhagen if nothing else works so the user isn't greeted with a blank card.
        let fallback = CLLocationCoordinate2D(latitude: 55.6761, longitude: 12.5683)
        return try? await weatherService.fetch(for: fallback, locationLabel: "København (fallback)")
    }
}
