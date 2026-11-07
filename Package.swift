// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenGuide",
    platforms: [.macOS("14.2")],
    products: [.executable(name: "OpenGuide", targets: ["OpenGuide"]),
               .library(name: "GuideCore", targets: ["GuideCore"])],
    targets: [
        .target(name: "GuideCore"),
        .executableTarget(name: "OpenGuide", dependencies: ["GuideCore"]),
        .testTarget(name: "GuideCoreTests", dependencies: ["GuideCore"]),
        .testTarget(name: "OpenGuideTests", dependencies: ["OpenGuide", "GuideCore"])
    ]
)
