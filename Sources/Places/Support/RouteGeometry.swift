//
//  RouteGeometry.swift
//  Places
//
//  Created by David Sherlock on 2026.
//
//  Measuring along a line on the earth: points at even spacing, and how far
//  any point is from the line and how far into it. Pure arithmetic on a
//  sphere, so it is testable against geometry worked out by hand — MapKit
//  offers neither question.
//
//  Spherical rather than ellipsoidal. The difference is under 0.5% at any
//  latitude, which is far inside how precisely "38 km in" is meant, and it
//  keeps every distance here consistent with every other: mixing in
//  CoreLocation's own figures would put a point on the line a few metres off it.
//

import Foundation

/// Distances along and across a polyline, on a sphere.
enum RouteGeometry {

    /// The earth's mean radius, in metres (IUGG).
    static let earthRadius = 6_371_008.8

    // MARK: - Sampling

    /// Points along `line`, evenly spaced no further apart than `every`
    /// metres, always including both ends.
    ///
    /// The spacing is shrunk to divide the line exactly, so the last gap is
    /// never a stub: a 25 km line sampled every 10 km gives four points 8.3 km
    /// apart, not 0, 10, 20 and 25. A line shorter than `every` gives its two
    /// ends; a single point gives itself; an empty line gives nothing.
    static func samples(of line: [Coordinate], every: Double) -> [RouteSample] {
        guard let first = line.first else { return [] }
        let lengths = cumulativeLengths(of: line)
        let total = lengths[lengths.count - 1]
        guard total > 0 else { return [RouteSample(coordinate: first, along: 0)] }
        guard every > 0, every.isFinite else {
            return [RouteSample(coordinate: first, along: 0),
                    RouteSample(coordinate: line[line.count - 1], along: total)]
        }

        let gaps = max(1, Int((total / every).rounded(.up)))
        let spacing = total / Double(gaps)
        var samples: [RouteSample] = []
        samples.reserveCapacity(gaps + 1)
        var segment = 0
        for index in 0...gaps {
            // The last one is the last vertex exactly, not wherever rounding
            // in the sum happens to leave it.
            if index == gaps {
                samples.append(RouteSample(coordinate: line[line.count - 1], along: total))
                break
            }
            let target = Double(index) * spacing
            while segment < line.count - 2, lengths[segment + 1] < target { segment += 1 }
            let start = lengths[segment]
            let span = lengths[segment + 1] - start
            let fraction = span > 0 ? (target - start) / span : 0
            let point = interpolate(line[segment], line[segment + 1], fraction: fraction)
            samples.append(RouteSample(coordinate: point, along: target))
        }
        return samples
    }

    // MARK: - Position

    /// How far `point` is from `line`, and how far along the line its nearest
    /// point is. `nil` for an empty line.
    ///
    /// Each segment is a great-circle arc. The point is projected onto it with
    /// the cross-track and along-track formulas; when the projection falls
    /// before the segment's start or past its end, the nearest point is that
    /// end instead. The nearest over every segment wins, and on a tie the
    /// earlier one, so a point equidistant from two legs reads as the first
    /// time the route passes it.
    static func position(of point: Coordinate, on line: [Coordinate]) -> RoutePosition? {
        guard let first = line.first else { return nil }
        guard line.count > 1 else {
            return RoutePosition(offRoute: distance(point, first), along: 0, nearest: first)
        }
        let lengths = cumulativeLengths(of: line)
        var best: RoutePosition?
        for index in 0..<(line.count - 1) {
            let (offRoute, into) = nearest(point, onArcFrom: line[index], to: line[index + 1])
            if let best, best.offRoute <= offRoute { continue }
            let span = lengths[index + 1] - lengths[index]
            let nearestPoint = span > 0
                ? interpolate(line[index], line[index + 1], fraction: into / span)
                : line[index]
            best = RoutePosition(offRoute: offRoute, along: lengths[index] + into, nearest: nearestPoint)
        }
        return best
    }

