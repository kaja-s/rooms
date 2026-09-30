// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Rooms",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "RoomsCore", targets: ["RoomsCore"]),
        .library(name: "RoomsKit", targets: ["RoomsKit"]),
        .executable(name: "Rooms", targets: ["Rooms"]),
    ],
    targets: [
        .target(
            name: "RoomsCore"
        ),
        .target(
            name: "RoomsKit",
            dependencies: ["RoomsCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
            ]
        ),
        .executableTarget(
            name: "Rooms",
            dependencies: ["RoomsKit"]
        ),
        .testTarget(
            name: "RoomsCoreTests",
            dependencies: ["RoomsCore"]
        ),
        .testTarget(
            name: "RoomsKitTests",
            dependencies: ["RoomsKit"]
        ),
        .testTarget(
            name: "ConformanceTests",
            dependencies: ["RoomsCore", "RoomsKit"],
            path: "Tests/ConformanceTests"
        ),
    ]
)
