// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MoveCore",
    platforms: [.macOS(.v26), .iOS(.v26), .watchOS(.v26)],
    products: [.library(name: "MoveCore", targets: ["MoveCore"]), .library(name: "MoveShared", targets: ["MoveShared"])],
    targets: [
        .target(name: "MoveCore"),
        .target(name: "MoveShared", dependencies: ["MoveCore"]),
        .testTarget(name: "MoveCoreTests", dependencies: ["MoveCore"]),
        .testTarget(name: "MoveSharedTests", dependencies: ["MoveShared"])
    ]
)
