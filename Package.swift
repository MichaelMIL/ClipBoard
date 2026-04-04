// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClipboardApp",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "ClipboardApp", targets: ["ClipboardApp"]),
        .library(name: "ClipboardAppLib", targets: ["ClipboardAppLib"]),
    ],
    targets: [
        .target(
            name: "ClipboardAppLib",
            path: "Sources/ClipboardAppLib",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("UserNotifications"),
            ]
        ),
        .executableTarget(
            name: "ClipboardApp",
            dependencies: ["ClipboardAppLib"],
            path: "Sources/ClipboardApp",
            exclude: ["ExecutableInfo.plist", "Resources/logo.png"],
            resources: [
                .copy("Version.txt"),
            ],
            linkerSettings: [
                .linkedFramework("Carbon"),
                .unsafeFlags(
                    [
                        "-Xlinker", "-sectcreate",
                        "-Xlinker", "__TEXT",
                        "-Xlinker", "__info_plist",
                        "-Xlinker", "Sources/ClipboardApp/ExecutableInfo.plist",
                    ],
                    .when(platforms: [.macOS])
                ),
            ]
        ),
    ]
)
