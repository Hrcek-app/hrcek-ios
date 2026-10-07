// swift-tools-version: 6.2
import PackageDescription

let strict: [SwiftSetting] = [.treatAllWarnings(as: .error)]

let package = Package(
    name: "HrcekKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "HrcekKit", targets: ["HrcekKit"])],
    targets: [
        .target(name: "HrcekKit", swiftSettings: strict),
        .testTarget(
            name: "HrcekKitTests",
            dependencies: ["HrcekKit"],
            resources: [.process("Resources")],
            swiftSettings: strict
        ),
    ]
)
