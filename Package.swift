// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Folio",
    platforms: [.macOS(.v12)],
    dependencies: [
        // GitHub's own Markdown parser (cmark-gfm), packaged by the Swift project.
        .package(url: "https://github.com/swiftlang/swift-cmark.git", branch: "gfm"),
    ],
    targets: [
        // Markdown -> HTML. No AppKit, so it is unit-testable on its own.
        .target(
            name: "FolioCore",
            dependencies: [
                .product(name: "cmark-gfm", package: "swift-cmark"),
                .product(name: "cmark-gfm-extensions", package: "swift-cmark"),
            ],
            path: "Sources/FolioCore"
        ),
        .executableTarget(
            name: "Folio",
            dependencies: ["FolioCore"],
            path: "Sources/Folio",
            linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("WebKit")]
        ),
        .testTarget(name: "FolioTests", dependencies: ["FolioCore"], path: "Tests/FolioTests"),
    ]
)
