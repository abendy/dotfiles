// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "disk-prune",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "DiskPruneCore",
            path: "Sources/DiskPruneCore"
        ),
        .executableTarget(
            name: "disk-prune",
            dependencies: ["DiskPruneCore"],
            path: "Sources/CLI"
        ),
        .executableTarget(
            name: "disk-prune-menubar",
            dependencies: ["DiskPruneCore"],
            path: "Sources/MenuBar"
        ),
    ]
)
