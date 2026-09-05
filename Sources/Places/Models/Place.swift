//
//  Place.swift
//  Places
//
//  Created by David Sherlock on 2026.
//
//  An `MKMapItem` as a plain value.
//
//  `MKMapItem` is a reference type and is not `Sendable`, so it cannot cross a
//  concurrency boundary or be encoded. This carries everything it exposes,
//  and reads the address through whichever API the running OS has: `address`
//  and `location` on macOS 26 / iOS 26, `placemark` below — that property was
//  DEPRECATED in 26 with "Use location, address and addressRepresentations
//  instead", so using it unconditionally warns on a modern SDK and using the
//  new one unconditionally will not compile against an older floor.
//

import Contacts
import CoreLocation
import Foundation
import MapKit

/// A place MapKit knows about.
public struct Place: Sendable, Codable, Equatable, Identifiable {

    /// MapKit's stable identifier, where the OS provides one (macOS 15+).
    /// Falls back to the coordinate, which is stable enough to dedupe on.
    public var id: String { identifier ?? "\(coordinate.latitude),\(coordinate.longitude)" }

    public let identifier: String?
    public let name: String?
    public let coordinate: Coordinate
    /// A single-line address.
    public let address: String?
    /// The parts, where the OS breaks them out.
    public let street: String?
    public let locality: String?
    public let administrativeArea: String?
    public let postalCode: String?
    public let country: String?
    public let countryCode: String?
    public let phoneNumber: String?
    public let url: String?
    /// What kind of place MapKit says it is.
    public let category: PointOfInterest?
    /// The IANA time zone, where known.
    public let timeZone: String?
    /// Whether this is the device's own location.
    public let isCurrentLocation: Bool

    /// Metres from wherever the search was centred. Filled in by the search,
    /// not by MapKit.
    public var distance: Double?

    init?(_ item: MKMapItem, from origin: Coordinate? = nil) {
        // The coordinate is the one thing a place cannot be without.
        let raw: CLLocationCoordinate2D
        if #available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) {
            raw = item.location.coordinate
        } else {
            raw = item.placemark.coordinate
        }
        guard let coordinate = Coordinate(raw) else { return nil }
        self.coordinate = coordinate

        self.name = item.name
        self.phoneNumber = item.phoneNumber
        self.url = item.url?.absoluteString
        self.timeZone = item.timeZone?.identifier
        self.isCurrentLocation = item.isCurrentLocation
        self.category = item.pointOfInterestCategory.flatMap(PointOfInterest.init)

        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
            self.identifier = item.identifier?.rawValue
        } else {
            self.identifier = nil
        }

        let parts = Place.address(of: item)
        self.address = parts.full
        self.street = parts.street
        self.locality = parts.locality
        self.administrativeArea = parts.administrativeArea
        self.postalCode = parts.postalCode
        self.country = parts.country
        self.countryCode = parts.countryCode

        self.distance = origin.map { $0.distance(to: coordinate) }
    }

    /// Reads the address through whichever API this OS has.
    private static func address(of item: MKMapItem) -> (
        full: String?, street: String?, locality: String?,
        administrativeArea: String?, postalCode: String?, country: String?, countryCode: String?
    ) {
        if #available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) {
            let representations = item.addressRepresentations
            return (
                full: item.address?.fullAddress,
                // The modern API exposes the city and region as names rather
                // than as a postal breakdown; the finer parts are not offered.
                street: item.address?.shortAddress,
                locality: representations?.cityName,
                administrativeArea: representations?.regionName,
                postalCode: nil,
                country: nil,
                countryCode: nil
            )
        }
        let placemark = item.placemark
        let postal = placemark.postalAddress
        return (
            full: postal.map { CNPostalAddressFormatter.string(from: $0, style: .mailingAddress)
                .replacingOccurrences(of: "\n", with: ", ") },
            street: placemark.thoroughfare.map { street in
                placemark.subThoroughfare.map { "\($0) \(street)" } ?? street
            },
            locality: placemark.locality,
            administrativeArea: placemark.administrativeArea,
            postalCode: placemark.postalCode,
            country: placemark.country,
            countryCode: placemark.isoCountryCode
        )
    }

    /// A place built by hand, for tests and for callers assembling one.
    public init(identifier: String? = nil, name: String?, coordinate: Coordinate,
                address: String? = nil, street: String? = nil, locality: String? = nil,
                administrativeArea: String? = nil, postalCode: String? = nil,
                country: String? = nil, countryCode: String? = nil,
                phoneNumber: String? = nil, url: String? = nil,
                category: PointOfInterest? = nil, timeZone: String? = nil,
                isCurrentLocation: Bool = false, distance: Double? = nil) {
        self.identifier = identifier
        self.name = name
        self.coordinate = coordinate
        self.address = address
        self.street = street
        self.locality = locality
        self.administrativeArea = administrativeArea
        self.postalCode = postalCode
        self.country = country
        self.countryCode = countryCode
        self.phoneNumber = phoneNumber
        self.url = url
        self.category = category
        self.timeZone = timeZone
        self.isCurrentLocation = isCurrentLocation
        self.distance = distance
    }

    /// A one-line description — "Monmouth Coffee, 27 Monmouth Street, London".
    public var summary: String {
        [name, address].compactMap { $0 }.joined(separator: ", ")
    }

    /// An Apple Maps link to this point.
    public var mapsURL: String {
        "https://maps.apple.com/?ll=\(coordinate.latitude),\(coordinate.longitude)"
    }
}
