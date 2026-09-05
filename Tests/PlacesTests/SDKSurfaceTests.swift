//
//  SDKSurfaceTests.swift
//  Places
//
//  Created by David Sherlock on 2026.
//
//  Offline checks for the parts added by the 2026-09-06 audit against the
//  macOS 27 MapKit headers: region priority, address filters, bounding
//  regions, completion highlights, per-step geometry, identifier lookup.
//

import MapKit
import XCTest
@testable import Places

final class SDKSurfaceTests: XCTestCase {

    func testRegionPriorityMapsOntoMapKit() {
        XCTAssertEqual(RegionPriority.preferred.mapKit, .default)
        XCTAssertEqual(RegionPriority.required.mapKit, .required)
    }

    func testAddressComponentsBuildTheRightFilter() throws {
        XCTAssertNil(AddressComponents.filter(including: [], excluding: []))
        let including = try XCTUnwrap(AddressComponents.filter(including: [.locality, .postalCode], excluding: []))
        XCTAssertTrue(including.includes(.locality))
        XCTAssertTrue(including.includes(.postalCode))
        XCTAssertFalse(including.includes(.country))
        let excluding = try XCTUnwrap(AddressComponents.filter(including: [], excluding: [.country]))
        XCTAssertTrue(excluding.excludes(.country))
        XCTAssertFalse(excluding.excludes(.locality))
        // Including wins when both are given, as with points of interest.
        let both = try XCTUnwrap(AddressComponents.filter(including: [.locality], excluding: [.country]))
        XCTAssertTrue(both.includes(.locality))
        XCTAssertEqual(AddressComponents.all.mapKit, [.country, .administrativeArea, .subAdministrativeArea, .locality, .subLocality, .postalCode])
    }

    func testRegionConvertsBothWaysAndKnowsWhatItContains() throws {
        let centre = try XCTUnwrap(Coordinate(latitude: 51.5, longitude: -0.12))
        let region = Region(center: centre, latitudeDelta: 0.02, longitudeDelta: 0.04)
        XCTAssertEqual(region.latitudinalMetres, 0.02 * 111_320, accuracy: 0.001)
        XCTAssertLessThan(region.longitudinalMetres, 0.04 * 111_320, "longitude shrinks away from the equator")
        XCTAssertTrue(region.contains(try XCTUnwrap(Coordinate(latitude: 51.505, longitude: -0.10))))
        XCTAssertFalse(region.contains(try XCTUnwrap(Coordinate(latitude: 51.52, longitude: -0.12))))
        let back = try XCTUnwrap(Region(region.mapKit))
        XCTAssertEqual(back, region)
    }

    func testSuggestionHighlightsRenderAsMarks() {
        let s = Suggestion(title: "Trafalgar Square", subtitle: "London, England",
                           titleHighlights: [.init(location: 0, length: 7)],
                           subtitleHighlights: [])
        XCTAssertEqual(s.markedTitle(), "**Trafalg**ar Square")
        XCTAssertEqual(s.markedTitle(open: "<b>", close: "</b>"), "<b>Trafalg</b>ar Square")
        XCTAssertEqual(s.titleHighlights.first?.range, 0..<7)
        // Two runs, and a run past the end is ignored rather than crashing.
        let two = Suggestion(title: "Kings Cross Station", titleHighlights: [.init(location: 0, length: 5), .init(location: 6, length: 5), .init(location: 50, length: 3)])
        XCTAssertEqual(two.markedTitle(), "**Kings** **Cross** Station")
        XCTAssertEqual(Suggestion(title: "Plain").markedTitle(), "Plain")
    }

    func testRouteStepsCarryTheirOwnGeometry() {
        let step = RouteStep(instructions: "Turn left", distance: 120, polyline: [])
        XCTAssertTrue(step.polyline.isEmpty)
        XCTAssertEqual(step.mode, .automobile)
    }

    func testPlaceCarriesTheNewAddressForms() throws {
        let place = Place(identifier: "I1", name: "No 10", coordinate: try XCTUnwrap(Coordinate(latitude: 51.5034, longitude: -0.1276)),
                          address: "10 Downing Street, London, SW1A 2AA, England",
                          shortAddress: "10 Downing Street, London", cityWithContext: "London, England",
                          street: "10 Downing Street", alternateIdentifiers: ["I2", "I3"])
        XCTAssertEqual(place.street, "10 Downing Street", "street is number and road, not the pin label")
        XCTAssertEqual(place.shortAddress, "10 Downing Street, London")
        XCTAssertEqual(place.alternateIdentifiers, ["I2", "I3"])
        let data = try JSONEncoder().encode(place)
        let back = try JSONDecoder().decode(Place.self, from: data)
        XCTAssertEqual(back, place)
    }

    func testSearchResultsRoundTrip() throws {
        let centre = try XCTUnwrap(Coordinate(latitude: 51.5, longitude: -0.12))
        let results = SearchResults(places: [Place(name: "A", coordinate: centre)],
                                    boundingRegion: Region(center: centre, latitudeDelta: 0.1, longitudeDelta: 0.1))
        let back = try JSONDecoder().decode(SearchResults.self, from: try JSONEncoder().encode(results))
        XCTAssertEqual(back, results)
    }

    func testAnEmptyIdentifierIsRefusedBeforeAnyRequest() async {
        do {
            _ = try await Places().place(identifier: "  ")
            XCTFail("must refuse")
        } catch let error as PlacesError {
            guard case .invalidRegion = error else { return XCTFail("got \(error)") }
        } catch { XCTFail("unexpected \(error)") }
    }
}
