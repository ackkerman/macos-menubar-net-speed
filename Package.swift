// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MenubarNetSpeed",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MenubarNetSpeed",
            path: "Sources",
            resources: [],
            linkerSettings: [
                .linkedFramework("Cocoa")
            ]
        )
    ]
)
