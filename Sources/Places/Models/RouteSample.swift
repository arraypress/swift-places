//
//  RouteSample.swift
//  Places
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A point taken at a known distance along a route's geometry.
///
/// What ``Route/samples(every:)`` returns: somewhere to centre a search when
/// the question is "what is along the way" rather than "what is near here".
public struct RouteSample: Sendable, Codable, Equatable {
    /// Where the sample falls.
    public let coordinate: Coordinate
    /// Metres from the start of the line, measured along it.
    public let along: Double

    public init(coordinate: Coordinate, along: Double) {
        self.coordinate = coordinate
        self.along = along
    }
}
