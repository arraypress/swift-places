//
//  RoutePreference.swift
//  Places
//
//  Created by David Sherlock on 2026.
//

import Foundation
import MapKit

/// Whether to avoid something on a route.
///
/// Mirrors `MKDirectionsRoutePreference`, which has exactly these two values.
public enum RoutePreference: String, CaseIterable, Sendable, Codable {
    /// No preference — MapKit's default.
    case any
    /// Prefer routes without it. Not a guarantee; MapKit may still use one
    /// where there is no alternative.
    case avoid

    /// The same choice as MapKit expresses it.
    public var preference: MKDirections.RoutePreference {
        self == .avoid ? .avoid : .any
    }
}
