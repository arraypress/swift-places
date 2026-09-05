//
//  Places.swift
//  Places
//
//  Created by David Sherlock on 2026.
//
//  Search, directions and geocoding through MapKit and CoreLocation.
//
//  NOTHING HERE NEEDS ANYTHING FROM APPLE. No entitlement, no key, no
//  Info.plist, no developer account. Proven 2026-09-05 with a bare Mach-O —
//  no bundle, ad-hoc signed with an explicitly EMPTY entitlements dict —
//  which ran MKLocalSearch and MKDirections successfully. `grep -rl
//  "entitlement"` across every MapKit header finds nothing. The
//  `com.apple.developer.maps` capability that does exist is for ROUTING APPS
//  that Apple Maps hands off to, not for calling MapKit; and it is WeatherKit,
//  not MapKit, that needs an entitlement.
//
//  The one thing that does need a plist string is the DEVICE'S OWN position
//  via `CLLocationManager` — which is why this library does not do that. It
//  takes coordinates; getting them from the device is the app's job, and the
//  app is where the usage description has to live anyway.
//
//  Everything is on Apple's servers, so it is rate-limited per app. The limit
//  is undocumented; exceeding it surfaces as ``PlacesError/throttled``.
//

import CoreLocation
import Foundation
import MapKit

/// MapKit, as values.
public struct Places: Sendable {

    /// How many polyline points a route keeps. A London–Bristol drive is
    /// ~1,700; zero means all of them.
    public static let defaultPolylineLimit = 100

    /// How far around a point to search when no radius is given.
    public static let defaultRadiusMetres: Double = 5_000

    private let polylineLimit: Int

    /// A client.
    ///
    /// - Parameter polylineLimit: Points to keep per route. `0` keeps every
    ///   point; the default thins to something a caller can draw or serialise.
    public init(polylineLimit: Int = Places.defaultPolylineLimit) {
        self.polylineLimit = max(0, polylineLimit)
    }

    // MARK: - Search

    /// Places matching a query.
    ///
    /// - Parameters:
    ///   - query: Free text — `coffee`, `Monmouth Coffee`, `SW1A 2AA`.
    ///   - near: Where to look. Without one MapKit searches broadly and the
    ///     results are far less useful.
    ///   - radiusMetres: How wide, around `near`.
    ///   - categories: Restrict to these kinds of place. Empty means any.
    ///   - excluding: Kinds to leave out. Ignored when `categories` is given —
    ///     MapKit's filter is one or the other, not both.
    ///   - resultTypes: Addresses, points of interest, physical features.
    ///   - limit: Most to return, nearest first when `near` is given.
    public func search(_ query: String,
                       near: Coordinate? = nil,
                       radiusMetres: Double = Places.defaultRadiusMetres,
                       categories: [PointOfInterest] = [],
                       excluding: [PointOfInterest] = [],
                       resultTypes: ResultTypes = [.address, .pointOfInterest],
                       addressComponents: AddressComponents = [],
                       excludingAddressComponents: AddressComponents = [],
                       regionPriority: RegionPriority = .preferred,
                       limit: Int = 25) async throws -> [Place] {
        try await searchResults(query, near: near, radiusMetres: radiusMetres, categories: categories,
                                excluding: excluding, resultTypes: resultTypes,
                                addressComponents: addressComponents,
                                excludingAddressComponents: excludingAddressComponents,
                                regionPriority: regionPriority, limit: limit).places
    }

