// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Mackey",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Mackey", targets: ["Mackey"])
    ],
    targets: [
        .executableTarget(
            name: "Mackey",
            path: "Sources",
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        ),
        .testTarget(
            name: "MackeyTests",
            dependencies: ["Mackey"],
            path: "Tests/MackeyTests"
        )
    ]
)
