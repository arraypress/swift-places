//
//  TransportMode+MapKit.swift
//  Places
//
//  Created by David Sherlock on 2026.
//

import Foundation
import MapKit

extension TransportMode {
    /// The mode MapKit reported. `MKDirectionsTransportType` is an option set,
    /// so a response can in principle carry more than one bit; the first that
    /// matches wins, and anything unrecognised is `.any`.
    init(transportType: MKDirectionsTransportType) {
        if transportType.contains(.automobile) { self = .automobile }
        else if transportType.contains(.walking) { self = .walking }
        else if transportType.contains(.cycling) { self = .cycling }
        else if transportType.contains(.transit) { self = .transit }
        else { self = .any }
    }
}
