//
//  LiveTests.swift
//  PlacesTests
//
//  Created by David Sherlock on 2026.
//
//  Live checks against MapKit itself. Skipped unless PLACES_LIVE=1, because
//  MapKit throttles per app and a test suite should not spend that budget on
//  every run. No key, no entitlement — anyone can run these.
//
//      PLACES_LIVE=1 swift test --filter LiveTests
//

import Foundation
import XCTest
@testable import Places

final class LiveTests: XCTestCase {

    private var isEnabled: Bool { ProcessInfo.processInfo.environment["PLACES_LIVE"] == "1" }
    private let coventGarden = Coordinate(latitude: 51.5142, longitude: -0.1237)!
    private let paddington = Coordinate(latitude: 51.5154, longitude: -0.1755)!
    private let liverpoolStreet = Coordinate(latitude: 51.5178, longitude: -0.0823)!

    func testSearchFindsPlacesAndMeasuresThem() async throws {
        try XCTSkipUnless(isEnabled, "set PLACES_LIVE=1 to run")

        let places = try await Places().search("coffee", near: coventGarden,
                                               radiusMetres: 1_000, limit: 10)
        XCTAssertFalse(places.isEmpty)
        let first = try XCTUnwrap(places.first)
        XCTAssertNotNil(first.name)
        XCTAssertNotNil(first.address, "an address on either the modern or the legacy API")

        // Nearest first, and every one inside the radius we asked for.
        let distances = places.compactMap(\.distance)
        XCTAssertEqual(distances, distances.sorted(), "results must come back nearest first")
        for place in places {
            XCTAssertLessThan(place.distance ?? 0, 3_000, "\(place.name ?? "?") is outside the area")
        }
    }

    func testNearbyByCategoryReturnsThatCategory() async throws {
        try XCTSkipUnless(isEnabled, "set PLACES_LIVE=1 to run")

        let places = try await Places().nearby([.restaurant], near: coventGarden,
                                               radiusMetres: 800, limit: 10)
        XCTAssertFalse(places.isEmpty)
        // The filter is MapKit's, so this is really checking we built it right.
        let restaurants = places.filter { $0.category == .restaurant }
        XCTAssertFalse(restaurants.isEmpty, "got: \(places.compactMap { $0.category?.name })")
    }

    func testRoutingReturnsStepsTollsAndAdvisories() async throws {
        try XCTSkipUnless(isEnabled, "set PLACES_LIVE=1 to run")

        let bristol = Coordinate(latitude: 51.4545, longitude: -2.5879)!
        let london = Coordinate(latitude: 51.5074, longitude: -0.1276)!
        let routes = try await Places().route(from: london, to: bristol, mode: .automobile)

        XCTAssertFalse(routes.isEmpty)
        let best = try XCTUnwrap(routes.first)
        XCTAssertGreaterThan(best.distance, 100_000, "London to Bristol is about 190 km")
        XCTAssertGreaterThan(best.travelTime, 3_600)
        XCTAssertFalse(best.steps.isEmpty)
        XCTAssertFalse(best.name.isEmpty)
        XCTAssertEqual(best.mode, .automobile)
        XCTAssertFalse(best.polyline.isEmpty)
        XCTAssertLessThanOrEqual(best.polyline.count, Places.defaultPolylineLimit,
                                 "the geometry must be thinned to the limit")
        // The ends of a thinned line must still be the ends of the route.
        XCTAssertLessThan(best.polyline.first!.distance(to: london), 5_000)
        XCTAssertLessThan(best.polyline.last!.distance(to: bristol), 5_000)
    }

    /// Apple's header says transit is ETA-only. This pins both halves of that.
    func testTransitGivesAnEstimateButRefusesAStepList() async throws {
        try XCTSkipUnless(isEnabled, "set PLACES_LIVE=1 to run")
        let places = Places()

        let estimate = try await places.estimate(from: paddington, to: liverpoolStreet, mode: .transit)
        XCTAssertGreaterThan(estimate.travelTime, 0)
        XCTAssertGreaterThan(estimate.distance, 0)
        XCTAssertEqual(estimate.mode, .transit)
        XCTAssertGreaterThan(estimate.arrival, estimate.departure)

        do {
            _ = try await places.route(from: paddington, to: liverpoolStreet, mode: .transit)
            XCTFail("MapKit does not produce transit steps")
        } catch let error as PlacesError {
            guard case .routeStepsUnavailable(.transit) = error else {
                return XCTFail("expected .routeStepsUnavailable, got \(error)")
            }
        }
    }

    func testEveryModeEstimates() async throws {
        try XCTSkipUnless(isEnabled, "set PLACES_LIVE=1 to run")
        for mode in [TransportMode.automobile, .walking, .cycling, .transit] {
            let estimate = try await Places().estimate(from: paddington, to: liverpoolStreet, mode: mode)
            XCTAssertGreaterThan(estimate.travelTime, 0, "\(mode.rawValue)")
        }
    }

    func testGeocodingBothWays() async throws {
        try XCTSkipUnless(isEnabled, "set PLACES_LIVE=1 to run")
        let places = Places()

        let forward = try await places.geocode("10 Downing Street, London")
        let found = try XCTUnwrap(forward.first)
        XCTAssertEqual(found.postalCode, "SW1A 2AA")
        XCTAssertEqual(found.countryCode, "GB")
        XCTAssertLessThan(found.coordinate.distance(to: Coordinate(latitude: 51.5035, longitude: -0.1277)!), 500)

        let back = try await places.reverseGeocode(found.coordinate)
        XCTAssertEqual(back.first?.locality, "London")
    }

    /// The nonsense must contain NO DIGITS. A geocoder is fuzzy by design and
    /// a number will match a postcode somewhere: "zzzqqq nowhere 99999"
    /// resolves to Moyahua de Estrada, Mexico — postcode 99999. Measured
    /// 2026-09-05, and a good reminder that "no results" is harder to provoke
    /// than it looks.
    func testNothingMatchedIsItsOwnError() async throws {
        try XCTSkipUnless(isEnabled, "set PLACES_LIVE=1 to run")
        do {
            let found = try await Places().geocode("aaaaaaaa bbbbbbbb cccccccc")
            XCTFail("that is not a place, got \(found.compactMap(\.name))")
        } catch let error as PlacesError {
            XCTAssertEqual(error, .noResults)
        }
    }
}
