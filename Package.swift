// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QuickClip",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "QuickClip", targets: ["QuickClip"])
    ],
    targets: [
        .target(name: "QuickClipCore", path: "Sources/QuickClipCore"),
        .executableTarget(
            name: "QuickClip",
            dependencies: ["QuickClipCore"],
            path: "Sources/QuickClip"
        ),
        .testTarget(
            name: "QuickClipCoreTests",
            dependencies: ["QuickClipCore"],
            path: "Tests/QuickClipCoreTests"
        )
    ]
)
