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
try await places.nearby([.restaurant], near: here, radiusMetres: 800)
try await places.search("Monmouth Coffee", near: here)
try await places.search("SW1A 2AA", resultTypes: [.address])
try await places.search("bar", near: here, excluding: [.nightlife])
```

**84 categories**, generated from `MKPointOfInterestCategory.h` in the installed
SDK rather than typed by hand, so the list cannot drift from Apple's. They are
built from their raw strings rather than the static constants — several are
gated to a newer OS, and going through the constants would either drop them
from the API or force the whole package up to macOS 27.

Results come back **nearest first** when you give a centre, with `distance` in
metres filled in. MapKit's own order is relevance, which is a different
question.

MapKit's filter is *including* **or** *excluding*, never both — pass both and
including wins.

## Directions

```swift
let routes = try await places.route(from: a, to: b, mode: .automobile,
                                    tolls: .avoid, highways: .any)
routes[0].distance          // metres
routes[0].travelTime        // seconds
routes[0].steps             // turn-by-turn
routes[0].hasTolls
routes[0].advisoryNotices   // ["Toll required.", "London ULEZ covers all boroughs"]
routes[0].polyline          // thinned to 100 points; 0 keeps all ~1,700
```

`advisoryNotices` is worth surfacing — the ULEZ and toll warnings live nowhere
else in the response.

## Transit is estimate-only, and that is Apple's rule

```swift
try await places.estimate(from: a, to: b, mode: .transit)   // 27 min, 7.6 km
try await places.route(from: a, to: b, mode: .transit)      // throws
```

Apple's header says it inline — `MKDirectionsTransportTypeTransit … // Only
supported for ETA calculations`. Ask for a route anyway and MapKit answers
`MKErrorDomain 5`, which reads like an outage rather than a documented limit;
this throws `.routeStepsUnavailable(.transit)` instead.

The estimate is real and worth having: measured London Paddington → Liverpool
Street at **27 minutes by transit against 46 by car**. `automobile`, `walking`
and `cycling` all give full routes *and* estimates.

## Two error domains

Search and directions fail in `MKErrorDomain`; **geocoding fails in
`kCLErrorDomain`**. A client reading only the first reports "no such address" as
an unexplained error — found by a live test here, and fixed. Throttling gets its
own case, because it means back off rather than retry.

## Tested

25 tests. Eighteen offline — the generated category table, coordinate parsing,
the filter's including-wins rule, polyline thinning keeping both ends, and both
error domains. Seven run against MapKit itself, skipped by default because it
throttles per app:

```console
$ PLACES_LIVE=1 swift test --filter LiveTests
```

All seven passed 2026-09-05.

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
