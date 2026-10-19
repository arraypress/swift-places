//
//  RoutePosition.swift
//  Places
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Where a point sits relative to a route: how far off it, and how far in.
///
/// What ``Route/position(of:)`` returns. A café 400 m off the road, 38 km
/// into the journey, is `offRoute: 400, along: 38_000`.
public struct RoutePosition: Sendable, Codable, Equatable {
    /// Metres from the point to the nearest point on the line — the
    /// shortest distance over the earth's surface, one way.
    public let offRoute: Double
    /// Metres from the start of the line to that nearest point, measured
    /// along the line.
    public let along: Double
    /// The nearest point on the line itself.
    public let nearest: Coordinate

    public init(offRoute: Double, along: Double, nearest: Coordinate) {
        self.offRoute = offRoute
        self.along = along
        self.nearest = nearest
    }
}
