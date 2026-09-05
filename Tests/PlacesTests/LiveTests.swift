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

// MARK: - Added 2026-09-05

extension LiveTests {

    /// `nearby` uses `MKLocalPointsOfInterestRequest`, not a text query built
    /// from category names. Measured on the change: 48 results against 25.
    func testNearbyUsesTheDedicatedRequestAndOutdoesATextQuery() async throws {
        try XCTSkipUnless(isEnabled, "set PLACES_LIVE=1 to run")
        let trafalgar = try XCTUnwrap(Coordinate(latitude: 51.5080, longitude: -0.1281))

        let dedicated = try await Places().nearby([.restaurant, .cafe],
                                                  near: trafalgar, radiusMetres: 500, limit: 100)
        let textQuery = try await Places().search("Restaurant Cafe", near: trafalgar,
                                                  radiusMetres: 500,
                                                  categories: [.restaurant, .cafe],
                                                  resultTypes: [.pointOfInterest], limit: 100)

        XCTAssertGreaterThan(dedicated.count, textQuery.count,
                             "the dedicated POI request should beat matching category words")
        XCTAssertTrue(dedicated.allSatisfy { $0.category != nil },
                      "a POI request must return categorised places")
    }

    /// Geocoding fails in MKErrorDomain now, not kCLErrorDomain — one domain
    /// for the whole library.
    func testGeocodingNonsenseIsNoResultsAndNotAnUnexplainedError() async throws {
        try XCTSkipUnless(isEnabled, "set PLACES_LIVE=1 to run")
        do {
            _ = try await Places().geocode("zzqqxx nowhere at all 99999999")
            XCTFail("that is not a place")
        } catch let error as PlacesError {
            guard case .noResults = error else {
                return XCTFail("expected .noResults, got \(error)")
            }
        }
    }

    /// The structured address parts must survive: the modern MapKit address
    /// API offers no postcode or country, and reports the COUNTRY as the
    /// region, so those come from the placemark.
    func testAnAddressKeepsItsPostcodeAndCountry() async throws {
        try XCTSkipUnless(isEnabled, "set PLACES_LIVE=1 to run")
        let results = try await Places().geocode("10 Downing Street, London")
        let place = try XCTUnwrap(results.first)

        XCTAssertEqual(place.postalCode, "SW1A 2AA")
        XCTAssertEqual(place.countryCode, "GB")
        XCTAssertEqual(place.country, "United Kingdom")
        XCTAssertEqual(place.locality, "London", "not \"City of Westminster, London\"")
        XCTAssertEqual(place.administrativeArea, "England",
                       "MKAddressRepresentations.regionName says United Kingdom here — wrong")
        XCTAssertTrue(place.address?.contains("SW1A 2AA") ?? false,
                      "the formatted address should carry the postcode")
    }

    func testSuggestCompletesAPartialQuery() async throws {
        try XCTSkipUnless(isEnabled, "set PLACES_LIVE=1 to run")
        let london = try XCTUnwrap(Coordinate(latitude: 51.5074, longitude: -0.1278))
        let suggestions = try await Places().suggest("Trafalg", near: london, limit: 10)

        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertTrue(suggestions.contains { $0.title.localizedCaseInsensitiveContains("Trafalgar") },
                      "got: \(suggestions.map(\.title))")
        XCTAssertTrue(suggestions.allSatisfy { !$0.searchText.isEmpty },
                      "a suggestion with no search text cannot be acted on")
    }

    /// A cycling request returns a cycling-aware route that MapKit LABELS
    /// automobile. `mode` must report what was asked for.
    func testCyclingReportsCyclingEvenThoughMapKitSaysAutomobile() async throws {
        try XCTSkipUnless(isEnabled, "set PLACES_LIVE=1 to run")
        let from = try XCTUnwrap(Coordinate(latitude: 51.5080, longitude: -0.1281))
        let to = try XCTUnwrap(Coordinate(latitude: 51.5054, longitude: -0.0235))

        let routes = try await Places().route(from: from, to: to, mode: .cycling)
        let route = try XCTUnwrap(routes.first)
        XCTAssertEqual(route.mode, .cycling, "the caller asked for cycling")
        XCTAssertEqual(route.reportedMode, .automobile,
                       "MapKit's own label — if this ever changes, drop the workaround")
    }
}

// MARK: - Added 2026-09-06, from the SDK audit

extension LiveTests {

