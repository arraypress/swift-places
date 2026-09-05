//
//  TransportMode.swift
//  Places
//
//  Created by David Sherlock on 2026.
//
//  How to travel, and the one thing Apple's header says out loud about it.
//

import Foundation
import MapKit

/// A way of getting there.
public enum TransportMode: String, CaseIterable, Sendable, Codable {
    case automobile
    case walking
    case cycling
    case transit
    /// Let MapKit choose.
    case any

    public var transportType: MKDirectionsTransportType {
        switch self {
        case .automobile: return .automobile
        case .walking: return .walking
        case .cycling: return .cycling
        case .transit: return .transit
        case .any: return .any
        }
    }

    /// Whether a full turn-by-turn route can be calculated for this mode.
    ///
    /// **Transit cannot.** Apple's own header says so inline —
    /// `MKDirectionsTransportTypeTransit … // Only supported for ETA
    /// calculations` — and asking for a route anyway fails with
    /// `MKErrorDomain 5`, which reads like an outage rather than a documented
    /// limit. Measured 2026-09-05: transit ETA answers 27 min for a journey
    /// the car does in 46, so the estimate is real and worth having; it is
    /// only the step list that is missing.
    public var supportsRouteSteps: Bool { self != .transit }

    /// Whether an estimate can be made. All of them.
    public var supportsEstimate: Bool { true }

    /// Reads what someone would type — `car`, `drive`, `foot`, `bike`, `bus`.
    public init?(alias: String) {
        switch alias.lowercased() {
        case "automobile", "car", "drive", "driving": self = .automobile
        case "walking", "walk", "foot", "on-foot": self = .walking
        case "cycling", "cycle", "bike", "bicycle": self = .cycling
        case "transit", "bus", "train", "tube", "public", "public-transport": self = .transit
        case "any": self = .any
        default: return nil
        }
    }
}

/// Whether to avoid something on a route.
///
/// Mirrors `MKDirectionsRoutePreference`, which has exactly these two values.
public enum RoutePreference: String, CaseIterable, Sendable, Codable {
    /// No preference — MapKit's default.
    case any
    /// Prefer routes without it. Not a guarantee; MapKit may still use one
    /// where there is no alternative.
    case avoid

    public var preference: MKDirections.RoutePreference {
        self == .avoid ? .avoid : .any
    }
}

/// What kinds of result a search should return.
///
/// Mirrors `MKLocalSearchResultType`. `physicalFeature` — mountains, rivers —
/// arrived in macOS 15 / iOS 18, so it is only requested where it exists.
public struct ResultTypes: OptionSet, Sendable, Codable {
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

    /// The MapKit value, dropping anything this OS does not know about.
    var searchResultType: MKLocalSearch.ResultType {
        var types: MKLocalSearch.ResultType = []
        if contains(.address) { types.insert(.address) }
        if contains(.pointOfInterest) { types.insert(.pointOfInterest) }
        if contains(.physicalFeature) {
            if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
                types.insert(.physicalFeature)
            }
        }
        return types
    }
}
