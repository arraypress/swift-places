//
//  Coordinate.swift
//  Places
//
//  Created by David Sherlock on 2026.
//

import CoreLocation
import Foundation
import MapKit

/// A point on the earth.
///
/// A plain `Codable`, `Sendable` value — `CLLocationCoordinate2D` is neither,
/// so passing one across a concurrency boundary or into JSON needs this.
public struct Coordinate: Sendable, Codable, Equatable, Hashable {
    public let latitude: Double
    public let longitude: Double

    /// A coordinate, or `nil` if the numbers are not one.
    public init?(latitude: Double, longitude: Double) {
        guard (-90...90).contains(latitude), (-180...180).contains(longitude),
              latitude.isFinite, longitude.isFinite
        else { return nil }
        self.latitude = latitude
        self.longitude = longitude
    }

    public init?(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    /// Reads `51.5074,-0.1276` — one argument, because a leading minus is
    /// read as a flag before it is read as a number.
    public init?(_ text: String) {
        let parts = text.split(whereSeparator: { $0 == "," || $0 == " " })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard parts.count == 2, let latitude = Double(parts[0]), let longitude = Double(parts[1])
        else { return nil }
        self.init(latitude: latitude, longitude: longitude)
    }

    public var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    /// Metres to another point, along the surface.
    public func distance(to other: Coordinate) -> Double {
        location.distance(from: other.location)
    }

    /// A square region of `radius` metres around this point.
    ///
    /// Metres rather than degrees here because MapKit's own
    /// `MKCoordinateRegion(center:latitudinalMeters:longitudinalMeters:)`
    /// takes metres and does the latitude correction itself.
    public func region(radiusMetres radius: Double) -> MKCoordinateRegion {
        MKCoordinateRegion(center: clCoordinate,
                           latitudinalMeters: radius * 2,
                           longitudinalMeters: radius * 2)
    }
}
