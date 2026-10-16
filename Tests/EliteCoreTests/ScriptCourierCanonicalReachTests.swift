import Foundation
import Testing

@testable import EliteCore

private func canonicalCourierGame(_ fixture: CourierFixture, axis: SalvageUpgradeAxis) throws
  -> (Game, UUID)
{
  var game = try recoveredEquipmentGame("drive-technology")
  let stock = try #require(game.commander.fittedEquipment(at: .navigation))
  game.commander.credits = 100_000
  game.commander.system = try #require(game.systems.first { $0.technology >= 10 }?.id)
  let navigation = try #require(
    Equipment.all.first { $0.name == NavigationTier.advanced.equipmentName })
  _ = try game.applyEquipmentPurchase(game.quoteEquipmentPurchase(navigation))
  let lot = try #require(game.commander.salvageLedger.inventory.first)
  try game.applyRecoveredUpgrade(
    game.commander.quoteRecoveredUpgrade(lot: lot.identity, axis: axis, slot: .navigation))
  game.scriptPacks = [fixture.pack]
  game.scriptDurabilityAvailable = true
  game.ensureMissionCalendar()
  #expect(game.commander.valid && game.commander.salvageLedger.inventory.isEmpty)
  #expect(game.commander.fittedEquipment(at: .navigation)?.component?.receipts.count == 1)
  return (game, stock.id)
}

/// Selects a real native route, then finds a seed selecting it through the unchanged six draws.
/// No generated proof, destination, cost or draw is rewritten.
private func canonicalCourierTerms(_ game: inout Game, laterLeg: Bool, fuel: Int = 35) throws
  -> ScriptCourierTerms
{
  game.commander.fuel = fuel
  let stockFirst = Double(game.commander.fuel) / 10
  let stockFull = Double(game.commander.fuelCapacity) / 10
  let declaration = try #require(game.scriptPacks.first?.manifest.courier)
  let systems = game.systems
  for origin in 0..<256 {
    game.commander.system = origin
    guard
      let generation = try? ScriptCourierGeneration(
        origin: game.contractStation, commander: game.commander, seed: 1)
    else { continue }
    let witness = generation.paths.firstIndex { path in
      guard generation.calendarCost(path) < 259_200 else { return false }
      let first = systems[path[0]].distance(to: systems[path[1]])
      if !laterLeg { return path.count == 2 && first > stockFirst }
      return path.count == 3 && first <= stockFirst
        && systems[path[1]].distance(to: systems[path[2]]) > stockFull
    }
    guard let witness else { continue }
    for seed in UInt64(0)..<65_536 {
      var state = Game.pledgeProfileSeed(seed)
      for _ in 0..<4 { _ = ScriptCourierGeneration.next(&state) }
      let draw = ScriptCourierGeneration.next(&state)
      let index = Int(floor(Double(draw) / 4294967296.0 * Double(generation.paths.count)))
      guard index == witness else { continue }
      let selected = try ScriptCourierGeneration(
        origin: game.contractStation, commander: game.commander, seed: seed)
      let terms = selected.terms(declaration, row: 4)
      #expect(terms.valid && terms.path == generation.paths[witness])
      return terms
    }
  }
  throw MissionPackError("Actual recovered navigation has no courier regression witness.")
}

