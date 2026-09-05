//
//  RegionPriority.swift
//  Places
//
//  Created by David Sherlock on 2026.
//

import Foundation
import MapKit

/// How firmly a search stays inside the region it was given.
///
/// MapKit treats a region as a HINT by default: a search for "pizza" near
/// Trafalgar Square can return a well-known pizzeria in Mayfair. That is the
/// right answer for a map that will pan, and the wrong one for "what is
/// within walking distance". `required` confines results to the region.
public enum RegionPriority: String, Sendable, Codable, CaseIterable {
    /// The region biases ranking; results may fall outside it. MapKit's default.
    case preferred
    /// Only results inside the region are returned.
    case required

    var mapKit: MKLocalSearchRegionPriority {
        switch self {
        case .preferred: return .default
        case .required: return .required
        }
    }
}
