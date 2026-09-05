//
//  Place+Placemark.swift
//  Places
//
//  Created by David Sherlock on 2026.
//
//  Geocoding answers with `CLPlacemark`, not `MKMapItem` — a different type
//  carrying much the same thing. Kept apart from the model so the MapKit and
//  CoreLocation readings can be told apart at a glance.
//

import Contacts
import CoreLocation
import Foundation

extension Place {

    /// A geocoded placemark as a place.
    ///
    /// `CLPlacemark` is not deprecated the way `MKMapItem.placemark` is, and
    /// carries the postal parts broken out — so unlike the MapKit path, the
    /// street, postcode and country are available on every OS.
    init?(_ placemark: CLPlacemark) {
        guard let coordinate = placemark.location.flatMap({ Coordinate($0.coordinate) })
        else { return nil }

        let street = placemark.thoroughfare.map { road in
            placemark.subThoroughfare.map { "\($0) \(road)" } ?? road
        }
        let full = placemark.postalAddress.map {
            CNPostalAddressFormatter.string(from: $0, style: .mailingAddress)
                .replacingOccurrences(of: "\n", with: ", ")
        }
        self.init(
            identifier: nil,
            // A geocoded point often has no business name; the street is the
            // most useful thing to call it.
            name: placemark.name ?? street,
            coordinate: coordinate,
            address: full,
            street: street,
            locality: placemark.locality,
            administrativeArea: placemark.administrativeArea,
            postalCode: placemark.postalCode,
            country: placemark.country,
            countryCode: placemark.isoCountryCode,
            phoneNumber: nil,
            url: nil,
            category: nil,
            timeZone: placemark.timeZone?.identifier,
            isCurrentLocation: false,
            distance: nil
        )
    }
}
