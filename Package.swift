// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DropLab",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "DropLabCore",
            targets: ["DropLabCore"]
        ),
        .executable(
            name: "droplab",
            targets: ["droplab"]
        ),
        .executable(
            name: "DropLabApp",
            targets: ["DropLabApp"]
        )
    ],
    targets: [
        .target(
            name: "DropLabCore",
            path: "Sources/DropLabCore"
        ),
        .executableTarget(
            name: "droplab",
            dependencies: ["DropLabCore"],
            path: "Sources/droplab"
        ),
        .executableTarget(
            name: "DropLabApp",
            dependencies: ["DropLabCore"],
            path: "Sources/DropLabApp"
        ),
        .testTarget(
            name: "DropLabCoreTests",
            dependencies: ["DropLabCore"],
            path: "Tests/DropLabCoreTests"
        )
    ]
)
