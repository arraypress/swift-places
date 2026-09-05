//
//  PlacesTests.swift
//  PlacesTests
//
//  Created by David Sherlock on 2026.
//
//  Offline. MapKit itself cannot be faked, so what is pinned here is
//  everything around it: the category table generated from Apple's header,
//  coordinate parsing, the filter, polyline thinning, and the two error
//  domains.
//

import CoreLocation
import Foundation
import MapKit
import XCTest
@testable import Places

final class PlacesTests: XCTestCase {

    // MARK: - Categories

    /// Generated from MKPointOfInterestCategory.h, so this is really asserting
    /// the generator did not silently produce an empty or broken table.
    func testEveryCategoryMapsToARealMapKitValue() {
        XCTAssertEqual(PointOfInterest.allCases.count, 84, "the SDK ships 84 categories")
        for poi in PointOfInterest.allCases {
            XCTAssertTrue(poi.rawValue.hasPrefix("MKPOICategory"), poi.rawValue)
            XCTAssertEqual(poi.category.rawValue, poi.rawValue)
            XCTAssertFalse(poi.name.isEmpty)
            XCTAssertFalse(poi.displayName.isEmpty)
        }
    }

    /// Built from the raw string rather than the static constant, so that
    /// categories gated to a newer OS still compile and compare equal.
    func testACategoryBuiltFromItsStringEqualsApplesConstant() {
        XCTAssertEqual(PointOfInterest.restaurant.category, .restaurant)
        XCTAssertEqual(PointOfInterest.evCharger.category, .evCharger)
        XCTAssertEqual(PointOfInterest.nationalPark.category, .nationalPark)
        XCTAssertEqual(PointOfInterest.restaurant.rawValue, "MKPOICategoryRestaurant")
    }

    func testAcronymsAreCasedTheWaySwiftWouldWriteThem() {
        XCTAssertEqual(PointOfInterest.atm.rawValue, "MKPOICategoryATM")
        XCTAssertEqual(PointOfInterest.evCharger.rawValue, "MKPOICategoryEVCharger")
        XCTAssertEqual(PointOfInterest.rvPark.rawValue, "MKPOICategoryRVPark")
    }

    func testCategoryAliasesAcceptWhatSomeoneWouldType() {
        XCTAssertEqual(PointOfInterest(alias: "restaurant"), .restaurant)
        XCTAssertEqual(PointOfInterest(alias: "gas-station"), .gasStation)
        XCTAssertEqual(PointOfInterest(alias: "Gas Station"), .gasStation)
        XCTAssertEqual(PointOfInterest(alias: "EV Charger"), .evCharger)
        XCTAssertEqual(PointOfInterest(alias: "MKPOICategoryCafe"), .cafe)
        XCTAssertNil(PointOfInterest(alias: "teleporter"))
    }

    func testACategoryFromMapKitRoundTrips() {
        XCTAssertEqual(PointOfInterest(MKPointOfInterestCategory.museum), .museum)
        XCTAssertNil(PointOfInterest(MKPointOfInterestCategory(rawValue: "MKPOICategoryNotAThing")))
    }

    func testDisplayNamesSpaceTheWords() {
        XCTAssertEqual(PointOfInterest.gasStation.displayName, "Gas Station")
        XCTAssertEqual(PointOfInterest.evCharger.displayName, "EVCharger")
        XCTAssertEqual(PointOfInterest.cafe.displayName, "Cafe")
    }

    // MARK: - Filter

    /// MapKit's filter is including OR excluding, never both.
    func testTheFilterPrefersIncludingAndIsNilWhenUnconstrained() {
        let including = Places.filter(including: [.restaurant, .cafe], excluding: [.bank])
        XCTAssertNotNil(including)
        XCTAssertEqual(including?.includes(.restaurant), true)
        XCTAssertEqual(including?.includes(.bank), false, "including wins; the exclusions are dropped")

        let excluding = Places.filter(including: [], excluding: [.bank])
        XCTAssertEqual(excluding?.excludes(.bank), true)

        XCTAssertNil(Places.filter(including: [], excluding: []), "no filter means no restriction")
    }

    // MARK: - Coordinates

    func testACoordinateRefusesImpossibleNumbers() {
        XCTAssertNotNil(Coordinate(latitude: 51.5, longitude: -0.12))
        XCTAssertNotNil(Coordinate(latitude: -90, longitude: 180), "the extremes are valid")
        XCTAssertNil(Coordinate(latitude: 91, longitude: 0))
        XCTAssertNil(Coordinate(latitude: 0, longitude: 181))
        XCTAssertNil(Coordinate(latitude: .nan, longitude: 0))
        XCTAssertNil(Coordinate(latitude: .infinity, longitude: 0))
    }

    /// One argument, because a leading minus is a flag before it is a number.
    func testACoordinateParsesFromOneCommaSeparatedString() {
        XCTAssertEqual(Coordinate("51.5074,-0.1276")?.longitude ?? 0, -0.1276, accuracy: 1e-6)
        XCTAssertNotNil(Coordinate("51.5074, -0.1276"), "a space after the comma is fine")
        XCTAssertNotNil(Coordinate("-33.9 151.2"), "so is a space instead of a comma")
        XCTAssertNil(Coordinate("51.5074"))
        XCTAssertNil(Coordinate("north,west"))
        XCTAssertNil(Coordinate(""))
    }

