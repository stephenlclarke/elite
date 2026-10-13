// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Elite",
  platforms: [.macOS(.v14)],
  products: [.executable(name: "Elite", targets: ["EliteMac"])],
  targets: [
    .target(name: "EliteCore", resources: [.process("Resources")]),
    .executableTarget(name: "EliteMac", dependencies: ["EliteCore"]),
    .testTarget(name: "EliteCoreTests", dependencies: ["EliteCore", "EliteMac"]),
  ]
)