    /// `.required` confines results to the region; `.preferred` may not.
    func testRequiredRegionPriorityKeepsEveryResultInside() async throws {
        try XCTSkipUnless(isEnabled, "set PLACES_LIVE=1 to run")
        let trafalgar = try XCTUnwrap(Coordinate(latitude: 51.5080, longitude: -0.1281))
        let radius = 400.0
        let required = try await Places().search("pizza", near: trafalgar, radiusMetres: radius,
                                                 regionPriority: .required, limit: 50)
        let preferred = try await Places().search("pizza", near: trafalgar, radiusMetres: radius,
                                                  regionPriority: .preferred, limit: 50)
        // A rectangle of the radius on each side has a corner ~radius·√2 away.
        let furthestRequired = required.compactMap(\.distance).max() ?? 0
        XCTAssertLessThanOrEqual(furthestRequired, radius * 1.5, "required must stay inside the region")
        XCTAssertGreaterThanOrEqual(preferred.compactMap(\.distance).max() ?? 0, furthestRequired,
                                    "preferred is allowed to reach further")
    }

    func testAddressComponentsNarrowAnAddressSearch() async throws {
        try XCTSkipUnless(isEnabled, "set PLACES_LIVE=1 to run")
        let towns = try await Places().search("Richmond", resultTypes: [.address],
                                              addressComponents: [.locality], limit: 20)
        XCTAssertFalse(towns.isEmpty)
        XCTAssertTrue(towns.allSatisfy { $0.category == nil }, "addresses, not businesses")
        XCTAssertTrue(towns.contains { $0.locality?.hasPrefix("Richmond") ?? false }, towns.map { $0.address ?? "?" }.joined(separator: " | "))
    }

    func testSearchResultsCarryABoundingRegionThatContainsThem() async throws {
        try XCTSkipUnless(isEnabled, "set PLACES_LIVE=1 to run")
        let london = try XCTUnwrap(Coordinate(latitude: 51.5074, longitude: -0.1278))
        let results = try await Places().searchResults("coffee", near: london, radiusMetres: 800, limit: 10)
        let region = try XCTUnwrap(results.boundingRegion)
        for place in results.places {
            XCTAssertTrue(region.contains(place.coordinate), "\(place.name ?? "?") lies outside MapKit's own bounding region")
        }
    }

    func testSuggestionsSayWhereTheFragmentMatched() async throws {
        try XCTSkipUnless(isEnabled, "set PLACES_LIVE=1 to run")
        let london = try XCTUnwrap(Coordinate(latitude: 51.5074, longitude: -0.1278))
        let suggestions = try await Places().suggest("Trafalg", near: london, limit: 10)
        let hit = try XCTUnwrap(suggestions.first { $0.title.localizedCaseInsensitiveContains("Trafalgar") })
        XCTAssertFalse(hit.titleHighlights.isEmpty, "MapKit reports highlight ranges; they must survive")
        XCTAssertTrue(hit.markedTitle().lowercased().contains("**trafalg**"), hit.markedTitle())
    }

    /// The identifier a search hands out must resolve back to the same place.
    func testAPlaceCanBeFoundAgainByItsIdentifier() async throws {
        try XCTSkipUnless(isEnabled, "set PLACES_LIVE=1 to run")
        let london = try XCTUnwrap(Coordinate(latitude: 51.5074, longitude: -0.1278))
        let found = try await Places().search("British Museum", near: london, limit: 1)
        let first = try XCTUnwrap(found.first)
        let identifier = try XCTUnwrap(first.identifier, "MapKit provides identifiers on macOS 15+")
        let again = try await Places().place(identifier: identifier)
        XCTAssertEqual(again.name, first.name)
        XCTAssertLessThan(again.coordinate.distance(to: first.coordinate), 50)
    }

    /// `preferredLocale` changes the language of the address strings.
    func testGeocodingHonoursTheRequestedLocale() async throws {
        try XCTSkipUnless(isEnabled, "set PLACES_LIVE=1 to run")
        let englishResults = try await Places().geocode("10 Downing Street, London", locale: Locale(identifier: "en_GB"))
        let germanResults = try await Places().geocode("10 Downing Street, London", locale: Locale(identifier: "de_DE"))
        let english = try XCTUnwrap(englishResults.first)
        let german = try XCTUnwrap(germanResults.first)
        XCTAssertEqual(english.country, "United Kingdom")
        XCTAssertNotEqual(german.country, english.country, "the German locale should name the country in German")
        XCTAssertEqual(english.street, "10 Downing Street", "street is the number and road only")
        XCTAssertEqual(english.shortAddress, "10 Downing Street, London")
        XCTAssertEqual(english.cityWithContext, "London, England")
    }

    func testRouteStepsHaveGeometry() async throws {
        try XCTSkipUnless(isEnabled, "set PLACES_LIVE=1 to run")
        let from = try XCTUnwrap(Coordinate(latitude: 51.5080, longitude: -0.1281))
        let to = try XCTUnwrap(Coordinate(latitude: 51.5194, longitude: -0.1270))
        let routes = try await Places().route(from: from, to: to, mode: .walking)
        let route = try XCTUnwrap(routes.first)
        XCTAssertGreaterThan(route.steps.count, 1)
        XCTAssertTrue(route.steps.dropLast().allSatisfy { !$0.polyline.isEmpty }, "every step but the arrival has geometry")
    }
}
