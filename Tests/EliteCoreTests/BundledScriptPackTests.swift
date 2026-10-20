import CryptoKit
import Foundation
import Testing

@testable import EliteCore

private let bundledCourierDigest =
  "65ff79fef1171fa0c0af8808754c075e93c0302a33fb3e0b04fa59f59585b369"

private let bundledBondedDigest =
  "08dfba917d8f630b0fb39a4458ec1fa06245eb1347352a172a7576c0967682ca"

private let bundledColdChainDigest =
  "28d0072262956e974bc2033f8b0e984e1b35780a98b6861a1a81b4ca43c7487f"

private let bundledRepairLoopDigest =
  "c0b674ac2eca0221890412446f423c5f7ada4520b38669dbfbef5289049c199f"

private let bundledSeedTransferDigest =
  "feadc6cc8bed2b59a608dc0667afd11a5d7c1e790e2466e3b8c44974f9f03d54"

private let bundledMutualContributionDigest =
  "d4691b29ad9bc6f2fae1fa07345a96b38068857d427eb1977d7ced498ff698bf"

private let bundledNavigationTradeDigest =
  "8c23ce72936e8bdfa47978f7d7d4240171babe05c2da5ac49727d2616e38d802"

private let bundledSealedDispatchDigest =
  "93289d5daf873d0cf878b37fa55178e4ab91cf6fa1947f379a54c3bc04267ae7"

private let bundledOriginalRescueDigest = NativeOriginalRescueJourney.digest
private let bundledOrbitalOutlookDigest =
  "cf5076adbecad912603ddd146aeb2ead31621bf698ff4a4a7071a2b66b2cf798"

private let bundledCabinJourneyDigest =
  "2e2f46e0bed56f79c489cf21c438289c07469511336beaf1ef953f38253dc800"
private let bundledConsentedFreightDigest =
  "37ca73ed1b3f3656c42baedaf8dbaa3ee8aa3798ccf23e376c3c25ceac9bd572"
private let bundledCorridorDefenceDigest =
  "ec6b00bfe07466f4d205c415adff00ef1fb0a9a56b487d5a1312dfe3f314762c"
private let bundledVerifiedWarrantDigest =
  "f125be8200d0dd3ae834f2dc4cd52da46f7c571de7e67cbec61f76c7beab9911"

private struct BundledScriptFixture {
  let root: URL
  var library: URL { root.appendingPathComponent("installed") }
  var save: URL { root.appendingPathComponent("commander.json") }

  init() throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "bundled-script-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  }

  func clean() { try? FileManager.default.removeItem(at: root) }

  func variant(_ name: String, version: String = "1.0.0", comment: String = "") throws -> ScriptPack
  {
    let folder = root.appendingPathComponent(name)
    try FileManager.default.copyItem(at: ScriptPackLibrary.bundledCourierDirectory, to: folder)
    let manifest = folder.appendingPathComponent("manifest.toml")
    let text = try String(contentsOf: manifest, encoding: .utf8)
    try text.replacingOccurrences(of: "version = \"1.0.0\"\n", with: "version = \"\(version)\"\n")
      .write(to: manifest, atomically: true, encoding: .utf8)
    if !comment.isEmpty {
      let module = folder.appendingPathComponent("scripts/main.lua")
      let lua = try String(contentsOf: module, encoding: .utf8)
      try (lua + "\n-- " + comment + "\n").write(to: module, atomically: true, encoding: .utf8)
    }
    return try ScriptPackLibrary.read(folder)
  }

  // This restore test needs an admissible package-1; it does not assert route availability at Avenor.
  func restorableCourierSourceGame() throws -> Game {
    let providers = ScriptPackLibrary.defaultLibrary(directory: library)
    try #require(providers.errors.isEmpty)
    let courier = try #require(providers.packs.first { $0.digest == bundledCourierDigest })
    for source in Universe.systemsIncludingPlugh(number: 0) where source.original != nil {
      var initial = game()
      initial.commander.system = source.id
      initial.selectedSystem = source.id
      initial.market = MarketItem.at(initial.currentSystem)
      try initial.commander.prepareEquipment(legacy: false)
      initial.commander.mirrorFittedEquipment()
      // Probe only an isolated initial-scene copy. The runtime generates its own board/quote.
      var probe = initial
      probe.scriptPacks = providers.packs
      probe.scriptDurabilityAvailable = true
      let key = try probe.ensureContractBoard(courier)
      let offer = try #require(
        probe.commander.contracts.boards[key]?.offers.first { $0.key == "package-1" })
      if probe.contractAcceptanceQuote(board: key, offer: offer.id).allowed {
        return initial
      }
    }
    throw MissionPackError(
      "No ordinary initial source has an admissible unchanged package-1 quote.")
  }

  func game() -> Game {
    var game = Game(executive: false)
    game.screen = .status
    game.commander.credits = 100_000
    return game
  }
}

