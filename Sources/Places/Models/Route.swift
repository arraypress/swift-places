//
//  Route.swift
//  Places
//
//  Created by David Sherlock on 2026.
//
//  `MKRoute` and `MKRoute.Step` as plain values, plus the ETA-only estimate
//  that transit gives instead of a route.
//

//

import Foundation
import MapKit

/// A way of getting from one place to another.
public struct Route: Sendable, Codable, Equatable {

    /// What the route is known by — "M4", "US-101".
    public let name: String
    /// Metres.
    public let distance: Double
    /// Seconds.
    public let travelTime: Double
    /// The mode this route was ASKED for, which is the one a caller means.
    public let mode: TransportMode
    /// The mode MapKit labelled the result with.
    ///
    /// Usually the same as ``mode``. It is **not** for cycling: a cycling
    /// request returns a genuinely cycling-aware route — different roads, and
    /// an advisory like "Cycle routes and main roads" — but MapKit stamps it
    /// `automobile` (measured 2026-09-05, `transportType` raw value 1 for a
    /// request of raw value 8). Reporting that verbatim made `--mode cycling`
    /// answer "automobile", which reads like the request was ignored when it
    /// was not. Both are kept so the discrepancy is visible, not hidden.
    public let reportedMode: TransportMode
    /// Whether the route uses a toll road.
    public let hasTolls: Bool
    /// Whether it uses a motorway.
    public let hasHighways: Bool
    /// MapKit's own notices — "Toll required.", "Avoid during winter storms",
    /// and, in London, the ULEZ. Worth surfacing: they are the part a driver
    /// most wants and no other field carries.
    public let advisoryNotices: [String]
    /// The turn-by-turn directions, in order.
    public let steps: [RouteStep]
    /// The route's geometry, thinned to `polylineLimit` points.
    public let polyline: [Coordinate]

    init(_ route: MKRoute, requested: TransportMode, polylineLimit: Int) {
        self.name = route.name
        self.distance = route.distance
        self.travelTime = route.expectedTravelTime
        self.mode = requested
        self.reportedMode = TransportMode(transportType: route.transportType)
        self.advisoryNotices = route.advisoryNotices
        self.hasTolls = route.hasTolls
        self.hasHighways = route.hasHighways
        // MapKit's own step list ends with a zero-distance "arrive" entry and
        // often begins with one too; they carry the instruction, so they stay.
        self.steps = route.steps.map { RouteStep($0, polylineLimit: polylineLimit) }
        self.polyline = Route.coordinates(of: route.polyline, limit: polylineLimit)
    }

    /// Reads the geometry out of an `MKPolyline`, thinned.
    ///
    /// A London-to-Bristol drive is ~1,700 points; a caller drawing a line or
    /// writing JSON rarely wants all of them, and nothing else in MapKit
    /// offers a coarser version. Zero means every point.
    static func coordinates(of polyline: MKPolyline, limit: Int) -> [Coordinate] {
        let count = polyline.pointCount
        guard count > 0 else { return [] }
        var raw = [CLLocationCoordinate2D](repeating: .init(), count: count)
        polyline.getCoordinates(&raw, range: NSRange(location: 0, length: count))

        let points = raw.compactMap(Coordinate.init)
        guard limit > 0, points.count > limit else { return points }
        // Even sampling, always keeping both ends — a thinned line that does
        // not start and finish in the right place is worse than none.
        let stride = Double(points.count - 1) / Double(limit - 1)
        var thinned = (0..<(limit - 1)).map { points[Int((Double($0) * stride).rounded())] }
        thinned.append(points[points.count - 1])
        return thinned
    }

    public init(name: String, distance: Double, travelTime: Double, mode: TransportMode,
                reportedMode: TransportMode? = nil,
                hasTolls: Bool = false, hasHighways: Bool = false,
                advisoryNotices: [String] = [], steps: [RouteStep] = [],
                polyline: [Coordinate] = []) {
        self.name = name
        self.distance = distance
        self.travelTime = travelTime
        self.mode = mode
        self.reportedMode = reportedMode ?? mode
        self.hasTolls = hasTolls
        self.hasHighways = hasHighways
        self.advisoryNotices = advisoryNotices
        self.steps = steps
        self.polyline = polyline
    }
}