    func testDistanceIsMetresAlongTheSurface() {
        let london = Coordinate(latitude: 51.5074, longitude: -0.1276)!
        let bristol = Coordinate(latitude: 51.4545, longitude: -2.5879)!
        XCTAssertEqual(london.distance(to: bristol) / 1000, 171, accuracy: 5, "about 171 km as the crow flies")
        XCTAssertEqual(london.distance(to: london), 0, accuracy: 0.001)
    }

    func testARegionIsTwiceTheRadiusAcross() {
        let region = Coordinate(latitude: 51.5, longitude: 0)!.region(radiusMetres: 1_000)
        XCTAssertEqual(region.center.latitude, 51.5, accuracy: 1e-9)
        // A degree of latitude is ~111 km, so 2 km spans ~0.018°.
        XCTAssertEqual(region.span.latitudeDelta, 0.018, accuracy: 0.002)
    }

    // MARK: - Transport modes

    /// Apple's header: transit is "Only supported for ETA calculations".
    func testOnlyTransitLacksRouteSteps() {
        XCTAssertFalse(TransportMode.transit.supportsRouteSteps)
        for mode in [TransportMode.automobile, .walking, .cycling, .any] {
            XCTAssertTrue(mode.supportsRouteSteps, mode.rawValue)
        }
        // But every mode can be estimated — that is the point of the split.
        XCTAssertTrue(TransportMode.allCases.allSatisfy(\.supportsEstimate))
    }

    func testModeAliasesReadLikeSpeech() {
        XCTAssertEqual(TransportMode(alias: "car"), .automobile)
        XCTAssertEqual(TransportMode(alias: "drive"), .automobile)
        XCTAssertEqual(TransportMode(alias: "foot"), .walking)
        XCTAssertEqual(TransportMode(alias: "bike"), .cycling)
        XCTAssertEqual(TransportMode(alias: "tube"), .transit)
        XCTAssertEqual(TransportMode(alias: "bus"), .transit)
        XCTAssertNil(TransportMode(alias: "teleport"))
    }

    func testAModeIsReadBackFromMapKitsOptionSet() {
        XCTAssertEqual(TransportMode(transportType: .automobile), .automobile)
        XCTAssertEqual(TransportMode(transportType: .cycling), .cycling)
        XCTAssertEqual(TransportMode(transportType: .transit), .transit)
        XCTAssertEqual(TransportMode(transportType: []), .any, "an empty set is not a mode")
    }

    // MARK: - Result types

    func testPhysicalFeatureIsOnlyRequestedWhereItExists() {
        // It arrived in macOS 15 / iOS 18; below that it must be dropped
        // rather than sent as an unknown bit.
        let types = ResultTypes.all.searchResultType
        XCTAssertTrue(types.contains(.address))
        XCTAssertTrue(types.contains(.pointOfInterest))
        if #available(macOS 15.0, iOS 18.0, *) {
            XCTAssertTrue(types.contains(.physicalFeature))
        }
    }

    // MARK: - Polyline thinning

    func testThinningKeepsBothEndsAndHitsTheLimit() {
        let points = (0..<1_000).map {
            CLLocationCoordinate2D(latitude: 51.0 + Double($0) / 10_000, longitude: -0.1)
        }
        let polyline = MKPolyline(coordinates: points, count: points.count)

        let thinned = Route.coordinates(of: polyline, limit: 100)
        XCTAssertEqual(thinned.count, 100)
        XCTAssertEqual(thinned.first?.latitude ?? 0, 51.0, accuracy: 1e-9, "the start must survive")
        XCTAssertEqual(thinned.last?.latitude ?? 0, points.last!.latitude, accuracy: 1e-9,
                       "and so must the end — a line that stops short is worse than none")

        XCTAssertEqual(Route.coordinates(of: polyline, limit: 0).count, 1_000, "zero means every point")
        XCTAssertEqual(Route.coordinates(of: polyline, limit: 5_000).count, 1_000,
                       "a limit above the count changes nothing")
    }

    // MARK: - Errors

    /// Search fails in MKErrorDomain, geocoding in kCLErrorDomain. Reading
    /// only the first reports "no such address" as an unexplained failure.
    func testBothErrorDomainsAreUnderstood() {
        let mapKitNoResult = NSError(domain: MKErrorDomain, code: 4, userInfo: nil) // placemarkNotFound
        XCTAssertEqual(PlacesError.from(mapKitNoResult), .noResults)

        let throttled = NSError(domain: MKErrorDomain, code: 3, userInfo: nil) // loadingThrottled
        XCTAssertEqual(PlacesError.from(throttled), .throttled)

        let geocodeNoResult = NSError(domain: kCLErrorDomain, code: 8, userInfo: nil)
        XCTAssertEqual(PlacesError.from(geocodeNoResult), .noResults,
                       "kCLErrorDomain 8 is geocodeFoundNoResult")

        let other = NSError(domain: "com.example", code: 1, userInfo: nil)
        guard case .mapKit = PlacesError.from(other) else {
            return XCTFail("an unknown domain should pass through")
        }
    }

    // MARK: - Place

    func testAPlaceSummarisesAndLinks() {
        let place = Place(name: "Monmouth Coffee",
                          coordinate: Coordinate(latitude: 51.5143, longitude: -0.1268)!,
                          address: "27 Monmouth Street, London")
        XCTAssertEqual(place.summary, "Monmouth Coffee, 27 Monmouth Street, London")
        XCTAssertTrue(place.mapsURL.contains("51.5143"))
        XCTAssertEqual(place.id, "51.5143,-0.1268", "no MapKit id means the coordinate identifies it")
    }
}
