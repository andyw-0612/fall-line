// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "MarkingMenu",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "MarkingMenu", targets: ["MarkingMenu"])],
    targets: [
        .target(name: "MarkingCore"),
        .executableTarget(name: "MarkingMenu", dependencies: ["MarkingCore"]),
        .testTarget(name: "MarkingCoreTests", dependencies: ["MarkingCore"], resources: [.copy("Fixtures")]),
        .testTarget(name: "ProductFeedbackTests", dependencies: ["MarkingMenu", "MarkingCore"])
    ]
)
