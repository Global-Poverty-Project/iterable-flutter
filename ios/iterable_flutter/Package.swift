// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "iterable_flutter",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "iterable-flutter", targets: ["iterable_flutter"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(url: "https://github.com/Iterable/swift-sdk", .upToNextMinor(from: "6.7.5"))
    ],
    targets: [
        .target(
            name: "iterable_flutter",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "IterableSDK", package: "swift-sdk")
            ]
        )
    ]
)
