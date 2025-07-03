// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OrzSwiftKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "SwiftUIX", targets: ["SwiftUIX"]),
        .library(name: "JokerKits", targets: ["JokerKits"]),
        .library(name: "Utils", targets: ["Utils"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.12.3"),
        .package(url: "https://github.com/vapor/console-kit.git", from: "4.15.2"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.10.2"),
        .package(url: "https://github.com/kylehickinson/swiftui-webview.git", from: "0.3.1"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin.git", from: "1.4.5"),
        .package(url: "https://github.com/OrzGeeker/OrzSwiftLint.git", from: "0.0.4"),
    ],
    targets: [
        .target(name: "SwiftUIX", dependencies: [
            "Utils",
            .product(name: "WebView", package: "swiftui-webview")
        ], plugins: [
            .plugin(name: "OrzSwiftLintBuildToolPlugin", package: "OrzSwiftLint")
        ]),
        .testTarget(name: "SwiftUIXTests", dependencies: ["SwiftUIX"]),
        .target(name: "JokerKits", dependencies: [
            .product(name: "Crypto",
                     package: "swift-crypto",
                     condition: .when(platforms: [.linux])),
            .product(name: "Alamofire", package: "alamofire"),
            .product(name: "ConsoleKit", package: "console-kit"),
            "Utils"
        ], plugins: [
            .plugin(name: "OrzSwiftLintBuildToolPlugin", package: "OrzSwiftLint")
        ]),
        .testTarget(name: "JokerKitsTests", dependencies: ["JokerKits"]),
        .target(name: "Utils", plugins: [
            .plugin(name: "OrzSwiftLintBuildToolPlugin", package: "OrzSwiftLint")
        ])
    ]
)
