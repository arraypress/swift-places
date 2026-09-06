//
//  ResultTypes.swift
//  Places
//
//  Created by David Sherlock on 2026.
//

import Foundation
import MapKit

/// What kinds of result a search should return.
///
/// Mirrors `MKLocalSearchResultType`. `physicalFeature` — mountains, rivers —
/// arrived in macOS 15 / iOS 18, so it is only requested where it exists.
public struct ResultTypes: OptionSet, Sendable, Codable {
    /// The underlying bits. Required by `OptionSet`.
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// Street addresses.
    public static let address = ResultTypes(rawValue: 1 << 0)
    /// Businesses and landmarks.
    public static let pointOfInterest = ResultTypes(rawValue: 1 << 1)
    /// Natural features. Ignored below macOS 15 / iOS 18.
    public static let physicalFeature = ResultTypes(rawValue: 1 << 2)

    /// Everything the running OS supports.
    public static let all: ResultTypes = [.address, .pointOfInterest, .physicalFeature]

    /// The MapKit value for a search.
    var searchResultType: MKLocalSearch.ResultType {
        var types: MKLocalSearch.ResultType = []
        if contains(.address) { types.insert(.address) }
        if contains(.pointOfInterest) { types.insert(.pointOfInterest) }
        if contains(.physicalFeature) { types.insert(.physicalFeature) }
        return types
    }

    /// The MapKit value for autocomplete.
    ///
    /// A separate option set from the search one, with **no physical-feature
    /// member** — the completer offers addresses, points of interest and
    /// queries, so a request for mountains and rivers simply has nothing to
    /// map onto and is dropped rather than faked.
    var completerResultType: MKLocalSearchCompleter.ResultType {
        var types: MKLocalSearchCompleter.ResultType = []
        if contains(.address) { types.insert(.address) }
        if contains(.pointOfInterest) { types.insert(.pointOfInterest) }
        // Nothing asked for maps onto a completer type; ask for everything
        // rather than sending an empty set, which returns nothing at all.
        return types.isEmpty ? [.address, .pointOfInterest, .query] : types
    }
}
