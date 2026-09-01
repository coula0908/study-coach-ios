// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "StudyCoachCore",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "StudyCoachCore",
            targets: ["StudyCoachCore"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "StudyCoachCore",
            dependencies: []
        ),
        .testTarget(
            name: "StudyCoachCoreTests",
            dependencies: ["StudyCoachCore"]
        ),
    ]
)
