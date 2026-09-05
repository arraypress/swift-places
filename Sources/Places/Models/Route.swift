//
//  Route.swift
//  Places
//
//  Created by David Sherlock on 2026.
//
//  `MKRoute` and `MKRoute.Step` as plain values, plus the ETA-only estimate
//  that transit gives instead of a route.
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
    public let mode: TransportMode
    /// Whether the route uses a toll road.
    public let hasTolls: Bool
    /// Whether it uses a motorway.
    public let hasHighways: Bool
    /// MapKit's own notices — "Toll required.", "Avoid during winter storms",
    /// and, in London, the ULEZ. Worth surfacing: they are the part a driver
    /// most wants and no other field carries.
    public let advisoryNotices: [String]
    public let steps: [RouteStep]
    /// The route's geometry, thinned to `polylineLimit` points.
    public let polyline: [Coordinate]

    init(_ route: MKRoute, polylineLimit: Int) {
        self.name = route.name
        self.distance = route.distance
        self.travelTime = route.expectedTravelTime
        self.mode = TransportMode(transportType: route.transportType)
        self.advisoryNotices = route.advisoryNotices
        if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
            self.hasTolls = route.hasTolls
            self.hasHighways = route.hasHighways
        } else {
            self.hasTolls = false
            self.hasHighways = false
        }
        // MapKit's own step list ends with a zero-distance "arrive" entry and
        // often begins with one too; they carry the instruction, so they stay.
        self.steps = route.steps.map(RouteStep.init)
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
                hasTolls: Bool = false, hasHighways: Bool = false,
                advisoryNotices: [String] = [], steps: [RouteStep] = [],
                polyline: [Coordinate] = []) {
        self.name = name
        self.distance = distance
        self.travelTime = travelTime
        self.mode = mode
        self.hasTolls = hasTolls
        self.hasHighways = hasHighways
        self.advisoryNotices = advisoryNotices
        self.steps = steps
        self.polyline = polyline
    }
}

/// One instruction along a route.
public struct RouteStep: Sendable, Codable, Equatable {
    /// "Turn right onto Trafalgar Square".
    public let instructions: String
    /// A legal or warning notice attached to this step.
    public let notice: String?
    /// Metres.
    public let distance: Double
    /// A step may differ from the route: a drive can include a ferry.
    public let mode: TransportMode

    init(_ step: MKRoute.Step) {
        self.instructions = step.instructions
        self.notice = step.notice
        self.distance = step.distance
        self.mode = TransportMode(transportType: step.transportType)
    }

    public init(instructions: String, notice: String? = nil,
                distance: Double, mode: TransportMode = .automobile) {
        self.instructions = instructions
        self.notice = notice
        self.distance = distance
        self.mode = mode
    }
}

/// How long a journey takes, without the turn-by-turn.
///
/// This is all transit can give — see ``TransportMode/supportsRouteSteps``.
public struct Estimate: Sendable, Codable, Equatable {
    public let mode: TransportMode
    /// Metres.
    public let distance: Double
    /// Seconds.
    public let travelTime: Double
    public let departure: Date
    public let arrival: Date

    init(_ response: MKDirections.ETAResponse) {
        self.mode = TransportMode(transportType: response.transportType)
        self.distance = response.distance
        self.travelTime = response.expectedTravelTime
        self.departure = response.expectedDepartureDate
        self.arrival = response.expectedArrivalDate
    }

    public init(mode: TransportMode, distance: Double, travelTime: Double,
                departure: Date, arrival: Date) {
        self.mode = mode
        self.distance = distance
        self.travelTime = travelTime
        self.departure = departure
        self.arrival = arrival
    }
}

extension TransportMode {
    /// The mode MapKit reported. `MKDirectionsTransportType` is an option set,
    /// so a response can in principle carry more than one bit; the first that
    /// matches wins, and anything unrecognised is `.any`.
    init(transportType: MKDirectionsTransportType) {
        if transportType.contains(.automobile) { self = .automobile }
        else if transportType.contains(.walking) { self = .walking }
        else if transportType.contains(.cycling) { self = .cycling }
        else if transportType.contains(.transit) { self = .transit }
        else { self = .any }
    }
}
