// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Places",
    // MapKit search and directions are available far further back than this,
    // but the fleet floors at these. Nothing here needs a newer OS: the
    // macOS 26 address API is used when present and fallen back on below it.
    platforms: [
        .macOS(.v14), .iOS(.v16), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1),
    ],
    products: [
        .library(name: "Places", targets: ["Places"]),
    ],
    targets: [
        .target(name: "Places"),
        .testTarget(name: "PlacesTests", dependencies: ["Places"]),
    ]
)