struct BundledScriptPackTests {
  @Test func bundledCourierRetainsApprovedResourceBytesAndContentIdentity() throws {
    let folder = ScriptPackLibrary.bundledCourierDirectory
    let docs = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/generated-couriers")
    for (name, expected) in [
      ("manifest.toml", "f4c2a1bb538f257a229cce4911c81c4471a0aa92b2d30fe1605959c0740407f6"),
      ("scripts/main.lua", "7134b0c5633be2c742d9bcc3dc9768d1966dade002685060a6db3794b18de046"),
    ] {
      let bytes = try Data(contentsOf: folder.appendingPathComponent(name))
      #expect(bytes == (try Data(contentsOf: docs.appendingPathComponent(name))))
      #expect(SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() == expected)
    }
    let pack = try ScriptPackLibrary.read(folder)
    #expect(pack.digest == bundledCourierDigest && pack.manifest.version == "1.0.0")
    #expect(pack.manifest.id == "project.generated-couriers" && pack.missingCapabilities.isEmpty)
  }

  @Test func defaultDiscoveryIsReadOnlyAndExplicitMissingDirectoryStaysExternalOnly() async throws {
    let fixture = try BundledScriptFixture()
    defer { fixture.clean() }
    let runtime = GameRuntime(game: fixture.game())
    let before = await runtime.snapshot()
    await runtime.loadScriptPacks(directory: fixture.library)
    let initiallyLoadedPacks = await runtime.snapshot().scriptPacks
    #expect(initiallyLoadedPacks.isEmpty)
    let errors = await runtime.loadDefaultScriptPacks(directory: fixture.library)
    let discovered = await runtime.snapshot()
    #expect(
      errors.isEmpty
        && discovered.scriptPacks.map(\.digest) == [
          bundledCourierDigest, bundledBondedDigest, bundledColdChainDigest,
          bundledRepairLoopDigest, bundledSeedTransferDigest, bundledMutualContributionDigest,
          bundledNavigationTradeDigest, bundledSealedDispatchDigest, bundledVerifiedWarrantDigest,
          bundledCorridorDefenceDigest, bundledConsentedFreightDigest, bundledCabinJourneyDigest,
          bundledOrbitalOutlookDigest, bundledOriginalRescueDigest, NativeOriginalEvacuation.digest,
          NativeOriginalSurvey.digest, NativeIdentifiedSalvage.digest,
        ])
    #expect(discovered.commander == before.commander && discovered.bodies == before.bodies)
    #expect(discovered.commander.scriptState.instances.isEmpty)
    #expect(discovered.commander.contracts.boards.isEmpty && !discovered.requiresScriptDurability)
    #expect(discovered.scriptGallery.first?.status == .locked)
    #expect(!FileManager.default.fileExists(atPath: fixture.library.path))
    #expect(!FileManager.default.fileExists(atPath: fixture.save.path))
    await runtime.loadScriptPacks(directory: fixture.library)
    let explicitlyReloadedPacks = await runtime.snapshot().scriptPacks
    #expect(explicitlyReloadedPacks.isEmpty)
  }

  @Test func identicalInstalledCopyDeduplicatesWithoutRewritingUserContent() throws {
    let fixture = try BundledScriptFixture()
    defer { fixture.clean() }
    let pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledCourierDirectory)
    let installed = try ScriptPackLibrary.install(pack, directory: fixture.library)
    let manifest = installed.appendingPathComponent("manifest.toml")
    let module = installed.appendingPathComponent("scripts/main.lua")
    let beforeManifest = try Data(contentsOf: manifest)
    let beforeModule = try Data(contentsOf: module)
    let library = ScriptPackLibrary.defaultLibrary(directory: fixture.library)
    #expect(
      library.errors.isEmpty
        && library.packs.map(\.digest) == [
          bundledCourierDigest, bundledBondedDigest, bundledColdChainDigest,
          bundledRepairLoopDigest, bundledSeedTransferDigest, bundledMutualContributionDigest,
          bundledNavigationTradeDigest, bundledSealedDispatchDigest, bundledVerifiedWarrantDigest,
          bundledCorridorDefenceDigest, bundledConsentedFreightDigest, bundledCabinJourneyDigest,
          bundledOrbitalOutlookDigest, bundledOriginalRescueDigest, NativeOriginalEvacuation.digest,
          NativeOriginalSurvey.digest, NativeIdentifiedSalvage.digest,
        ])
    #expect(try Data(contentsOf: manifest) == beforeManifest)
    #expect(try Data(contentsOf: module) == beforeModule)
    #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.library.path).count == 1)
  }

  @Test(arguments: ["same-version", "different-version"])
  func installedDistinctContentKeepsItsIdentityAndExternalOrdering(_ kind: String) async throws {
    let fixture = try BundledScriptFixture()
    defer { fixture.clean() }
    let pack = try fixture.variant(
      kind, version: kind == "different-version" ? "1.0.1" : "1.0.0", comment: kind)
    let installed = try ScriptPackLibrary.install(pack, directory: fixture.library)
    let library = ScriptPackLibrary.defaultLibrary(directory: fixture.library)
    #expect(library.errors.isEmpty)
    #expect(
      library.packs.map(\.digest) == [
        pack.digest, bundledCourierDigest, bundledBondedDigest, bundledColdChainDigest,
        bundledRepairLoopDigest, bundledSeedTransferDigest, bundledMutualContributionDigest,
        bundledNavigationTradeDigest, bundledSealedDispatchDigest, bundledVerifiedWarrantDigest,
        bundledCorridorDefenceDigest, bundledConsentedFreightDigest, bundledCabinJourneyDigest,
        bundledOrbitalOutlookDigest, bundledOriginalRescueDigest, NativeOriginalEvacuation.digest,
        NativeOriginalSurvey.digest, NativeIdentifiedSalvage.digest,
      ])
    #expect(library.packs[0].manifest.version == pack.manifest.version)
    #expect(try ScriptPackLibrary.read(installed).digest == pack.digest)
    let explicit = GameRuntime(game: fixture.game())
    await explicit.loadScriptPacks(directory: fixture.library)
    let explicitlyLoadedDigests = await explicit.snapshot().scriptPacks.map(\.digest)
    #expect(explicitlyLoadedDigests == [pack.digest])
  }

  @Test func malformedInstalledContentReportsItsErrorAlongsideBundledCourier() async throws {
    let fixture = try BundledScriptFixture()
    defer { fixture.clean() }
    try FileManager.default.createDirectory(at: fixture.library, withIntermediateDirectories: true)
    try Data("broken".utf8).write(to: fixture.library.appendingPathComponent("broken"))
    let runtime = GameRuntime(game: fixture.game())
    let before = await runtime.snapshot()
    let errors = await runtime.loadDefaultScriptPacks(directory: fixture.library)
    let after = await runtime.snapshot()
    #expect(errors.count == 1 && errors[0].contains("broken"))
    #expect(after.message.contains("broken") && after.commander == before.commander)
    #expect(
      after.scriptPacks.map(\.digest) == [
        bundledCourierDigest, bundledBondedDigest, bundledColdChainDigest, bundledRepairLoopDigest,
        bundledSeedTransferDigest, bundledMutualContributionDigest, bundledNavigationTradeDigest,
        bundledSealedDispatchDigest, bundledVerifiedWarrantDigest, bundledCorridorDefenceDigest,
        bundledConsentedFreightDigest, bundledCabinJourneyDigest, bundledOrbitalOutlookDigest,
        bundledOriginalRescueDigest, NativeOriginalEvacuation.digest, NativeOriginalSurvey.digest,
        NativeIdentifiedSalvage.digest,
      ])
  }

  @Test func defaultCourierOpensRealContractsAndAnIsolatedGalleryTrial() async throws {
    let fixture = try BundledScriptFixture()
    defer { fixture.clean() }
    let runtime = GameRuntime(game: fixture.game(), saveURL: fixture.save)
    let errors = await runtime.loadDefaultScriptPacks(directory: fixture.library)
    #expect(errors.isEmpty)
    let discovered = await runtime.snapshot()
    #expect(
      discovered.scriptGallery.contains {
        $0.trialDigest == bundledCourierDigest && $0.status == .available
      })
    #expect(discovered.commander.contracts.boards.isEmpty)
    await runtime.key("contracts-open")
    let contracts = await runtime.snapshot()
    #expect(contracts.screen == .contracts && contracts.contractBoard.rows.count == 22)
    let repairRows = contracts.contractBoard.rows.filter {
      $0.repairLoop?.digest == bundledRepairLoopDigest
    }
    #expect(
      repairRows.count == 1 && repairRows[0].repairLoop?.action == .unavailable
        && repairRows[0].reason != nil)
    let reliefRows = contracts.contractBoard.rows.filter {
      $0.board.hasPrefix(bundledMutualContributionDigest + "/")
    }
    #expect(reliefRows.count == 1 && reliefRows[0].offer == nil && reliefRows[0].reason != nil)
    let seedRows = contracts.contractBoard.rows.filter {
      $0.coldChain?.digest == bundledSeedTransferDigest
    }
    #expect(
      seedRows.count == 1 && seedRows[0].coldChain?.action == .unavailable
        && seedRows[0].reason != nil)
    let coldRows = contracts.contractBoard.rows.filter {
      $0.coldChain?.digest == bundledColdChainDigest
    }
    #expect(
      coldRows.count == 1 && coldRows[0].coldChain?.action == .unavailable
        && coldRows[0].reason != nil)
    #expect(
      contracts.commander.scriptState.instances.isEmpty && contracts.commander.cargoTonnes == 0)
    let board = try #require(
      contracts.commander.contracts.boards.values.first { $0.digest == bundledCourierDigest })
    #expect(board.digest == bundledCourierDigest)
    let bondedRows = contracts.contractBoard.rows.filter {
      $0.board.hasPrefix(bundledBondedDigest + "/")
    }
    #expect(bondedRows.count == 1 && bondedRows[0].offer == nil && bondedRows[0].reason != nil)
    #expect(
      contracts.contractBoard.rows.filter { $0.board.hasPrefix(bundledCourierDigest + "/") }.count
        == 6)
    #expect(
      board.offers.map(\.key)
        == ["data-1", "package-1", "data-2", "package-2", "data-3", "package-3"])
    await runtime.key("gallery-open")
    let live = await runtime.snapshot()
    let savedBytes = try Data(contentsOf: fixture.save)
    try await runtime.startScriptGalleryTrial(packDigest: bundledCourierDigest, seed: 42)
    let trialDirectory = await runtime.gallerySaveDirectory()
    let namespace = try #require(trialDirectory)
    defer { try? FileManager.default.removeItem(at: namespace) }
    let trial = await runtime.snapshot()
    #expect(trial.isMissionTrial && trial.screen == .contracts)
    #expect(trial.contractBoard.rows.filter { $0.people == .journey(.request) }.count == 1)
    #expect(trial.contractBoard.rows.filter { $0.people == .outlook(.request) }.count == 1)
    #expect(contracts.contractBoard.rows.filter { $0.people == .outlook(.request) }.count == 1)
    #expect(contracts.contractBoard.rows.filter { $0.people == .journey(.request) }.count == 1)
    #expect(trial.contractBoard.rows.count == 22 && trial.contractBoard.action == .back)
    #expect(
      trial.contractBoard.rows.filter { $0.coldChain?.digest == bundledColdChainDigest }.count == 1)
    #expect(
      trial.contractBoard.rows.filter {
        $0.repairLoop?.digest == bundledRepairLoopDigest
      }.count == 1)
    #expect(
      trial.contractBoard.rows.filter {
        $0.coldChain?.digest == bundledSeedTransferDigest
      }.count == 1)
    #expect(
      trial.contractBoard.rows.filter {
        $0.board.hasPrefix(bundledMutualContributionDigest + "/")
      }.count == 1)
    let trialBondedRows = trial.contractBoard.rows.filter {
      $0.board.hasPrefix(bundledBondedDigest + "/")
    }
    #expect(
      trialBondedRows.count == 1 && trialBondedRows[0].offer == nil
        && trialBondedRows[0].reason != nil)
    #expect(
      trial.contractBoard.rows.filter { $0.board.hasPrefix(bundledCourierDigest + "/") }.count == 6)
    #expect(trial.commander.scriptState.instances.isEmpty)
    #expect(
      FileManager.default.fileExists(
        atPath: namespace.appendingPathComponent("commander.json").path))
    #expect(try Data(contentsOf: fixture.save) == savedBytes)
    try await runtime.returnFromScriptGalleryTrial()
    let returnedCommander = await runtime.snapshot().commander
    #expect(returnedCommander == live.commander)
    #expect(try Data(contentsOf: fixture.save) == savedBytes)
  }

  @Test func defaultDiscoveryRestoresTheSavedOriginalDigestBesideChangedSameVersionContent()
    async throws
  {
    let fixture = try BundledScriptFixture()
    defer { fixture.clean() }
    let initial = try fixture.restorableCourierSourceGame()
    let runtime = GameRuntime(game: initial, saveURL: fixture.save)
    _ = await runtime.loadDefaultScriptPacks(directory: fixture.library)
    let key = try await runtime.generateContractBoard(packDigest: bundledCourierDigest)
    let generated = await runtime.snapshot()
    let board = try #require(generated.commander.contracts.boards[key])
    let offer = try #require(board.offers.first { $0.key == "package-1" })
    let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
    try #require(quote.allowed, Comment(rawValue: quote.issues.joined(separator: "; ")))
    let terms = try #require(quote.courier?.terms)
    print(
      "RESTORE_COURIER_SOURCE galaxy=\(initial.commander.galaxy) system=\(initial.commander.system) name=\(initial.currentSystem.name) offer=\(offer.key) allowed=\(quote.allowed) path=\(terms.path) lowerBound=\(terms.calendarLowerBoundSeconds) duration=\(terms.duration) ship=\(initial.commander.shipID) fuel=\(initial.commander.fuel) credits=\(initial.commander.credits)"
    )
    #expect(
      generated.commander.shipID == initial.commander.shipID
        && generated.commander.fuel == initial.commander.fuel)
    #expect(
      generated.commander.cargo == initial.commander.cargo
        && generated.commander.credits == initial.commander.credits)
    let id = try await runtime.confirmContract(quote)
    let accepted = await runtime.snapshot()
    let state = try #require(accepted.commander.scriptState.instances[id])
    let custody = try #require(state.courier)
    #expect(state.digest == bundledCourierDigest && accepted.commander.cargoTonnes == 1)
    let savedBytes = try Data(contentsOf: fixture.save)
    let changed = try fixture.variant("changed", comment: "Distinct installed same-version content")
    _ = try ScriptPackLibrary.install(changed, directory: fixture.library)
    let restored = GameRuntime(game: fixture.game())
    _ = await restored.loadDefaultScriptPacks(directory: fixture.library)
    try await restored.load(from: fixture.save)
    let loaded = await restored.snapshot()
    let retained = try #require(loaded.commander.scriptState.instances[id])
    #expect(
      loaded.scriptPacks.map(\.digest) == [
        changed.digest, bundledCourierDigest, bundledBondedDigest, bundledColdChainDigest,
        bundledRepairLoopDigest, bundledSeedTransferDigest, bundledMutualContributionDigest,
        bundledNavigationTradeDigest, bundledSealedDispatchDigest, bundledVerifiedWarrantDigest,
        bundledCorridorDefenceDigest, bundledConsentedFreightDigest, bundledCabinJourneyDigest,
        bundledOrbitalOutlookDigest, bundledOriginalRescueDigest, NativeOriginalEvacuation.digest,
        NativeOriginalSurvey.digest, NativeIdentifiedSalvage.digest,
      ])
    #expect(loaded.scriptPack(for: retained)?.digest == bundledCourierDigest)
    #expect(retained.digest == state.digest && retained.version == state.version)
    #expect(retained.courier == custody && retained.contract == state.contract)
    #expect(loaded.commander.contracts == accepted.commander.contracts)
    #expect(loaded.commander.cargoTonnes == 1)
    #expect(try Data(contentsOf: fixture.save) == savedBytes)
  }
}

