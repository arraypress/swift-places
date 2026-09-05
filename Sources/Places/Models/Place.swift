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
    /// A single-line address — "10 Downing Street, London, SW1A 2AA, England".
    public let address: String?
    /// The short form MapKit shows under a pin — "10 Downing Street, London".
    public let shortAddress: String?
    /// The city with enough context to place it — "London, England".
    public let cityWithContext: String?
    /// The parts, where the OS breaks them out. `street` is the number and
    /// road only — "10 Downing Street".
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
    /// Other identifiers MapKit knows this place by (macOS 15+). A place
    /// merged from several sources can have more than one; any of them
    /// resolves through ``Places/place(identifier:)``.
    public let alternateIdentifiers: [String]

    /// Metres from wherever the search was centred. Filled in by the search,
    /// not by MapKit.
    public var distance: Double?

    init?(_ item: MKMapItem, from origin: Coordinate? = nil) {
        // The coordinate is the one thing a place cannot be without.
        guard let coordinate = Coordinate(item.location.coordinate) else { return nil }
        self.coordinate = coordinate

        self.name = item.name
        self.phoneNumber = item.phoneNumber
        self.url = item.url?.absoluteString
        self.timeZone = item.timeZone?.identifier
        self.isCurrentLocation = item.isCurrentLocation
        self.category = item.pointOfInterestCategory.flatMap(PointOfInterest.init)

        self.identifier = item.identifier?.rawValue
        self.alternateIdentifiers = item.alternateIdentifiers.map(\.rawValue).sorted()

        let parts = Place.address(of: item)
        self.address = parts.full
        self.shortAddress = parts.short
        self.cityWithContext = parts.cityWithContext
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
        full: String?, short: String?, cityWithContext: String?, street: String?, locality: String?,
        administrativeArea: String?, postalCode: String?, country: String?, countryCode: String?
    ) {
        // MEASURED 2026-09-05 on "10 Downing Street, London", macOS 27.
        //
        // The modern API is better for the FORMATTED string and worse for the
        // STRUCTURED parts, so each is taken from where it is right:
        //
        //   MKAddress.fullAddress  "10 Downing Street, London, SW1A 2AA, England"
        //                          — includes the postcode; the postal
        //                            formatter's output does not.
        //
        //   MKAddressRepresentations is NOT usable for components:
        //     cityName   "City of Westminster, London"  (placemark: "London")
        //     regionName "United Kingdom"               — that is the COUNTRY,
        //                not the region. Mapping it to administrativeArea, as
        //                this once did, reported England as United Kingdom.
        //   It also offers no postcode, country or country code at all.
        //
        // `placemark` is deprecated as of macOS 26 with no replacement that
        // carries these fields, so it stays until one exists.
        let placemark = item.placemark
        let formatted = item.address?.fullAddress ?? placemark.postalAddress.map {
            CNPostalAddressFormatter.string(from: $0, style: .mailingAddress)
                .replacingOccurrences(of: "\n", with: ", ")
        }
        return (
            full: formatted,
            // shortAddress is "10 Downing Street, London" — number, road AND
            // city. It is the pin label, not the street, so it gets its own
            // field; `street` stays the number and road from the placemark.
            short: item.address?.shortAddress,
            cityWithContext: item.addressRepresentations?.cityWithContext,
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
                address: String? = nil, shortAddress: String? = nil, cityWithContext: String? = nil,
                street: String? = nil, locality: String? = nil,
                administrativeArea: String? = nil, postalCode: String? = nil,
                country: String? = nil, countryCode: String? = nil,
                phoneNumber: String? = nil, url: String? = nil,
                category: PointOfInterest? = nil, timeZone: String? = nil,
                isCurrentLocation: Bool = false, alternateIdentifiers: [String] = [],
                distance: Double? = nil) {
        self.identifier = identifier
        self.name = name
        self.coordinate = coordinate
        self.address = address
        self.shortAddress = shortAddress
        self.cityWithContext = cityWithContext
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
        self.alternateIdentifiers = alternateIdentifiers
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
