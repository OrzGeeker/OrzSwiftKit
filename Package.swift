// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OrzSwiftKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(name: "SwiftUIX", targets: ["SwiftUIX"]),
        .library(name: "JokerKits", targets: ["JokerKits"]),
        .library(name: "Utils", targets: ["Utils"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.4.0"),
        .package(url: "https://github.com/vapor/console-kit.git", from: "4.14.3"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.9.1"),
        .package(url: "https://github.com/kylehickinson/swiftui-webview.git", from: "0.3.0"),
        // 待[SwiftLint](https://github.com/realm/SwiftLint/blob/main/Package.swift)
        // 依赖 swift-argument-parser 版本 ~> 1.3.0 时可依赖
        //.package(url: "https://github.com/OrzGeeker/OrzSwiftLint.git", branch: "main")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(name: "SwiftUIX", dependencies: [
            "Utils",
            .product(name: "WebView", package: "swiftui-webview")
        ], plugins: [
            // .plugin(name: "OrzSwiftLintBuildToolPlugin", package: "OrzSwiftLint")
        ]),
        .testTarget(name: "SwiftUIXTests", dependencies: ["SwiftUIX"]),
        .target(name: "JokerKits", dependencies: [
            .product(name: "Crypto",
                     package: "swift-crypto",
                     condition: .when(platforms: [.linux])), "Alamofire",
            .product(name: "ConsoleKit", package: "console-kit"),
            "Utils"
        ], plugins: [
            // .plugin(name: "OrzSwiftLintBuildToolPlugin", package: "OrzSwiftLint")
        ]),
        .testTarget(name: "JokerKitsTests", dependencies: ["JokerKits"]),
        .target(name: "Utils", plugins: [
            // .plugin(name: "OrzSwiftLintBuildToolPlugin", package: "OrzSwiftLint")
        ])
    ]
)
