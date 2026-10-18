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
        .library(name: "Utils", targets: ["Utils"]),
        .library(name: "CacheKit", targets: ["CacheKit"]),
        .library(name: "RuntimeKit", targets: ["RuntimeKit"]),
        .library(name: "TransferKit", targets: ["TransferKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.12.3"),
        .package(url: "https://github.com/vapor/console-kit.git", from: "4.15.2"),
        .package(url: "https://github.com/kylehickinson/swiftui-webview.git", from: "0.3.1"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin.git", from: "1.4.5"),
        // 统一 lint 配置：build-tool 插件，**每次构建自动跑**（本地/CI 都能及时暴露）。
        // 0.0.7 起 OrzSwiftLint 改用 SwiftLint 官方**预编译二进制**（artifactbundle），
        // 插件照跑但不再编译 swift-syntax（下游冷编 554s→~几十秒、缓存 ~3GiB→几百MB）。
        .package(url: "https://github.com/OrzGeeker/OrzSwiftLint.git", from: "0.0.8"),
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
                     condition: .when(platforms: [.linux, .windows])),
            .product(name: "ConsoleKit", package: "console-kit"),
            "TransferKit",
            "Utils"
        ], plugins: [
            .plugin(name: "OrzSwiftLintBuildToolPlugin", package: "OrzSwiftLint")
        ]),
        .testTarget(name: "JokerKitsTests", dependencies: ["JokerKits"]),
        .target(name: "Utils", plugins: [
            .plugin(name: "OrzSwiftLintBuildToolPlugin", package: "OrzSwiftLint")
        ]),
        .target(name: "CacheKit", plugins: [
            .plugin(name: "OrzSwiftLintBuildToolPlugin", package: "OrzSwiftLint")
        ]),
        .testTarget(name: "CacheKitTests", dependencies: ["CacheKit"]),
        .target(name: "RuntimeKit", dependencies: ["Utils", "JokerKits"], plugins: [
            .plugin(name: "OrzSwiftLintBuildToolPlugin", package: "OrzSwiftLint")
        ]),
        .testTarget(name: "RuntimeKitTests", dependencies: ["RuntimeKit"]),
        .target(name: "TransferKit", dependencies: [
            .product(name: "Crypto",
                     package: "swift-crypto",
                     condition: .when(platforms: [.linux, .windows]))
        ], plugins: [
            .plugin(name: "OrzSwiftLintBuildToolPlugin", package: "OrzSwiftLint")
        ]),
        .testTarget(name: "TransferKitTests", dependencies: ["TransferKit"])
    ]
)
