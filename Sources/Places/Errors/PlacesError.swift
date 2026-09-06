//
//  PlacesError.swift
//  Places
//
//  Created by David Sherlock on 2026.
//

import Foundation
import MapKit

/// What can go wrong asking MapKit about the world.
public enum PlacesError: Error, LocalizedError, Sendable, Equatable {
    /// Nothing matched.
    case noResults
    /// MapKit is throttling this app. The limit is per-app and undocumented.
    case throttled
    /// The mode asked for cannot produce a step-by-step route.
    ///
    /// Transit is the only one. Apple's header says so inline, and the raw
    /// failure is `MKErrorDomain 5`, which reads like an outage instead.
    case routeStepsUnavailable(TransportMode)
    /// A coordinate outside the possible range.
    case invalidCoordinate(latitude: Double, longitude: Double)
    /// A search area that is not an area.
    case invalidRegion(String)
    /// Autocomplete did not answer in time.
    ///
    /// `MKLocalSearchCompleter` reports through a delegate driven by a run
    /// loop; with no run loop it simply never calls back. This library spins
    /// one, so a timeout means the network is slow — not that a run loop is
    /// missing.
    case timedOut
    /// MapKit failed for a reason of its own.
    case mapKit(code: Int, message: String)

    /// A one-line reason, for a CLI or a log.
    public var errorDescription: String? {
        switch self {
        case .noResults:
            return "nothing matched"
        case .throttled:
            return "MapKit is throttling this app; try again shortly"
        case .routeStepsUnavailable(let mode):
            return "\(mode.rawValue) gives an estimate but no turn-by-turn route"
        case .invalidCoordinate(let latitude, let longitude):
            return "\(latitude), \(longitude) is not a coordinate"
        case .invalidRegion(let why):
            return "bad search area: \(why)"
        case .timedOut:
            return "autocomplete did not answer in time"
        case .mapKit(let code, let message):
            return "\(message) (MKError \(code))"
        }
    }

    /// Maps a raw failure onto this.
    ///
    /// TWO DOMAINS, not one. Search and directions fail in `MKErrorDomain`,
    /// but geocoding goes through `CLGeocoder` and fails in
    /// `kCLErrorDomain` — so a client that only reads MapKit's codes reports
    /// "no such address" as an unexplained error. Found by a live test on
    /// 2026-09-05: `kCLErrorDomain error 8` is `geocodeFoundNoResult`.
    ///
    /// `loadingThrottled` is worth its own case either way: it means slow
    /// down, not that the query was wrong, so a caller should back off rather
    /// than retry.
    static func from(_ error: Error) -> PlacesError {
        let ns = error as NSError
        switch ns.domain {
        case MKErrorDomain:
            switch MKError.Code(rawValue: UInt(max(0, ns.code))) {
            case .placemarkNotFound, .directionsNotFound:
                return .noResults
            case .loadingThrottled:
                return .throttled
            default:
                return .mapKit(code: ns.code, message: ns.localizedDescription)
            }
        case kCLErrorDomain:
            switch CLError.Code(rawValue: ns.code) {
            case .geocodeFoundNoResult, .geocodeCanceled:
                return .noResults
            case .network:
                // CoreLocation reports its own throttling as a network error.
                return .throttled
            default:
                return .mapKit(code: ns.code, message: ns.localizedDescription)
            }
        default:
            return .mapKit(code: ns.code, message: ns.localizedDescription)
        }
    }
}
