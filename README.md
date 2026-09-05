# swift-places

MapKit as plain values. Search, directions and geocoding — **nothing needed
from Apple**.

```swift
import Places

let places = Places()
let here = Coordinate(latitude: 51.5142, longitude: -0.1237)!

try await places.nearby([.restaurant, .cafe], near: here)
try await places.search("coffee", near: here, radiusMetres: 800)
try await places.route(from: here, to: there, mode: .automobile)
try await places.estimate(from: here, to: there, mode: .transit)
try await places.geocode("10 Downing Street, London")
```

## No entitlement, no key, no plist

Proven, not assumed. On 2026-09-05 a **bare Mach-O — no bundle, no Info.plist,
ad-hoc signed with an explicitly empty entitlements dict** — ran `MKLocalSearch`
and `MKDirections` successfully. `grep -rl "entitlement"` across every MapKit
header in the SDK finds nothing.

The `com.apple.developer.maps` capability that *does* exist in Xcode is for
**routing apps that Apple Maps hands off to** — an `MKDirectionsRequest`
extension with a coverage file. It has nothing to do with calling MapKit. And
it is **WeatherKit**, not MapKit, that needs an entitlement.

Works the same on iOS: the header is
`API_AVAILABLE(macos(10.9), ios(7.0), tvos(9.2), watchos(1.0))`.

**What this library deliberately does not do** is read the device's own
position. `CLLocationManager` is the one piece that needs
`NSLocationWhenInUseUsageDescription` and a user prompt — and that string has to
live in the consuming app anyway. This takes coordinates; getting them is the
app's job.

## Finding places

```swift
let places = Places()

try await places.search("coffee", near: here, radiusMetres: 800)
try await places.nearby([.restaurant, .cafe], near: here)          // MKLocalPointsOfInterestRequest
try await places.suggest("Trafalg", near: here)                    // autocomplete, as you type
try await places.geocode("10 Downing Street, London")              // address → place
try await places.reverseGeocode(here)                              // place → address
try await places.place(identifier: earlier.identifier!)            // the same place, later
```

**The region is a hint unless you say otherwise.** MapKit ranks by the region
you give but will still return a strong match outside it — right for a map
that pans, wrong for "within walking distance". `regionPriority: .required`
confines results to the region. Measured: a 400 m pizza search near Trafalgar
Square reaches Mayfair with `.preferred` and stays inside with `.required`.

**Addresses can be narrowed by kind.** `addressComponents: [.locality]` turns
a search for "Richmond" into towns called Richmond, not roads and postcodes
containing the word. It wraps `MKAddressFilter`; `search` and `suggest` both
take it.

**`nearby` uses the dedicated request**, not a text query built from
category names. On the same 500 m circle it returned 48 restaurants and cafés
against the text query's 25, and it honours the radius — the text query
matches words, not a region.

**Suggestions say where they matched.** A `Suggestion` carries MapKit's
highlight ranges for the title and subtitle, and `markedTitle()` renders them
— `**Trafalg**ar Square` — which is what a search field emboldens. A
suggestion is not a place: it has no coordinate. Feed its `searchText` back
into `search`.

**`searchResults` adds the bounding region** — the rectangle MapKit says
covers every result, which is what a map should show. `search` is the same
call returning only the places.

**Identifiers are stable; names and coordinates are not.** Every place from
a search carries MapKit's `identifier` (and any `alternateIdentifiers`).
`place(identifier:)` resolves one later through `MKMapItemRequest` — store
that, not a name to search for again.

**Geocoding takes a bias and a language.** `geocode("Springfield", near:
here)` prefers the nearby one; `locale: Locale(identifier: "de_DE")` returns
the address strings in German. Both go through `MKGeocodingRequest` and
`MKReverseGeocodingRequest`, MapKit's own geocoder as of macOS 26, so every
call in this library fails in one error domain.

### What a Place carries

`address` is the full single line ("10 Downing Street, London, SW1A 2AA,
England"), `shortAddress` the pin label ("10 Downing Street, London"),
`cityWithContext` the city placed ("London, England"), and `street` the
number and road only ("10 Downing Street"). The structured parts — locality,
administrative area, postcode, country, country code — come from the
placemark, because measured on macOS 27 the modern `MKAddressRepresentations`
offers no postcode or country at all and reports the **country** as the
region: `regionName` is "United Kingdom" where the placemark's administrative
area is "England". Each field is taken from the API that has it right.

## Directions

```swift
try await places.route(from: a, to: b, mode: .cycling, tolls: .avoid)
try await places.estimate(from: a, to: b, mode: .transit)
```

A `Route` has its name, distance, time, tolls and motorways, MapKit's advisory
notices (the ULEZ, in London), the steps, and the geometry thinned to
`polylineLimit` points. Each `RouteStep` has its own instruction, notice,
distance, mode and geometry — what a turn-by-turn view draws for the current
manoeuvre.

**Cycling comes back labelled `automobile`.** MapKit computes a genuinely
cycling-aware route — different roads, an advisory reading "Cycle routes and
main roads" — and stamps the result `automobile`. `Route.mode` is the mode
you asked for; `reportedMode` keeps MapKit's label so the discrepancy is
visible rather than hidden.

## Tested

45 tests: 26 offline (models, filters, the 84-category table generated from
Apple's header, the run-loop-backed completer's shape) and 19 live against
MapKit, run with `PLACES_LIVE=1 swift test --filter LiveTests`. The live
suite is where the numbers in this README come from — `.required` staying
inside 400 m where `.preferred` reaches further, 48 places against 25, the
German locale naming the country in German, cycling labelled `automobile`,
a place found again by its identifier — and it is what caught the completer
hanging without a run loop, and the modern address API reporting a country
as a region.

Audited against the macOS 27 SDK headers on 2026-09-06: every data-bearing
MapKit request — `MKLocalSearch`, `MKLocalPointsOfInterestRequest`,
`MKLocalSearchCompleter`, `MKDirections` (routes and ETAs), `MKGeocodingRequest`,
`MKReverseGeocodingRequest`, `MKMapItemRequest` — and every field of
`MKMapItem`, `MKRoute`, `MKRoute.Step`, `MKETAResponse` and
`MKLocalSearchCompletion` is reachable from this library. Not wrapped, by
choice: `MKMapSnapshotter` and Look Around (they produce images, a different
tool), `openInMaps` (an app concern; `Place.mapsURL` is the headless form),
and `MKMapItem.forCurrentLocation()` (needs location permission, so it
cannot be tested headless).

## Requirements

macOS 14+ / iOS 16+ / tvOS 16+ / watchOS 9+ / visionOS 1+ · Swift 6 · no
dependencies. The macOS 26 address API is used where present and fallen back on
below it, so there are no deprecation warnings on a modern SDK and no floor
raise on an older one.

MapKit is rate-limited per app. The limit is undocumented; exceeding it
surfaces as `PlacesError.throttled`.

## Installation

```swift
.package(url: "https://github.com/arraypress/swift-places.git", from: "0.1.0")
```

## Licence

MIT
