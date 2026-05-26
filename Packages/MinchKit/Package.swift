// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MinchKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "MinchKit", targets: ["MinchKit"]),
    ],
    targets: [
        .target(name: "MinchKit"),
        .testTarget(name: "MinchKitTests", dependencies: ["MinchKit"]),
    ]
)
