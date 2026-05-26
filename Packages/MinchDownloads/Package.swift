// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MinchDownloads",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "MinchDownloads", targets: ["MinchDownloads"]),
    ],
    dependencies: [
        .package(path: "../MinchKit"),
        .package(path: "../MinchPersistence"),
    ],
    targets: [
        .target(name: "MinchDownloads", dependencies: ["MinchKit", "MinchPersistence"]),
    ]
)
