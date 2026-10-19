//
//  Route+Geometry.swift
//  Places
//
//  Created by David Sherlock on 2026.
//
//  "What is along the way" — the two questions a route's geometry answers
//  that MapKit does not: where to look, and how far out of the way each
//  thing found is. The arithmetic is in ``RouteGeometry``.
//

import Foundation

public extension Route {

    /// Points along the route's ``polyline``, evenly spaced no further apart
    /// than `every` metres, both ends always included — somewhere to centre
    /// each search when looking for things along the way.
    ///
    /// A route shorter than `every` gives its two ends. Measured along the
    /// polyline as returned, so a route from a client built with a small
    /// `polylineLimit` is measured along the thinned line; build the client
    /// with `polylineLimit: 0` for the road's own geometry.
    func samples(every metres: Double) -> [RouteSample] {
        RouteGeometry.samples(of: polyline, every: metres)
    }

    /// How far `point` is from the route, and how far into the route its
    /// nearest point is — "400 m off the road, 38 km in". `nil` when the
    /// route carries no geometry.
    func position(of point: Coordinate) -> RoutePosition? {
        RouteGeometry.position(of: point, on: polyline)
    }

    /// The length of the ``polyline`` in metres, which can differ slightly
    /// from ``distance`` — MapKit's figure — when the line has been thinned.
    var polylineLength: Double {
        RouteGeometry.cumulativeLengths(of: polyline).last ?? 0
    }
}
