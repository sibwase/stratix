// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DiagnosticsKit",
    platforms: [.macOS(.v14), .tvOS(.v26), .iOS(.v17)],
    products: [
        .library(name: "DiagnosticsKit", targets: ["DiagnosticsKit"])
    ],
    dependencies: [
        .package(path: "../StratixModels"),
        .package(path: "../../ThirdParty/swift-async-algorithms")
    ],
    targets: [
        .target(name: "DiagnosticsKit", dependencies: [
            .product(name: "StratixModels", package: "StratixModels"),
            .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
        ]),
        .testTarget(
            name: "DiagnosticsKitTests",
            dependencies: ["DiagnosticsKit"]
        )
    ]
)
