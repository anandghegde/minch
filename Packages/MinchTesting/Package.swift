// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MinchTesting",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "MinchTesting", targets: ["MinchTesting"]),
    ],
    dependencies: [
        .package(path: "../MinchKit"),
    ],
    targets: [
        .target(name: "MinchTesting", dependencies: ["MinchKit"]),
    ]
)
