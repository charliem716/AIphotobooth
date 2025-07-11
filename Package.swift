// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PhotoBooth",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "PhotoBooth",
            targets: ["PhotoBooth"])
    ],
    dependencies: [
        // OpenAI Swift SDK
        .package(url: "https://github.com/MacPaw/OpenAI.git", branch: "main"),
        // For loading environment variables
        .package(url: "https://github.com/thebarndog/swift-dotenv.git", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "PhotoBooth",
            dependencies: [
                .product(name: "OpenAI", package: "OpenAI"),
                .product(name: "SwiftDotenv", package: "swift-dotenv"),
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("AppKit"),
                .linkedFramework("Foundation")
            ]
        ),
        .testTarget(
            name: "PhotoBoothTests",
            dependencies: ["PhotoBooth"]
        ),
    ]
) 