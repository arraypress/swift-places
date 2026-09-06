//
//  AddressComponents.swift
//  Places
//
//  Created by David Sherlock on 2026.
//

import Foundation
import MapKit

/// The kinds of address a search may return, for narrowing address results.
///
/// A search for "Springfield" with `[.locality]` returns towns called
/// Springfield and not streets, counties or postcodes containing the word.
/// Wraps `MKAddressFilter`, which is an include-list or an exclude-list —
/// pass one or the other, as with ``PointOfInterest`` filters.
public struct AddressComponents: OptionSet, Sendable, Codable, Hashable {
    /// The underlying bits. Required by `OptionSet`.
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }

    /// The country name.
    public static let country = AddressComponents(rawValue: 1 << 0)
    /// A state, province or region.
    public static let administrativeArea = AddressComponents(rawValue: 1 << 1)
    /// A county or district.
    public static let subAdministrativeArea = AddressComponents(rawValue: 1 << 2)
    /// A city or town.
    public static let locality = AddressComponents(rawValue: 1 << 3)
    /// A neighbourhood.
    public static let subLocality = AddressComponents(rawValue: 1 << 4)
    /// The postcode or ZIP.
    public static let postalCode = AddressComponents(rawValue: 1 << 5)

    /// Every component at once.
    public static let all: AddressComponents = [.country, .administrativeArea, .subAdministrativeArea, .locality, .subLocality, .postalCode]

    var mapKit: MKAddressFilter.Options {
        var o: MKAddressFilter.Options = []
        if contains(.country) { o.insert(.country) }
        if contains(.administrativeArea) { o.insert(.administrativeArea) }
        if contains(.subAdministrativeArea) { o.insert(.subAdministrativeArea) }
        if contains(.locality) { o.insert(.locality) }
        if contains(.subLocality) { o.insert(.subLocality) }
        if contains(.postalCode) { o.insert(.postalCode) }
        return o
    }

    /// MapKit's filter, or nil when nothing was asked for. Including wins.
    static func filter(including: AddressComponents, excluding: AddressComponents) -> MKAddressFilter? {
        if !including.isEmpty { return MKAddressFilter(including: including.mapKit) }
        if !excluding.isEmpty { return MKAddressFilter(excluding: excluding.mapKit) }
        return nil
    }
}