    /// The same search, with the rectangle MapKit says covers every result.
    ///
    /// - Parameters:
    ///   - regionPriority: `.preferred` lets MapKit rank by the region and
    ///     still return a strong match outside it; `.required` confines
    ///     results to the region. See ``RegionPriority``.
    ///   - addressComponents: When asking for addresses, which kinds — towns
    ///     only, say. Empty means any. Mutually exclusive with `excludingAddressComponents`.
    public func searchResults(_ query: String,
                              near: Coordinate? = nil,
                              radiusMetres: Double = Places.defaultRadiusMetres,
                              categories: [PointOfInterest] = [],
                              excluding: [PointOfInterest] = [],
                              resultTypes: ResultTypes = [.address, .pointOfInterest],
                              addressComponents: AddressComponents = [],
                              excludingAddressComponents: AddressComponents = [],
                              regionPriority: RegionPriority = .preferred,
                              limit: Int = 25) async throws -> SearchResults {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PlacesError.invalidRegion("no query") }
        guard radiusMetres > 0 else { throw PlacesError.invalidRegion("radius must be positive") }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = resultTypes.searchResultType
        if let near {
            request.region = near.region(radiusMetres: radiusMetres)
            request.regionPriority = regionPriority.mapKit
        }
        request.pointOfInterestFilter = Places.filter(including: categories, excluding: excluding)
        request.addressFilter = AddressComponents.filter(including: addressComponents, excluding: excludingAddressComponents)