struct BundledOriginalSurveyPackTests {
  @Test func installedOriginalSurveyHasClosedTargetsAndProductionDigest() throws {
    let pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledOriginalSurveyDirectory)
    #expect(pack.digest == NativeOriginalSurvey.digest)
    #expect(pack.manifest.originalSurvey?.valid == true)
    #expect(pack.manifest.mission.milestones.count == 5)
    #expect(pack.missingCapabilities.isEmpty)
    #expect(ScriptPackLibrary.validSurveyMarkers(pack.manifest))
    #expect(
      ScriptBaseClueCatalog.sources.first {
        $0.sourceID == NativeOriginalSurvey.stateID
      }?.clueID == "consented-survey-family-trace")
  }
}

struct BundledIdentifiedSalvagePackTests {
  @Test func originalDepotPackRetainsExactGeometryAndContentIdentity() throws {
    let pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledIdentifiedSalvageDirectory)
    #expect(pack.digest == NativeIdentifiedSalvage.digest)
    #expect(pack.manifest.identifiedSalvage?.valid == true)
    for (reference, expected) in [
      ("catalogue:SH058", NativeIdentifiedSalvage.packageGeometry),
      ("catalogue:SH141", NativeIdentifiedSalvage.cradleGeometry),
    ] {
      let model = try #require(pack.models[reference])
      let canonical = try ScriptPackLibrary.canonicalGeometry(model)
      #expect(ScriptPackLibrary.hash(canonical) == expected)
    }
    #expect(pack.missingCapabilities.isEmpty)
    #expect(pack.manifest.encounters?.first?.actors.count == 3)
    #expect(
      ScriptBaseClueCatalog.sources.first {
        $0.sourceID == NativeIdentifiedSalvage.stateID
      }?.clueID == "identified-salvage-family-trace")
  }
}
