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
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Stackz",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "StackzTests",
            dependencies: ["Stackz"],
            path: "Tests"
        )
    ]
)
