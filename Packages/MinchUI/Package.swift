// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MinchUI",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "MinchUI", targets: ["MinchUI"]),
    ],
    dependencies: [
        .package(path: "../MinchKit"),
    ],
    targets: [
        .target(name: "MinchUI", dependencies: ["MinchKit"]),
        .testTarget(name: "MinchUITests", dependencies: ["MinchUI"]),
    ]
)
