// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "YipYip",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "YipYip", targets: ["YipYip"]),
        .library(name: "YipYipCore", targets: ["YipYipCore"]),
    ],
    targets: [
        .executableTarget(
            name: "YipYip",
            dependencies: ["YipYipCore"],
            path: "Sources/YipYip",
            linkerSettings: [
                .linkedFramework("Carbon"),
            ]
        ),
        .target(
            name: "YipYipCore",
            path: "Sources/YipYipCore",
            linkerSettings: [
                .linkedFramework("Security"),
            ]
        ),
        .testTarget(
            name: "YipYipCoreTests",
            dependencies: ["YipYipCore"],
            path: "Tests/YipYipCoreTests"
        ),
    ]
)
