// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "LosNotches",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "NookCore"),
        .executableTarget(
            name: "LosNotches",
            dependencies: ["NookCore"],
            linkerSettings: [.linkedFramework("IOBluetooth"), .linkedFramework("CoreBluetooth")]
        ),
        .testTarget(name: "NookCoreTests", dependencies: ["NookCore"]),
    ],
    swiftLanguageModes: [.v5]
)
