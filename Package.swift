// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "Stackz",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Stackz", targets: ["Stackz"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.0")
    ],
    targets: [
        .executableTarget(
            name: "Stackz",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "StackzTests",
            dependencies: ["Stackz"],
            path: "Tests"
        )
    ]
)
