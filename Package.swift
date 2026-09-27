// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Macbeth",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "MacbethCore", targets: ["MacbethCore"]),
        .executable(name: "macbeth", targets: ["MacbethCLI"]),
        .executable(name: "macbeth-tests", targets: ["MacbethTests"]),
        .executable(name: "MacbethApp", targets: ["MacbethApp"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MacbethCore",
            dependencies: [],
            path: "Sources/MacbethCore",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "MacbethCLI",
            dependencies: ["MacbethCore"],
            path: "Sources/MacbethCLI"
        ),
        .executableTarget(
            name: "MacbethTests",
            dependencies: ["MacbethCore"],
            path: "Sources/MacbethTests"
        ),
        .executableTarget(
            name: "MacbethApp",
            dependencies: ["MacbethCore"],
            path: "Sources/MacbethApp"
        )
    ]
)