    /// The shortest distance from `point` to the arc `a`→`b`, and how far
    /// from `a` along the arc the nearest point lies. Both in metres.
    static func nearest(_ point: Coordinate, onArcFrom a: Coordinate, to b: Coordinate) -> (offRoute: Double, along: Double) {
        let arc = angle(a, b)
        let toPoint = angle(a, point)
        guard arc > 0 else { return (toPoint * earthRadius, 0) }

        let relative = bearing(a, point) - bearing(a, b)
        // Behind the start: the start is nearest.
        guard cos(relative) > 0 else { return (toPoint * earthRadius, 0) }
        let crossTrack = asin(clamp(sin(toPoint) * sin(relative)))
        let alongTrack = acos(clamp(cos(toPoint) / cos(crossTrack)))
        // Past the end: the end is nearest.
        guard alongTrack <= arc else { return (angle(b, point) * earthRadius, arc * earthRadius) }
        return (abs(crossTrack) * earthRadius, alongTrack * earthRadius)
    }

    // MARK: - Primitives

    /// Running length of the line at each vertex, in metres; the first is 0.
    static func cumulativeLengths(of line: [Coordinate]) -> [Double] {
        var lengths = [0.0]
        lengths.reserveCapacity(line.count)
        for index in line.indices.dropFirst() {
            lengths.append(lengths[index - 1] + distance(line[index - 1], line[index]))
        }
        return lengths
    }

    /// Great-circle distance in metres.
    static func distance(_ a: Coordinate, _ b: Coordinate) -> Double {
        angle(a, b) * earthRadius
    }

    /// The angle between two points at the earth's centre, in radians —
    /// haversine, which stays accurate for the short spans a route is made of.
    static func angle(_ a: Coordinate, _ b: Coordinate) -> Double {
        let φ1 = radians(a.latitude), φ2 = radians(b.latitude)
        let Δφ = φ2 - φ1
        let Δλ = radians(b.longitude - a.longitude)
        let h = sin(Δφ / 2) * sin(Δφ / 2) + cos(φ1) * cos(φ2) * sin(Δλ / 2) * sin(Δλ / 2)
        return 2 * atan2(sqrt(h), sqrt(max(0, 1 - h)))
    }

    /// Initial bearing from `a` towards `b`, in radians clockwise from north.
    static func bearing(_ a: Coordinate, _ b: Coordinate) -> Double {
        let φ1 = radians(a.latitude), φ2 = radians(b.latitude)
        let Δλ = radians(b.longitude - a.longitude)
        let y = sin(Δλ) * cos(φ2)
        let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(Δλ)
        return atan2(y, x)
    }

    /// The point `fraction` of the way along the great circle from `a` to `b`.
    static func interpolate(_ a: Coordinate, _ b: Coordinate, fraction: Double) -> Coordinate {
        let δ = angle(a, b)
        guard δ > 0 else { return a }
        let f = min(max(fraction, 0), 1)
        let φ1 = radians(a.latitude), λ1 = radians(a.longitude)
        let φ2 = radians(b.latitude), λ2 = radians(b.longitude)
        let wa = sin((1 - f) * δ) / sin(δ)
        let wb = sin(f * δ) / sin(δ)
        let x = wa * cos(φ1) * cos(λ1) + wb * cos(φ2) * cos(λ2)
        let y = wa * cos(φ1) * sin(λ1) + wb * cos(φ2) * sin(λ2)
        let z = wa * sin(φ1) + wb * sin(φ2)
        let latitude = degrees(atan2(z, sqrt(x * x + y * y)))
        let longitude = degrees(atan2(y, x))
        return Coordinate(latitude: latitude, longitude: longitude) ?? a
    }

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
    private static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
    private static func clamp(_ value: Double) -> Double { min(max(value, -1), 1) }
}
