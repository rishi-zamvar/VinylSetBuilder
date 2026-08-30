// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VinylSetBuilderCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "VinylSetBuilderCore", targets: ["VinylSetBuilderCore"])
    ],
    targets: [
        .target(name: "VinylSetBuilderCore"),
        .testTarget(
            name: "VinylSetBuilderCoreTests",
            dependencies: ["VinylSetBuilderCore"]
        ),
    ]
)
