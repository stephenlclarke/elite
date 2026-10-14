// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Elite",
  platforms: [.macOS(.v14)],
  products: [.executable(name: "Elite", targets: ["EliteMac"])],
  dependencies: [.package(url: "https://github.com/dduan/TOMLDecoder.git", exact: "0.4.5")],
  targets: [
    .target(
      name: "EliteCore", dependencies: [.product(name: "TOMLDecoder", package: "TOMLDecoder")],
      resources: [
        .copy("Resources/Ships"), .process("Resources/Legal"), .process("Resources/ModelLicenses"),
        .process("Resources/ASSET-NOTICE.txt"), .process("Resources/Oolite-LICENSE.txt"),
        .process("Resources/RescueStations-LICENSE.txt"), .process("Resources/Vector-MANIFEST.txt"),
        .process("Resources/CatalogueInputs.json"),
      ]),
    .executableTarget(name: "EliteMac", dependencies: ["EliteCore"]),
    .testTarget(name: "EliteCoreTests", dependencies: ["EliteCore", "EliteMac"]),
  ]
)
