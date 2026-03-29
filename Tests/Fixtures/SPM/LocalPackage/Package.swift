// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "LocalPackage",
    products: [
        .library(name: "LocalPackage", targets: ["LocalPackage"]),
    ],
    targets: [
        .target(name: "LocalPackage"),
    ]
)
