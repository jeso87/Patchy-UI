// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PatchyKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PatchyKit", targets: ["PatchyKit"]),
    ],
    targets: [
        .target(name: "PatchyKit"),
        .testTarget(name: "PatchyKitTests", dependencies: ["PatchyKit"]),
    ]
)
