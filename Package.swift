// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Places",
    // MapKit search and directions are available far further back than this,
    // but the fleet floors at these. Nothing here needs a newer OS: the
    // macOS 26 address API is used when present and fallen back on below it.
    platforms: [
        .macOS("26.0"), .iOS("26.0"), .tvOS("26.0"), .watchOS("26.0"), .visionOS("26.0"),
    ],
    products: [
        .library(name: "Places", targets: ["Places"]),
    ],
    targets: [
        .target(name: "Places"),
        .testTarget(name: "PlacesTests", dependencies: ["Places"]),
    ]
)
