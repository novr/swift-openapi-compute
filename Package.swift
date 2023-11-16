// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-openapi-compute",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "OpenAPICompute",
            targets: ["OpenAPICompute"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "0.3.6"),
        .package(url: "https://github.com/swift-cloud/Compute", from: "2.18.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "OpenAPICompute",
            dependencies: [
                .product(name: "Compute", package: "Compute"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            ]),
        .testTarget(
            name: "OpenAPIComputeTests",
            dependencies: ["OpenAPICompute"]),
    ]
)
