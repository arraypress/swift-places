//
//  Estimate.swift
//  Places
//
//  Created by David Sherlock on 2026.
//

import Foundation
import MapKit

/// How long a journey takes, without the turn-by-turn.
///
/// This is all transit can give — see ``TransportMode/supportsRouteSteps``.
public struct Estimate: Sendable, Codable, Equatable {
    /// How the journey is made.
    public let mode: TransportMode
    /// Metres.
    public let distance: Double
    /// Seconds.
    public let travelTime: Double
    /// When the journey would start.
    public let departure: Date
    /// When it would end.
    public let arrival: Date

    init(_ response: MKDirections.ETAResponse) {
        self.mode = TransportMode(transportType: response.transportType)
        self.distance = response.distance
        self.travelTime = response.expectedTravelTime
        self.departure = response.expectedDepartureDate
        self.arrival = response.expectedArrivalDate
    }

    public init(mode: TransportMode, distance: Double, travelTime: Double,
                departure: Date, arrival: Date) {
        self.mode = mode
        self.distance = distance
        self.travelTime = travelTime
        self.departure = departure
        self.arrival = arrival
    }
}
