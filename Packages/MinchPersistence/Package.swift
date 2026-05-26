// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MinchPersistence",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "MinchPersistence", targets: ["MinchPersistence"]),
    ],
    dependencies: [
        .package(path: "../MinchKit"),
    ],
    targets: [
        .target(name: "MinchPersistence", dependencies: ["MinchKit"]),
        .testTarget(name: "MinchPersistenceTests", dependencies: ["MinchPersistence", "MinchKit"]),
    ]
)
