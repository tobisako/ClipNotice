// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClipNotice",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "clipnotice",
            path: "Sources/ClipNotice"
        )
    ]
)
