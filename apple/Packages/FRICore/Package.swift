// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FRICore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "FRICore", targets: ["FRICore"]),
        .library(name: "FRIDesign", targets: ["FRIDesign"])
    ],
    targets: [
        .target(name: "FRICore", resources: [.process("Resources")]),
        .target(name: "FRIDesign"),
        .testTarget(name: "FRICoreTests", dependencies: ["FRICore"]),
        .testTarget(name: "FRIDesignTests", dependencies: ["FRIDesign"])
    ]
)
