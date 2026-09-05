//
//  SearchResults.swift
//  Places
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What a search returned, with the area that covers it.
///
/// ``Places/search(_:near:radiusMetres:categories:excluding:resultTypes:addressComponents:excludingAddressComponents:regionPriority:limit:)``
/// returns just the places; this adds MapKit's `boundingRegion`, which is
/// the rectangle a map should show to fit every result.
public struct SearchResults: Sendable, Codable, Equatable {
    public let places: [Place]
    /// The rectangle enclosing every result, as MapKit computed it.
    public let boundingRegion: Region?

    public init(places: [Place], boundingRegion: Region? = nil) {
        self.places = places
        self.boundingRegion = boundingRegion
    }
}
