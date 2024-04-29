// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OrzSwiftKit",
    platforms: [
        .iOS(.v13),
        .macOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(name: "OrzSwiftKit", targets: ["OrzSwiftKit"]),
        .library(name: "JokerKits", targets: ["JokerKits"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.3.0"),
        .package(url: "https://github.com/vapor/console-kit.git", from: "4.14.1"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.9.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "OrzSwiftKit"),

        .testTarget(
            name: "OrzSwiftKitTests",
            dependencies: ["OrzSwiftKit"]),

        .target(
            name: "JokerKits",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux])),
                "Alamofire",
                .product(name: "ConsoleKit", package: "console-kit")
            ]
        ),
        .testTarget(
            name: "JokerKitsTests",
            dependencies: ["JokerKits"]
        )
    ]
)