struct ScriptCourierCanonicalReachTests {
  @Test func admittedGrandfatheredMilitaryZeroCostUsesNativeCapEvenWithNoFuel() async throws {
    let fixture = try CourierFixture()
    defer { fixture.clean() }
    var game = Game(executive: false)
    game.screen = .inventory
    try game.commander.prepareEquipment(legacy: false)
    game.commander.system = Plugh.systemID
    game.commander.credits = 1_000_000
    for tier in [NavigationTier.advanced, .military] {
      let item = try #require(Equipment.all.first { $0.name == tier.equipmentName })
      _ = try game.applyEquipmentPurchase(game.quoteEquipmentPurchase(item))
    }
    var commander = game.commander
    let inventory = try #require(commander.equipmentInventory)
    let original = try #require(commander.fittedEquipment(at: .navigation))
    let component = try #require(original.component)
    var statistics = component.statistics
    statistics[.jumpFuelCost] = 0
    // This is a supported grandfathered native save, not an earned upgrade or new receipt.
    let changed = ComponentInstance(
      id: component.id, origin: component.origin, statistics: statistics,
      grade: component.grade, features: component.features, receipts: component.receipts)
    let replacement = OwnedEquipmentItem(
      id: original.id, node: original.node, provenance: original.provenance,
      component: changed, location: original.location, boundHull: original.boundHull)
    commander.savedEquipmentInventory = try .init(
      owner: inventory.owner, activeHull: inventory.activeHull, revision: inventory.revision,
      items: inventory.items.map { $0.id == original.id ? replacement : $0 })
    commander.fuel = 0
    let raw = fixture.root.appendingPathComponent("grandfathered-military.json")
    try JSONEncoder().encode(commander).write(to: raw)
    let runtime = GameRuntime(game: game)
    try await runtime.load(from: raw, persistMigrations: false)
    let admitted = await runtime.snapshot()
    let loaded = game.load(admitted.commander)
    try #require(loaded && game.commander.valid)
    #expect(game.commander.navigationTier == .military && game.commander.jumpFuelMultiplier == 0)
    #expect(game.commander.maximumJumpDistance == game.commander.jumpCap)
    #expect(game.commander.fullTankJumpDistance == game.commander.jumpCap)
    #expect(game.commander.fittedEquipment(at: .navigation)?.id == original.id)
    #expect(
      game.commander.fittedEquipment(at: .navigation)?.component?.receipts == component.receipts)
    game.scriptPacks = [fixture.pack]
    game.scriptDurabilityAvailable = true
    game.ensureMissionCalendar()
    let terms = try canonicalCourierTerms(&game, laterLeg: false, fuel: 0)
    #expect(terms.generation.reach.valid && terms.generation.reach.fuel == 0)
    #expect(terms.generation.reach.jumpFuelMultiplier == 0)
    #expect(terms.generation.reach.firstReach == game.commander.jumpCap)
    #expect(terms.generation.reach.fullTankReach == game.commander.jumpCap)
    try game.requireCourierResources(terms)
    #expect(game.commander.fuel == 0)
    let key = try game.ensureContractBoard(fixture.pack)
    let frozen = try #require(game.commander.contracts.boards[key])
    #expect(frozen.courierGeneration?.reach.jumpFuelMultiplier == 0 && frozen.valid)
    try GameRuntime.writeCommander(&game, to: fixture.save)
    let (saved, _) = try ScriptSaveStore.read(Data(contentsOf: fixture.save), from: fixture.save)
    #expect(saved.valid && saved.contracts.boards[key] == frozen)
  }

  @Test(arguments: [SalvageUpgradeAxis.jumpReach, .jumpFuelCost])
  func newProofFreezesActualPaidAndRecoveredNativeFacts(axis: SalvageUpgradeAxis) throws {
    let fixture = try CourierFixture()
    defer { fixture.clean() }
    let (game, _) = try canonicalCourierGame(fixture, axis: axis)
    let reach = ScriptCourierReach(game.commander)
    #expect(reach.revision == "elite-canonical-native-reach-v2" && reach.valid)
    #expect(reach.jumpCap == game.commander.jumpCap)
    #expect(reach.firstReach == game.commander.maximumJumpDistance)
    #expect(reach.fullTankReach == game.commander.fullTankJumpDistance)
    #expect(reach.jumpFuelMultiplier == game.commander.jumpFuelMultiplier)
    #expect(
      try JSONDecoder().decode(ScriptCourierReach.self, from: JSONEncoder().encode(reach)) == reach)
  }

  @Test(arguments: [false, true])
  func efficientFirstAndLaterLegsUseNativeReachAndRefittingRefusesTheFrozenRoute(laterLeg: Bool)
    throws
  {
    let fixture = try CourierFixture()
    defer { fixture.clean() }
    let prepared = try canonicalCourierGame(fixture, axis: .jumpFuelCost)
    var game = prepared.0
    let stockID = prepared.1
    #expect(game.commander.jumpFuelMultiplier < 1)
    let terms = try canonicalCourierTerms(&game, laterLeg: laterLeg)
    let frozen = try JSONEncoder().encode(terms)
    try game.requireCourierResources(terms)
    let stock = try #require(game.commander.equipmentInventory?.items.first { $0.id == stockID })
    try game.fitEquipment(
      stock, at: .navigation, expectedRevision: game.commander.equipmentInventory!.revision)
    #expect(game.commander.valid && game.commander.jumpFuelMultiplier == 1)
    #expect(game.commander.fittedEquipment(at: .navigation)?.id == stockID)
    let restored = try JSONDecoder().decode(ScriptCourierTerms.self, from: frozen)
    #expect(restored == terms && restored.valid)
    let before = game.commander
    #expect(throws: MissionPackError.self) { try game.requireCourierResources(restored) }
    #expect(game.commander == before)
  }

  @Test func v1GoldenBoardAndAcceptedPackageSurviveCanonicalLoadRefitAndReload() async throws {
    let fixture = try CourierFixture()
    defer { fixture.clean() }
    struct Golden: Decodable {
      let board: ScriptContractBoard
      let instance: ScriptInstance
      let calendarSeconds: Double
      let nextEvent: UInt64
    }
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().appendingPathComponent("Fixtures/courier-native-reach-v1.json")
    let bytes = try Data(contentsOf: url)
    try #require(
      ScriptPackLibrary.hash(bytes)
        == "c43c49e178ee1c58493f36ceb66a839ae6f222ddb04bb397b03895ca9c12c88e")
    let golden = try JSONDecoder().decode(Golden.self, from: bytes)
    let key = golden.board.cacheKey
    let id = golden.instance.id
    let job = try #require(golden.instance.contract)
    try #require(golden.board.valid && job.valid)
    #expect(golden.board.seed == 5_318_087_094_851_105_804)
    #expect(
      golden.board.courierGeneration?.draws
        == [898_330_452, 1_415_163_876, 1_426_520_566, 3_442_991_530, 290_823_243, 4_182_313_349])
    #expect(job.offer.courier?.path == [0, 71] && job.offer.reward == 8000)
    #expect(job.acceptedAt == 12.5 && job.deadline == 172_812.5 && !job.settled)
    #expect(id.uuidString == "47D441D2-0FFB-00E1-0258-A8662DEBA84B")
    #expect(golden.instance.courier?.item.uuidString == "193D7594-A8EB-3159-3400-BB449B2714A0")
    #expect(golden.instance.receipts == ["issue-consignment"])
    #expect(golden.instance.payloads == ["courier-consignment": 1])
    #expect(golden.instance.courier?.terminal == nil && golden.instance.completionReceipt == nil)
    let prepared = try canonicalCourierGame(fixture, axis: .jumpReach)
    var game = prepared.0
    game.commander.system = golden.board.station.system
    game.commander.contracts.boards[key] = golden.board
    game.commander.scriptState.instances[id] = golden.instance
    game.commander.scriptState.calendarSeconds = golden.calendarSeconds
    game.commander.scriptState.missionCalendar?.seconds = golden.calendarSeconds
    game.commander.scriptState.nextEvent = golden.nextEvent
    try #require(game.commander.valid)
    #expect(game.commander.jumpCap > golden.board.courierGeneration!.reach.jumpCap)
    try GameRuntime.writeCommander(&game, to: fixture.save)
    let runtime = GameRuntime(game: game, saveURL: fixture.save)
    try await runtime.load(from: fixture.save)
    let admitted = await runtime.snapshot()
    #expect(admitted.commander.valid && admitted.commander.contracts.boards[key] == golden.board)
    #expect(admitted.commander.scriptState.instances[id] == golden.instance)
    let loaded = game.load(admitted.commander)
    try #require(loaded)
    let stock = try #require(game.commander.equipmentInventory?.items.first { $0.id == prepared.1 })
    try game.fitEquipment(
      stock, at: .navigation, expectedRevision: game.commander.equipmentInventory!.revision)
    #expect(game.commander.fittedEquipment(at: .navigation)?.id == stock.id)
    #expect(game.commander.contracts.boards[key] == golden.board)
    #expect(game.commander.scriptState.instances[id] == golden.instance)
    try GameRuntime.writeCommander(&game, to: fixture.save)
    let (saved, _) = try ScriptSaveStore.read(Data(contentsOf: fixture.save), from: fixture.save)
    #expect(saved.valid && saved.contracts.boards[key] == golden.board)
    #expect(saved.scriptState.instances[id] == golden.instance)
    #expect(saved.scriptState.instances[id]?.courier?.issue == golden.instance.courier?.issue)
    #expect(saved.scriptState.instances[id]?.contract?.deadline == 172_812.5)
    #expect(try game.ensureContractBoard(fixture.pack) == key)
    #expect(game.commander.contracts.boards[key] == golden.board)
    #expect(game.commander.scriptState.instances.count == 1)
  }

  @Test func reachVersionsRefuseMissingMixedUnknownAndIncoherentFacts() throws {
    let fixture = try CourierFixture()
    defer { fixture.clean() }
    let reach = ScriptCourierReach(fixture.game().commander)
    let object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(reach)) as? [String: Any])
    func decode(_ changed: [String: Any]) throws -> ScriptCourierReach {
      try JSONDecoder().decode(
        ScriptCourierReach.self, from: JSONSerialization.data(withJSONObject: changed))
    }
    for key in ["jumpFuelMultiplier", "fullTankReach"] {
      var missing = object
      missing.removeValue(forKey: key)
      #expect(try !decode(missing).valid)
    }
    for (key, value) in [
      ("jumpFuelMultiplier", -1.0),
      ("jumpFuelMultiplier", 2.0), ("fullTankReach", 0.0), ("firstReach", -1.0),
    ] {
      var changed = object
      changed[key] = value
      #expect(try !decode(changed).valid)
    }
    var mixed = object
    mixed["revision"] = "elite-880d3a-native-reach-v1"
    #expect(try !decode(mixed).valid)
    mixed.removeValue(forKey: "jumpFuelMultiplier")
    mixed.removeValue(forKey: "fullTankReach")
    #expect(try decode(mixed).valid)
    mixed["firstReach"] = 0.0
    #expect(try !decode(mixed).valid)
    mixed["revision"] = "unknown-reach"
    #expect(try !decode(mixed).valid)
  }
}
