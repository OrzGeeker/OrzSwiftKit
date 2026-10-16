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
        // 仅用于**按需** lint（`swift package plugin swiftlint fix`）。
        // 切勿把 `OrzSwiftLintBuildToolPlugin` 挂到 target 上：它会把 swift-syntax
        // 拽进每次（含 release）编译，实测让下游 CI 从 ~3min 涨到 ~9min、`.build`
        // 涨到 ~3GiB。构建质量门禁请交给独立的 lint 步骤（见父仓库 HANDOFF §5）。
        .package(url: "https://github.com/OrzGeeker/OrzSwiftLint.git", from: "0.0.6"),
    ],
    targets: [
        .target(name: "SwiftUIX", dependencies: [
            "Utils",
            .product(name: "WebView", package: "swiftui-webview")
        ]),
        .testTarget(name: "SwiftUIXTests", dependencies: ["SwiftUIX"]),
        .target(name: "JokerKits", dependencies: [
            .product(name: "Crypto",
                     package: "swift-crypto",
                     condition: .when(platforms: [.linux])),
            .product(name: "ConsoleKit", package: "console-kit"),
            "TransferKit",
            "Utils"
        ]),
        .testTarget(name: "JokerKitsTests", dependencies: ["JokerKits"]),
        .target(name: "Utils"),
        .target(name: "CacheKit"),
        .testTarget(name: "CacheKitTests", dependencies: ["CacheKit"]),
        .target(name: "RuntimeKit", dependencies: ["Utils", "JokerKits"]),
        .testTarget(name: "RuntimeKitTests", dependencies: ["RuntimeKit"]),
        .target(name: "TransferKit", dependencies: [
            .product(name: "Crypto",
                     package: "swift-crypto",
                     condition: .when(platforms: [.linux]))
        ]),
        .testTarget(name: "TransferKitTests", dependencies: ["TransferKit"])
    ]
)
