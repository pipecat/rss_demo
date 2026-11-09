// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TopicReader",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "TopicReader", targets: ["ReaderMac"]),
               .executable(name: "ReaderChecks", targets: ["ReaderChecks"])],
    dependencies: [
        .package(url: "https://github.com/nmdias/FeedKit.git", exact: "10.10.2"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", exact: "2.14.3")
    ],
    targets: [
        .target(name: "ReaderDomain", path: "Packages/ReaderDomain"),
        .target(name: "ReaderApplication", dependencies: ["ReaderDomain"], path: "Packages/ReaderApplication"),
        .target(name: "ReaderAdapters", dependencies: ["ReaderDomain", "ReaderApplication", "FeedKit", "SwiftSoup"],
                path: "Packages/ReaderAdapters", resources: [.copy("Resources")]),
        .executableTarget(name: "ReaderMac", dependencies: ["ReaderDomain", "ReaderApplication", "ReaderAdapters"], path: "Apps/macOS"),
        .executableTarget(name: "ReaderChecks", dependencies: ["ReaderDomain", "ReaderApplication", "ReaderAdapters"], path: "Tests/ReaderChecks")
    ],
    swiftLanguageModes: [.v5]
)
