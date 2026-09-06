//
//  RouteStep.swift
//  Places
//
//  Created by David Sherlock on 2026.
//

import Foundation
import MapKit

/// One instruction along a route.
public struct RouteStep: Sendable, Codable, Equatable {
    /// "Turn right onto Trafalgar Square".
    public let instructions: String
    /// A legal or warning notice attached to this step.
    public let notice: String?
    /// Metres.
    public let distance: Double
    /// A step may differ from the route: a drive can include a ferry.
    public let mode: TransportMode
    /// This step's own geometry, thinned like the route's — what a
    /// turn-by-turn view draws for the current manoeuvre.
    public let polyline: [Coordinate]

    init(_ step: MKRoute.Step, polylineLimit: Int) {
        self.instructions = step.instructions
        self.notice = step.notice
        self.distance = step.distance
        self.mode = TransportMode(transportType: step.transportType)
        self.polyline = Route.coordinates(of: step.polyline, limit: polylineLimit)
    }

    public init(instructions: String, notice: String? = nil,
                distance: Double, mode: TransportMode = .automobile,
                polyline: [Coordinate] = []) {
        self.instructions = instructions
        self.notice = notice
        self.distance = distance
        self.mode = mode
        self.polyline = polyline
    }
}
