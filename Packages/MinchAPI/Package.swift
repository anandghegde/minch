// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MinchAPI",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "MinchAPI", targets: ["MinchAPI"]),
    ],
    dependencies: [
        .package(path: "../MinchKit"),
    ],
    targets: [
        .target(name: "MinchAPI", dependencies: ["MinchKit"]),
        .testTarget(name: "MinchAPITests", dependencies: ["MinchAPI", "MinchKit"]),
    ]
)
