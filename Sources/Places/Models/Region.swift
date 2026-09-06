//
//  Region.swift
//  Places
//
//  Created by David Sherlock on 2026.
//

import Foundation
import MapKit

/// A rectangular area on the map: a centre and how far it spans.
///
/// `MKCoordinateRegion` as a plain value. The spans are in degrees, as
/// MapKit gives them; ``latitudinalMetres`` and ``longitudinalMetres``
/// convert at the centre's latitude.
public struct Region: Sendable, Codable, Equatable {
    /// The middle of the region.
    public let center: Coordinate
    /// Degrees of latitude covered, top to bottom.
    public let latitudeDelta: Double
    /// Degrees of longitude covered, left to right.
    public let longitudeDelta: Double

    public init(center: Coordinate, latitudeDelta: Double, longitudeDelta: Double) {
        self.center = center
        self.latitudeDelta = latitudeDelta
        self.longitudeDelta = longitudeDelta
    }

    init?(_ region: MKCoordinateRegion) {
        guard let center = Coordinate(region.center) else { return nil }
        self.center = center
        self.latitudeDelta = region.span.latitudeDelta
        self.longitudeDelta = region.span.longitudeDelta
    }

    var mapKit: MKCoordinateRegion {
        MKCoordinateRegion(center: center.clCoordinate,
                           span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta))
    }

    /// One degree of latitude is 111.32 km everywhere.
    public var latitudinalMetres: Double { latitudeDelta * 111_320 }
    /// A degree of longitude shrinks towards the poles.
    public var longitudinalMetres: Double { longitudeDelta * 111_320 * cos(center.latitude * .pi / 180) }

    /// Whether a point lies inside the rectangle.
    public func contains(_ coordinate: Coordinate) -> Bool {
        abs(coordinate.latitude - center.latitude) <= latitudeDelta / 2
            && abs(coordinate.longitude - center.longitude) <= longitudeDelta / 2
    }
}
