// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Elite",
  platforms: [.macOS(.v14)],
  products: [.executable(name: "Elite", targets: ["EliteMac"])],
  dependencies: [.package(url: "https://github.com/dduan/TOMLDecoder.git", exact: "0.4.5")],
  targets: [
    .target(
      name: "CLua",
      exclude: [
        "LICENSE.txt", "PROVENANCE.json", "lcorolib.c", "ldblib.c", "liolib.c", "loadlib.c",
        "loslib.c", "lstrlib.c", "ltablib.c", "lutf8lib.c", "linit.c",
      ], publicHeadersPath: "include"),
    .target(name: "MissionScript", dependencies: ["CLua"], publicHeadersPath: "include"),
    .target(
      name: "EliteCore",
      dependencies: ["MissionScript", .product(name: "TOMLDecoder", package: "TOMLDecoder")],
      resources: [
        .copy("Resources/Ships"), .copy("Resources/MissionPacks"), .process("Resources/Legal"),
        .copy("Resources/ScriptPacks"), .copy("Resources/ShipTextures"),
        .copy("Resources/OriginalWorlds"),
        .copy("Resources/OriginalShipTextures"),
        .copy("Resources/OriginalFleetShowroomModels"),
        .copy("Resources/OriginalMarkets"),
        .process("Resources/ModelLicenses"),
        .process("Resources/ASSET-NOTICE.txt"), .process("Resources/Oolite-LICENSE.txt"),
        .process("Resources/RescueStations-LICENSE.txt"), .process("Resources/Vector-MANIFEST.txt"),
        .process("Resources/CatalogueInputs.json"),
      ]),
    .executableTarget(name: "EliteMac", dependencies: ["EliteCore"]),
    .testTarget(name: "EliteCoreTests", dependencies: ["EliteCore", "EliteMac"]),
  ]
)
