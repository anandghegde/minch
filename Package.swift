// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Minch",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Minch", targets: ["Minch"]),
    ],
    dependencies: [
        .package(path: "Packages/MinchKit"),
        .package(path: "Packages/MinchAPI"),
        .package(path: "Packages/MinchPersistence"),
        .package(path: "Packages/MinchDownloads"),
        .package(path: "Packages/MinchUI"),
    ],
    targets: [
        .executableTarget(
            name: "Minch",
            dependencies: [
                .product(name: "MinchKit", package: "MinchKit"),
                .product(name: "MinchAPI", package: "MinchAPI"),
                .product(name: "MinchPersistence", package: "MinchPersistence"),
                .product(name: "MinchDownloads", package: "MinchDownloads"),
                .product(name: "MinchUI", package: "MinchUI"),
            ],
            path: "App/Minch",
            exclude: ["Info.plist", "AppIcon.icns"]
        ),
    ]
)
