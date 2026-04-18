import XCTest
@testable import Jarvis

final class CommuteServiceTests: XCTestCase {
    func testTeslaEfficiencyConstant() {
        // 0.180 kWh/km is the tuned Model 3 AWD 2025 mixed-driving value. If
        // this changes we want the adjustment to be deliberate.
        XCTAssertEqual(CommuteService.teslaModel3AWD2025Efficiency, 0.180, accuracy: 0.0001)
    }

    func testTeslaKWhMath() {
        let estimate = CommuteEstimate(
            expectedTravelTime: 23 * 60,
            distanceMeters: 14_000,
            fromLabel: "A",
            toLabel: "B",
            teslaKWh: 14 * CommuteService.teslaModel3AWD2025Efficiency
        )
        XCTAssertEqual(estimate.distanceKm, 14)
        XCTAssertEqual(estimate.teslaKWh, 2.52, accuracy: 0.01)
    }

    func testPrettyTravelTimeUnderAnHour() {
        let estimate = CommuteEstimate(expectedTravelTime: 45 * 60, distanceMeters: 10_000,
                                       fromLabel: "", toLabel: "", teslaKWh: 0)
        XCTAssertEqual(estimate.prettyTravelTime, "45 min")
    }

    func testPrettyTravelTimeMultiHour() {
        let estimate = CommuteEstimate(expectedTravelTime: 2 * 3600 + 15 * 60,
                                       distanceMeters: 10_000, fromLabel: "", toLabel: "", teslaKWh: 0)
        XCTAssertEqual(estimate.prettyTravelTime, "2t 15m")
    }

    func testPrettyDistanceMeters() {
        let estimate = CommuteEstimate(expectedTravelTime: 60, distanceMeters: 350,
                                       fromLabel: "", toLabel: "", teslaKWh: 0)
        XCTAssertEqual(estimate.prettyDistance, "350 m")
    }

    func testPrettyDistanceKilometers() {
        let estimate = CommuteEstimate(expectedTravelTime: 60, distanceMeters: 14_500,
                                       fromLabel: "", toLabel: "", teslaKWh: 0)
        XCTAssertEqual(estimate.prettyDistance, "14.5 km")
    }
}
