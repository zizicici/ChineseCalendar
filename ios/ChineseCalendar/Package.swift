// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ChineseCalendar",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "ChineseCalendar",
            targets: ["ChineseCalendar"]
        )
    ],
    targets: [
        .target(
            name: "ChineseCalendar",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ChineseCalendarTests",
            dependencies: ["ChineseCalendar"]
        )
    ]
)
