// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Bathys",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Bathys",
            path: "Sources/Bathys",
            exclude: [
                // Immagini sorgente non usate a runtime: escluse dal bundle per non appesantire l'app
                "submarine_raw.png",
                "submarine_clean.png"
            ],
            resources: [
                .copy("Assets")
            ]
        )
    ]
)
