// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MoveCore",
    platforms: [.macOS(.v26)],
    products: [.library(name: "MoveCore", targets: ["MoveCore"])],
    targets: [
        .target(name: "MoveCore"),
        .testTarget(name: "MoveCoreTests", dependencies: ["MoveCore"])
    ]
)
