//
//  TransportMode.swift
//  Places
//
//  Created by David Sherlock on 2026.
//
//  How to travel, and the one thing Apple's header says out loud about it.
//

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

    /// The same mode as MapKit expresses it.
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
