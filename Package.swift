// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ScreenGrid",
    platforms: [
        .macOS("26.0")
    ],
    targets: [
        .executableTarget(
            name: "ScreenGrid",
            path: "Sources/ScreenGrid"
        ),
        .testTarget(
            name: "ScreenGridTests",
            dependencies: ["ScreenGrid"],
            path: "Tests/ScreenGridTests"
        ),
    ]
)
