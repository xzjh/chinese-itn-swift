// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ChineseITN",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(name: "ChineseITN", targets: ["ChineseITN"]),
    ],
    targets: [
        .target(name: "ChineseITN"),
        .testTarget(
            name: "ChineseITNTests",
            dependencies: ["ChineseITN"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
