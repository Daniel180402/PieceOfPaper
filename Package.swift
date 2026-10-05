// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PieceOfPaper",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "PieceOfPaper", targets: ["PieceOfPaper"]),
        .library(name: "PaperKit", targets: ["PaperKit"]),
    ],
    targets: [
        .target(name: "PaperKit"),
        .executableTarget(
            name: "PieceOfPaper",
            dependencies: ["PaperKit"]
        ),
        .testTarget(
            name: "PaperKitTests",
            dependencies: ["PaperKit"]
        ),
    ]
)