        return try await runResults(MKLocalSearch(request: request), near: near, limit: limit)
    }

    /// A place by the stable identifier MapKit gave it in an earlier result.
    ///
    /// `MKMapItemRequest`. The identifier is ``Place/identifier`` — what to
    /// store instead of a name-and-coordinate when a place must be found
    /// again later; names change and coordinates drift.
    public func place(identifier: String) async throws -> Place {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PlacesError.invalidRegion("no identifier") }
        guard let mapKitIdentifier = MKMapItem.Identifier(rawValue: trimmed) else {
            throw PlacesError.invalidRegion("not a MapKit place identifier")
        }
        let request = MKMapItemRequest(mapItemIdentifier: mapKitIdentifier)
        do {
            let item = try await request.mapItem
            guard let place = Place(item) else { throw PlacesError.noResults }
            return place
        } catch let error as PlacesError {
            throw error
        } catch {
            throw PlacesError.from(error)
        }
    }

    /// Places of a kind, near a point — "restaurants around here".
    ///
    /// Uses `MKLocalPointsOfInterestRequest`, MapKit's dedicated
    /// category-around-a-point search, rather than joining the category names
    /// into a text query. Measured 2026-09-05 over a 500 m circle on Trafalgar
    /// Square asking for restaurants and cafés: the dedicated request returned
    /// **48 results against the text query's 25**. The text query also drifts
    /// outside the radius, because it is matching words rather than a region.
    ///
    /// - Note: MapKit caps the radius at
    ///   `MKLocalPointsOfInterestRequest.maxRadius`; anything larger is clamped
    ///   rather than rejected, so a wide search quietly narrows.
    public func nearby(_ categories: [PointOfInterest],
                       near: Coordinate,
                       radiusMetres: Double = Places.defaultRadiusMetres,
                       limit: Int = 25) async throws -> [Place] {
        guard !categories.isEmpty else { throw PlacesError.invalidRegion("no categories") }
        guard radiusMetres > 0 else { throw PlacesError.invalidRegion("radius must be positive") }

        let radius = min(radiusMetres, MKLocalPointsOfInterestRequest.maxRadius)
        let request = MKLocalPointsOfInterestRequest(center: near.clCoordinate, radius: radius)
        request.pointOfInterestFilter = Places.filter(including: categories, excluding: [])
        return try await run(MKLocalSearch(request: request), near: near, limit: limit)
    }

    /// Builds MapKit's filter. Including wins: the filter is one or the other.
    static func filter(including: [PointOfInterest],
                       excluding: [PointOfInterest]) -> MKPointOfInterestFilter? {
        if !including.isEmpty {
            return MKPointOfInterestFilter(including: including.map(\.category))
        }
        if !excluding.isEmpty {
            return MKPointOfInterestFilter(excluding: excluding.map(\.category))
        }
        return nil
    }

    private func run(_ search: MKLocalSearch,
                     near: Coordinate?, limit: Int) async throws -> [Place] {
        try await runResults(search, near: near, limit: limit).places
    }

    private func runResults(_ search: MKLocalSearch,
                            near: Coordinate?, limit: Int) async throws -> SearchResults {
        do {
            let response = try await search.start()
            var places = response.mapItems.compactMap { Place($0, from: near) }
            guard !places.isEmpty else { throw PlacesError.noResults }
            // Nearest first when there is a centre to measure from; MapKit's
            // own order is relevance, which is not the same question.
            if near != nil {
                places.sort { ($0.distance ?? .greatestFiniteMagnitude) < ($1.distance ?? .greatestFiniteMagnitude) }
            }
            return SearchResults(places: limit > 0 ? Array(places.prefix(limit)) : places,
                                 boundingRegion: Region(response.boundingRegion))
        } catch let error as PlacesError {
            throw error
        } catch {
            throw PlacesError.from(error)
        }
    }

    // MARK: - Directions

    /// Routes between two points, best first.
    ///
    /// - Throws: ``PlacesError/routeStepsUnavailable(_:)`` for transit, which
    ///   Apple supports for estimates only — use ``estimate(from:to:mode:)``.
    public func route(from source: Coordinate,
                      to destination: Coordinate,
                      mode: TransportMode = .automobile,
                      alternates: Bool = true,
                      departure: Date? = nil,
                      arrival: Date? = nil,
                      tolls: RoutePreference = .any,
                      highways: RoutePreference = .any) async throws -> [Route] {
        guard mode.supportsRouteSteps else {
            throw PlacesError.routeStepsUnavailable(mode)
        }
        let request = directionsRequest(from: source, to: destination, mode: mode,
                                        alternates: alternates, departure: departure,
                                        arrival: arrival, tolls: tolls, highways: highways)
        do {
            let response = try await MKDirections(request: request).calculate()
            let routes = response.routes.map { Route($0, requested: mode, polylineLimit: polylineLimit) }
            guard !routes.isEmpty else { throw PlacesError.noResults }
            return routes
        } catch let error as PlacesError {
            throw error
        } catch {
            throw PlacesError.from(error)
        }
    }

    /// How long a journey takes, for any mode — transit included.
    public func estimate(from source: Coordinate,
                         to destination: Coordinate,
                         mode: TransportMode = .automobile,
                         departure: Date? = nil,
                         arrival: Date? = nil) async throws -> Estimate {
        let request = directionsRequest(from: source, to: destination, mode: mode,
                                        alternates: false, departure: departure,
                                        arrival: arrival, tolls: .any, highways: .any)
        do {
            return Estimate(try await MKDirections(request: request).calculateETA())
        } catch {
            throw PlacesError.from(error)
        }
    }

    private func directionsRequest(from source: Coordinate, to destination: Coordinate,
                                   mode: TransportMode, alternates: Bool,
                                   departure: Date?, arrival: Date?,
                                   tolls: RoutePreference, highways: RoutePreference)
    -> MKDirections.Request {
        let request = MKDirections.Request()
        request.source = Places.mapItem(source)
        request.destination = Places.mapItem(destination)
        request.transportType = mode.transportType
        request.requestsAlternateRoutes = alternates
        request.departureDate = departure
        request.arrivalDate = arrival
        request.tollPreference = tolls.preference
        request.highwayPreference = highways.preference
        return request
    }

    /// A map item for a bare coordinate.
    ///
    /// `MKMapItem(placemark:)` is deprecated as of macOS 26; this is the
    /// replacement.
    static func mapItem(_ coordinate: Coordinate) -> MKMapItem {
        MKMapItem(location: coordinate.location, address: nil)
    }

    // MARK: - Autocomplete

    /// What a half-typed query completes to — the search-field suggestions.
    ///
    /// `MKLocalSearchCompleter`, the API a keyboard or search box wants: it is
    /// built for a partial fragment and answers far faster than a full search,
    /// because it returns query text rather than resolved places.
    ///
    /// A ``Suggestion`` carries **no coordinate**. Feed its
    /// ``Suggestion/searchText`` back into ``search(_:near:radiusMetres:categories:excluding:resultTypes:limit:)``
    /// when the user picks one.
    ///
    /// - Parameters:
    ///   - fragment: What has been typed so far.
    ///   - near: Biases results towards a place. Suggestions are not confined
    ///     to it — the region is a hint, not a filter.
    ///   - resultTypes: Addresses, points of interest, or both.
    public func suggest(_ fragment: String,
                        near: Coordinate? = nil,
                        radiusMetres: Double = Places.defaultRadiusMetres,
                        categories: [PointOfInterest] = [],
                        excluding: [PointOfInterest] = [],
                        resultTypes: ResultTypes = [.address, .pointOfInterest],
                        addressComponents: AddressComponents = [],
                        excludingAddressComponents: AddressComponents = [],
                        regionPriority: RegionPriority = .preferred,
                        limit: Int = 25) async throws -> [Suggestion] {
        let trimmed = fragment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PlacesError.invalidRegion("nothing typed") }
        do {
            let suggestions = try await Completer().suggestions(
                for: trimmed, near: near, radiusMetres: radiusMetres,
                regionPriority: regionPriority, resultTypes: resultTypes,
                categories: categories, excluding: excluding,
                addressComponents: addressComponents, excludingAddressComponents: excludingAddressComponents)
            // An empty completion list is a normal answer for a fragment that
            // matches nothing — not an error, unlike a search that found none.
            return limit > 0 ? Array(suggestions.prefix(limit)) : suggestions
        } catch let error as PlacesError {
            throw error
        } catch {
            throw PlacesError.from(error)
        }
    }

    // MARK: - Geocoding

    /// An address to coordinates.
    ///
    /// `MKGeocodingRequest`, MapKit's own geocoder (macOS/iOS 26+), rather
    /// than `CLGeocoder`. It answers a postal address directly, where a local
    /// search would rank it against businesses — and it fails in
    /// **`MKErrorDomain`**, so every call in this library now reports through
    /// one error domain instead of two. Measured 2026-09-05: identical
    /// coordinates to `CLGeocoder` for "10 Downing Street, London", a fuller
    /// address string, and nonsense fails `MKErrorDomain 4` where CoreLocation
    /// gave `kCLErrorDomain 8`.
    ///
    /// - Parameters:
    ///   - near: Biases ambiguous addresses — "Springfield" near here.
    ///   - locale: The language of the result's address strings. Nil is the
    ///     system locale.
    public func geocode(_ address: String,
                        near: Coordinate? = nil,
                        radiusMetres: Double = Places.defaultRadiusMetres,
                        locale: Locale? = nil) async throws -> [Place] {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PlacesError.invalidRegion("no address") }
        guard let request = MKGeocodingRequest(addressString: trimmed) else {
            throw PlacesError.invalidRegion("could not read that address")
        }
        if let near { request.region = near.region(radiusMetres: radiusMetres) }
        request.preferredLocale = locale
        do {
            let places = try await request.mapItems.compactMap { Place($0) }
            guard !places.isEmpty else { throw PlacesError.noResults }
            return places
        } catch let error as PlacesError {
            throw error
        } catch {
            throw PlacesError.from(error)
        }
    }

    /// Coordinates to an address.
    ///
    /// - Parameter locale: The language of the address strings. Nil is the system locale.
    public func reverseGeocode(_ coordinate: Coordinate, locale: Locale? = nil) async throws -> [Place] {
        guard let request = MKReverseGeocodingRequest(location: coordinate.location) else {
            throw PlacesError.invalidRegion("not a location on Earth")
        }
        request.preferredLocale = locale
        do {
            let places = try await request.mapItems.compactMap { Place($0) }
            guard !places.isEmpty else { throw PlacesError.noResults }
            return places
        } catch let error as PlacesError {
            throw error
        } catch {
            throw PlacesError.from(error)
        }
    }
}
