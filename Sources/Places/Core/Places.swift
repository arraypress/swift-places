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
                       limit: Int = 25) async throws -> [Place] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PlacesError.invalidRegion("no query") }
        guard radiusMetres > 0 else { throw PlacesError.invalidRegion("radius must be positive") }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = resultTypes.searchResultType
        if let near { request.region = near.region(radiusMetres: radiusMetres) }
        request.pointOfInterestFilter = Places.filter(including: categories, excluding: excluding)

        return try await run(request, near: near, limit: limit)
    }

    /// Places of a kind, near a point — "restaurants around here".
    ///
    /// MapKit has no category-only search, so the categories are also used as
    /// the query text. That is what makes `nearby([.restaurant])` behave the
    /// way a caller expects rather than returning nothing.
    public func nearby(_ categories: [PointOfInterest],
                       near: Coordinate,
                       radiusMetres: Double = Places.defaultRadiusMetres,
                       limit: Int = 25) async throws -> [Place] {
        guard !categories.isEmpty else { throw PlacesError.invalidRegion("no categories") }
        let query = categories.map(\.displayName).joined(separator: " ")
        return try await search(query, near: near, radiusMetres: radiusMetres,
                                categories: categories,
                                resultTypes: [.pointOfInterest], limit: limit)
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

    private func run(_ request: MKLocalSearch.Request,
                     near: Coordinate?, limit: Int) async throws -> [Place] {
        do {
            let response = try await MKLocalSearch(request: request).start()
            var places = response.mapItems.compactMap { Place($0, from: near) }
            guard !places.isEmpty else { throw PlacesError.noResults }
            // Nearest first when there is a centre to measure from; MapKit's
            // own order is relevance, which is not the same question.
            if near != nil {
                places.sort { ($0.distance ?? .greatestFiniteMagnitude) < ($1.distance ?? .greatestFiniteMagnitude) }
            }
            return limit > 0 ? Array(places.prefix(limit)) : places
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
            let routes = response.routes.map { Route($0, polylineLimit: polylineLimit) }
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
        if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
            request.tollPreference = tolls.preference
            request.highwayPreference = highways.preference
        }
        return request
    }

    /// A map item for a bare coordinate.
    ///
    /// `MKMapItem(placemark:)` was deprecated in macOS 26 in favour of
    /// `init(location:address:)`, so both are here.
    static func mapItem(_ coordinate: Coordinate) -> MKMapItem {
        if #available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) {
            return MKMapItem(location: coordinate.location, address: nil)
        }
        return MKMapItem(placemark: MKPlacemark(coordinate: coordinate.clCoordinate))
    }

    // MARK: - Geocoding

    /// An address to coordinates.
    ///
    /// CoreLocation rather than MapKit: `CLGeocoder` answers a postal address
    /// directly, where a local search would rank it against businesses.
    public func geocode(_ address: String) async throws -> [Place] {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PlacesError.invalidRegion("no address") }
        do {
            let placemarks = try await CLGeocoder().geocodeAddressString(trimmed)
            let places = placemarks.compactMap(Place.init)
            guard !places.isEmpty else { throw PlacesError.noResults }
            return places
        } catch let error as PlacesError {
            throw error
        } catch {
            throw PlacesError.from(error)
        }
    }

    /// Coordinates to an address.
    public func reverseGeocode(_ coordinate: Coordinate) async throws -> [Place] {
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(coordinate.location)
            let places = placemarks.compactMap(Place.init)
            guard !places.isEmpty else { throw PlacesError.noResults }
            return places
        } catch let error as PlacesError {
            throw error
        } catch {
            throw PlacesError.from(error)
        }
    }
}
