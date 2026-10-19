//
//  RouteGeometryTests.swift
//  PlacesTests
//
//  Created by David Sherlock on 2026.
//
//  Offline. Sampling and the point-to-route distance, against geometry
//  worked out by hand: along the equator a degree of longitude is exactly
//  one degree of arc, so every expected figure is `degrees × π/180 × R`.
//

import Foundation
import XCTest
@testable import Places

final class RouteGeometryTests: XCTestCase {

    /// One degree of arc on the sphere `RouteGeometry` uses.
    private let degree = RouteGeometry.earthRadius * .pi / 180

    private func point(_ latitude: Double, _ longitude: Double) -> Coordinate {
        Coordinate(latitude: latitude, longitude: longitude)!
    }

    private func route(_ points: [Coordinate]) -> Route {
        Route(name: "test", distance: 0, travelTime: 0, mode: .automobile, polyline: points)
    }

    /// One degree east along the equator: 111.2 km.
    private var straight: Route { route([point(0, 0), point(0, 1)]) }

    /// East along the equator for a degree, then north for a degree.
    private var corner: Route { route([point(0, 0), point(0, 1), point(1, 1)]) }

    // MARK: - Sampling

    func testSamplesAreEvenAndNoFurtherApartThanAsked() {
        let samples = straight.samples(every: 10_000)
        // 111.2 km in at most 10 km steps is 12 gaps, so 13 points 9.27 km apart.
        XCTAssertEqual(samples.count, 13)
        let spacing = degree / 12
        for (previous, next) in zip(samples, samples.dropFirst()) {
            let gap = RouteGeometry.distance(previous.coordinate, next.coordinate)
            XCTAssertEqual(gap, spacing, accuracy: 1)
            XCTAssertLessThanOrEqual(gap, 10_000)
            XCTAssertEqual(next.along - previous.along, spacing, accuracy: 1)
        }
    }

    func testSamplesIncludeBothEnds() throws {
        let samples = straight.samples(every: 10_000)
        let first = try XCTUnwrap(samples.first)
        let last = try XCTUnwrap(samples.last)
        XCTAssertEqual(first.coordinate, point(0, 0))
        XCTAssertEqual(first.along, 0)
        XCTAssertEqual(last.coordinate, point(0, 1))
        XCTAssertEqual(last.along, degree, accuracy: 1)
    }

    func testARouteShorterThanTheSpacingGivesItsTwoEnds() {
        // About 3 km.
        let short = route([point(0, 0), point(0, 0.027)])
        let samples = short.samples(every: 10_000)
        XCTAssertEqual(samples.map(\.coordinate), [point(0, 0), point(0, 0.027)])
        XCTAssertEqual(samples[1].along, 0.027 * degree, accuracy: 1)
    }

    func testDegenerateLinesSampleSafely() {
        XCTAssertEqual(route([]).samples(every: 1_000), [])
        XCTAssertEqual(route([point(51.5, -0.1)]).samples(every: 1_000).map(\.coordinate), [point(51.5, -0.1)])
        // A nonsense spacing falls back to the ends rather than looping forever.
        XCTAssertEqual(straight.samples(every: 0).count, 2)
        XCTAssertEqual(straight.samples(every: -5).count, 2)
    }

    func testSamplesFollowTheLineRoundACorner() throws {
        let samples = corner.samples(every: 20_000)
        // 222.4 km in at most 20 km steps: 12 gaps.
        XCTAssertEqual(samples.count, 13)
        for sample in samples {
            let position = try XCTUnwrap(corner.position(of: sample.coordinate))
            XCTAssertLessThan(position.offRoute, 1, "a sample must lie on the line")
            XCTAssertEqual(position.along, sample.along, accuracy: 1)
        }
        XCTAssertTrue(samples.contains { $0.coordinate.latitude > 0.5 }, "it turned the corner")
    }

    // MARK: - Position

    func testAPointBesideAStraightLine() throws {
        let position = try XCTUnwrap(straight.position(of: point(0.1, 0.5)))
        XCTAssertEqual(position.offRoute, 0.1 * degree, accuracy: 1)
        XCTAssertEqual(position.along, 0.5 * degree, accuracy: 1)
        XCTAssertEqual(position.nearest.latitude, 0, accuracy: 1e-6)
        XCTAssertEqual(position.nearest.longitude, 0.5, accuracy: 1e-6)
    }

    func testEitherSideOfTheLineIsTheSameDistanceOff() throws {
        let north = try XCTUnwrap(straight.position(of: point(0.1, 0.5)))
        let south = try XCTUnwrap(straight.position(of: point(-0.1, 0.5)))
        XCTAssertEqual(south.offRoute, north.offRoute, accuracy: 0.01)
    }

    func testAPointOnTheLineIsNotOffIt() throws {
        let position = try XCTUnwrap(straight.position(of: point(0, 0.25)))
        XCTAssertEqual(position.offRoute, 0, accuracy: 0.01)
        XCTAssertEqual(position.along, 0.25 * degree, accuracy: 1)
    }

    func testBeforeTheStartTheStartIsNearest() throws {
        let position = try XCTUnwrap(straight.position(of: point(0, -0.2)))
        XCTAssertEqual(position.offRoute, 0.2 * degree, accuracy: 1)
        XCTAssertEqual(position.along, 0)
        XCTAssertEqual(position.nearest, point(0, 0))
    }

    func testPastTheEndTheEndIsNearest() throws {
        let position = try XCTUnwrap(straight.position(of: point(0, 1.2)))
        XCTAssertEqual(position.offRoute, 0.2 * degree, accuracy: 1)
        XCTAssertEqual(position.along, degree, accuracy: 1)
    }

    func testOutsideACornerTheCornerIsNearest() throws {
        // South-east of the turn: past the end of the first leg and behind
        // the start of the second, so neither leg's interior is closest.
        let outside = point(-0.1, 1.1)
        let position = try XCTUnwrap(corner.position(of: outside))
        XCTAssertEqual(position.offRoute, 15_725.36, accuracy: 1)
        XCTAssertEqual(position.offRoute, RouteGeometry.distance(outside, point(0, 1)), accuracy: 0.01)
        XCTAssertEqual(position.along, degree, accuracy: 1)
    }

    func testAlongTheSecondLegCountsTheFirst() throws {
        let position = try XCTUnwrap(corner.position(of: point(0.5, 1.05)))
        // Cross-track to the meridian at 1°E: asin(cos 0.5° · sin 0.05°) · R.
        XCTAssertEqual(position.offRoute, 5_559.54, accuracy: 1)
        XCTAssertEqual(position.along, 1.5 * degree, accuracy: 1)
    }

    func testARouteWithNoGeometryHasNoPosition() {
        XCTAssertNil(route([]).position(of: point(0, 0)))
        let single = route([point(0, 0)]).position(of: point(0, 0.1))
        XCTAssertEqual(single?.offRoute ?? 0, 0.1 * degree, accuracy: 1)
        XCTAssertEqual(single?.along, 0)
    }

    func testThePolylineLengthIsMeasuredAlongIt() {
        XCTAssertEqual(corner.polylineLength, 2 * degree, accuracy: 1)
        XCTAssertEqual(route([]).polylineLength, 0)
    }
}
