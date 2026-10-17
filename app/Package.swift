// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Bathys",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Bathys",
            path: "Sources/Bathys",
            exclude: [
                "submarine_raw.png"
            ],
            resources: [
                .copy("Assets"),
                .copy("submarine_clean.png")
            ]
        )
    ]
)
