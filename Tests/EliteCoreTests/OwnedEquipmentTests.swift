import Foundation
import Testing

@testable import EliteCore

@Test func replacingOwnedWeaponsAndComputersStoresTheOriginalIdentities() throws {
  var game = try missionGearGame()
  for (name, slot) in [
    (TargetingTier.basic.equipmentName, ComponentFittingSlot.targetingCore),
    (ShieldBooster.pulse.equipmentName, .shield),
  ] {
    try game.commander.grantEquipment(name, at: slot, provenance: .grant("replacement-fixture"))
  }
  let old = try #require(game.commander.equipmentInventory)
  let slots: Set<ComponentFittingSlot> = [.laser(.front), .targetingCore, .navigation, .shield]
  let replaced = old.items.filter { $0.location.map { slots.contains($0.slot) } == true }
  for (name, slot) in [
    (LaserKind.beam.equipmentName, ComponentFittingSlot.laser(.front)),
    (TargetingTier.military.equipmentName, .targetingCore),
    (NavigationTier.military.equipmentName, .navigation),
    (ShieldBooster.military.equipmentName, .shield),
  ] {
    try game.commander.grantEquipment(name, at: slot, provenance: .grant("replacement-fixture"))
  }
  let upgraded = try #require(game.commander.equipmentInventory)
  #expect(Set(old.items.map(\.id)).isSubset(of: Set(upgraded.items.map(\.id))))
  for original in replaced {
    #expect(upgraded.items.first { $0.id == original.id } == original.moved(to: nil))
  }
  try game.commander.grantEquipment(
    LaserKind.beam.equipmentName, at: .laser(.front), provenance: .grant("replacement-fixture"))
  try game.commander.grantEquipment(
    TargetingTier.basic.equipmentName, at: .targetingCore, provenance: .grant("replacement-fixture")
  )
  #expect(game.commander.equipmentInventory == upgraded && game.commander.valid)
}

@Test func anOccupiedCabinBlocksAZeroHoldHullWhileItsPersonAndEquipmentRemainOwned() throws {
  let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/mission-packs/scripted-passengers")
  let pack = try ScriptPackLibrary.read(source)
  var library = Game(executive: false)
  library.scriptPacks = [pack]
  let trial = try library.makeScriptTrial(packDigest: pack.digest, seed: 9)
  let before = trial.commander
  var portable = before
  for item in try #require(before.equipmentInventory).items {
    if case .laser = item.location?.slot {
      try portable.storeEquipment(item, expectedRevision: portable.equipmentInventory!.revision)
    } else if case .missilePylon = item.location?.slot {
      try portable.storeEquipment(item, expectedRevision: portable.equipmentInventory!.revision)
    }
  }
  let retained = portable
  try #require(ShipCatalogue.ship("SH033")?.game?.cargo == 0)
  #expect(throws: EquipmentRuntimeError.incompatibleFit) {
    try portable.projectedEquipmentTransfer(to: "SH033")
  }
  #expect(portable == retained)
  #expect(portable.accommodation == before.accommodation && trial.commander == before)
}

@Test func consumptionRetainsStoredBombsHyperdrivesAndEscapePods() throws {
  for (name, slot) in [
    ("Energy Bomb", ComponentFittingSlot.utility(.energyBomb)),
    ("Galactic Hyperdrive", .utility(.galacticHyperdrive)), ("Escape Pod", .utility(.escapePod)),
  ] {
    let fixture = try GearScriptFixture(
      name: name, quantity: 2, loan: false, requiredReturn: false,
      accepted:
        "{op='gear.issue',id='issue',gear='kit',fit=false},{op='gear.refit',id='fit',gear='kit',index=0}"
    )
    defer { fixture.clean() }
    var game = try fixture.game()
    let record = try #require(game.commander.scriptState.instances.values.first?.gearIssues["kit"])
    let spare = try #require(
      game.commander.equipmentInventory?.items.first { $0.id == record.items[1] })
    let fitted = try #require(game.commander.fittedEquipment(at: slot))
    #expect(fitted.id == record.items[0] && fitted.id != spare.id && spare.location == nil)
    game.launch()
    switch name {
    case "Energy Bomb": game.energyBomb()
    case "Galactic Hyperdrive": game.galacticJump()
    default: game.escapePod()
    }
    #expect(game.commander.equipmentInventory?.items.contains { $0.id == fitted.id } == false)
    #expect(
      game.commander.equipmentInventory?.items.first { $0.id == spare.id } == spare)
    #expect(game.commander.valid)
  }
}

private struct OwnedEquipmentObserverFixture {
  let folder: URL
  let manifest: URL
  let original: String
  let pack: ScriptPack
  init() throws {
    folder = try missionGearFolder()
    let example = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/scripted-courier")
    let directory = folder.appendingPathComponent("pack")
    try FileManager.default.copyItem(at: example, to: directory)
    manifest = directory.appendingPathComponent("manifest.toml")
    original = try String(contentsOf: manifest, encoding: .utf8)
    let text =
      original.replacingOccurrences(
        of: "\"cargo-v2\"]", with: "\"cargo-v2\", \"owned-equipment-v2\"]")
      + "\n[[handlers]]\nevent=\"ship.changed\"\nfunction=\"changed\"\n[[handlers]]\nevent=\"equipment.changed\"\nfunction=\"refitted\"\n[[handlers]]\nevent=\"gear.consumed\"\nfunction=\"spent\"\n"
    try text.write(to: manifest, atomically: true, encoding: .utf8)
    let source = """
      local function no(e,w,d) return {data=d,commands={}} end
      return {
        accepted=function(e,w,d) return {data={changes=0,fits=0,shots=0},commands={}} end,
        contact=no, confirm=no,
        changed=function(e,w,d)
          d.changes=d.changes+1; d.previous=e.previous; d.ship=e.ship
          d.loaded=w.fitted_equipment.Missile; d.stored=w.stored_equipment.Missile
          return {data=d,commands={}}
        end,
        refitted=function(e,w,d) d.fits=d.fits+1; d.fit_item=e.item; d.fitted=e.fitted; return {data=d,commands={}} end,
        spent=function(e,w,d) d.shots=d.shots+1; d.spent=e.item; return {data=d,commands={}} end
      }
      """
    try source.write(
      to: directory.appendingPathComponent("scripts/main.lua"), atomically: true, encoding: .utf8)
    pack = try ScriptPackLibrary.read(directory)
  }
  func clean() { try? FileManager.default.removeItem(at: folder) }
}

/// These event fixtures intentionally observe a stock Cobra exchange, independent of fresh defaults.
private func ownedObserverStockCobraGame() throws -> Game {
  var commander = Commander()
  commander.shipID = "SH023"
  commander.fuel = commander.fuelCapacity
  commander.missiles = 4
  try commander.prepareEquipment(legacy: false)
  var game = Game(executive: false)
  game.commander = commander
  game.commander.mirrorFittedEquipment()
  try game.migrateMiningPresence(legacyMissing: false, persistCurrentPolicy: true)
  game.energy = game.commander.performance.energy
  game.frontShield = game.commander.shieldCapacity
  game.rearShield = game.commander.rearShieldCapacity
  try #require(game.commander.valid && game.commander.shipID == "SH023")
  try #require(game.commander.fuel == 70 && game.commander.missiles == 4)
  game.screen = .inventory
  return game
}

@Test func scriptsObserveOnlyCommittedHullRefitAndActualAmmunitionEvents() throws {
  let fixture = try OwnedEquipmentObserverFixture()
  defer { fixture.clean() }
  let pack = fixture.pack
  var game = try ownedObserverStockCobraGame()
  game.scriptPacks = [pack]
  game.commander.credits = 10_000_000
  let id = try game.acceptScriptMission(pack)
  game.screen = .showroom
  game.showroom.selection = "SH013"
  game.key("showroom-trade")
  game.key("return")
  #expect(game.commander.scriptState.instances[id]?.data["changes"] == .integer(0))
  game.key("showroom-trade")
  game.key("right")
  game.key("return")
  let state = try #require(game.commander.scriptState.instances[id])
  #expect(state.suspension == nil && state.data["changes"] == .integer(1))
  #expect(state.data["previous"] == .string("SH023") && state.data["ship"] == .string("SH013"))
  #expect(state.data["loaded"] == .integer(4))
  let round = try #require(missionHighestRound(game.commander))
  try missionStorePhysical(round, in: &game)
  #expect(game.commander.scriptState.instances[id]?.data["fits"] == .integer(1))
  #expect(
    game.commander.scriptState.instances[id]?.data["fit_item"] == .string(round.id.uuidString))
  #expect(game.commander.scriptState.instances[id]?.data["fitted"] == .bool(false))
  let held = try #require(game.commander.equipmentInventory?.items.first { $0.id == round.id })
  let fit = try #require(game.inventoryActionPreview(for: .equipment(held)).command)
  let applied = game.performInventoryCommand(fit)
  try #require(applied)
  game.drainScriptEvents()
  #expect(game.commander.scriptState.instances[id]?.data["fits"] == .integer(2))
  #expect(game.commander.scriptState.instances[id]?.data["fit_item"] == .string(held.id.uuidString))
  #expect(game.commander.scriptState.instances[id]?.data["fitted"] == .bool(true))
  let spent = try #require(missionHighestRound(game.commander))
  game.launch()
  game.bodies = [SpaceBody(id: 1, hull: .sidewinder, position: .init(0, 0, 800))]
  game.missileArmed = true
  let fired = game.fireMissile()
  #expect(fired)
  game.drainScriptEvents()
  #expect(game.commander.scriptState.instances[id]?.data["shots"] == .integer(1))
  #expect(game.commander.scriptState.instances[id]?.data["spent"] == .string(spent.id.uuidString))
  try (fixture.original + "\n[[handlers]]\nevent=\"ship.changed\"\nfunction=\"changed\"\n").write(
    to: fixture.manifest, atomically: true, encoding: .utf8)
  #expect(throws: MissionPackError.self) {
    try ScriptPackLibrary.read(fixture.manifest.deletingLastPathComponent())
  }
}

@Test func actualInventoryCommandsStoreAndReuseLasersAndMissilesWithoutCharging() throws {
  var game = try missionGearGame()
  let cash = game.commander.credits
  let laser = try #require(game.commander.fittedEquipment(at: .laser(.front)))
  try missionStorePhysical(laser, in: &game)
  game.equipmentMount = .rear
  let held = try #require(game.commander.equipmentInventory?.items.first { $0.id == laser.id })
  let refit = try #require(game.inventoryActionPreview(for: .equipment(held)).command)
  let refitApplied = game.performInventoryCommand(refit)
  #expect(refitApplied)
  #expect(game.commander.fittedEquipment(at: .laser(.rear))?.id == laser.id)
  let round = try #require(missionHighestRound(game.commander))
  let before = try #require(game.commander.equipmentInventory)
  try missionStorePhysical(round, in: &game)
  let stored = try #require(game.commander.equipmentInventory?.items.first { $0.id == round.id })
  let reload = try #require(game.inventoryActionPreview(for: .equipment(stored)).command)
  let reloadApplied = game.performInventoryCommand(reload)
  #expect(reloadApplied)
  #expect(Set(game.commander.equipmentInventory!.items.map(\.id)) == Set(before.items.map(\.id)))
  #expect(game.commander.missiles == 3 && game.commander.valid && game.commander.credits == cash)
}

@Test func stowingAnExpansionOrTankNeverDiscardsCargoOrFuel() throws {
  var game = try missionGearGame()
  try game.commander.grantEquipment(
    "Large Cargo Bay", at: .utility(.cargoExpansion), provenance: .grant("stowage-fixture"))
  try game.commander.grantEquipment(
    FuelStorage.equipmentName, at: .fuelStorage(0), provenance: .grant("stowage-fixture"))
  // The retained SH023 catalogue has a 30t native hold plus a 15t expansion.
  // Put one actual tonne beyond the unexpanded hold before testing refusal.
  #expect(game.commander.nativePerformance.cargo == 30)
  game.commander.cargo[0] = game.commander.nativePerformance.cargo + 1
  #expect(game.commander.cargoTonnes > game.commander.nativePerformance.cargo)
  #expect(game.commander.cargoTonnes <= game.commander.standardCargoCapacity)
  game.commander.fuel = 140
  let before = game.commander
  for slot in [ComponentFittingSlot.utility(.cargoExpansion), .fuelStorage(0)] {
    let item = try #require(game.commander.fittedEquipment(at: slot))
    #expect(game.inventoryActionPreview(for: .equipment(item)).command == nil)
    #expect(game.commander == before)
  }
  game.commander.cargo[0] = game.commander.nativePerformance.cargo
  let bay = try #require(game.commander.fittedEquipment(at: .utility(.cargoExpansion)))
  let boundary = game.commander
  try missionStorePhysical(bay, in: &game)
  #expect(game.commander.cargo == boundary.cargo && game.commander.fuel == boundary.fuel)
  #expect(game.commander.credits == boundary.credits)
  let heldBay = try #require(game.commander.equipmentInventory?.items.first { $0.id == bay.id })
  let refitBay = try #require(game.inventoryActionPreview(for: .equipment(heldBay)).command)
  let bayRefitted = game.performInventoryCommand(refitBay)
  #expect(
    bayRefitted && game.commander.fittedEquipment(at: .utility(.cargoExpansion))?.id == bay.id)
  #expect(game.commander.cargo == boundary.cargo && game.commander.fuel == boundary.fuel)
  #expect(game.commander.credits == boundary.credits)
  game.commander.cargo[0] = 0
  game.commander.fuel = 70
  let tank = try #require(game.commander.fittedEquipment(at: .fuelStorage(0)))
  try missionStorePhysical(tank, in: &game)
  let stored = try #require(game.commander.equipmentInventory?.items.first { $0.id == tank.id })
  let refit = try #require(game.inventoryActionPreview(for: .equipment(stored)).command)
  let refitApplied = game.performInventoryCommand(refit)
  #expect(refitApplied)
  #expect(game.commander.fuelStorageUnits == 1 && game.commander.fuel == 70 && game.commander.valid)
}

@Test func actorInventoryCommandsAreStaleAfterRefitAndCannotChangeFlightOrPausedState() async throws
{
  let game = try missionGearGame()
  let runtime = GameRuntime(game: game)
  let shown = await runtime.snapshot()
  let laser = try #require(shown.commander.fittedEquipment(at: .laser(.front)))
  let command = try #require(shown.inventoryActionPreview(for: .equipment(laser)).command)
  let first = await runtime.equipmentTransaction(.inventory(command))
  #expect(first.applied)
  let before = await runtime.snapshot().commander
  let stale = await runtime.equipmentTransaction(.inventory(command))
  let afterStale = await runtime.snapshot()
  #expect(!stale.applied && afterStale.commander == before)
  // Ordinary native inventory actions require docking, including at a secondary station.
  var outside = game
  outside.dockedAtMainStation = false
  let original = try #require(outside.commander.equipmentInventory)
  let outsideLaser = try #require(outside.commander.fittedEquipment(at: .laser(.front)))
  let outsideCommand = try #require(
    outside.inventoryActionPreview(for: .equipment(outsideLaser)).command)
  let stored = outside.performEquipmentMutation(.inventory(outsideCommand))
  #expect(stored.applied && outside.commander.valid)
  #expect(
    outside.commander.equipmentInventory?.items.first { $0.id == outsideLaser.id }?.location == nil)
  #expect(outside.commander.equipmentInventory?.revision == original.revision + 1)
  #expect(outside.commander.credits == game.commander.credits)
  #expect(
    Set(outside.commander.equipmentInventory?.items.map(\.id) ?? [])
      == Set(original.items.map(\.id)))
  let held = try #require(
    outside.commander.equipmentInventory?.items.first { $0.id == outsideLaser.id })
  let refitCommand = try #require(
    outside.inventoryActionPreview(for: .equipment(held)).command)
  let refitted = outside.performEquipmentMutation(.inventory(refitCommand))
  #expect(refitted.applied && outside.commander.valid)
  #expect(outside.commander.fittedEquipment(at: .laser(.front))?.id == outsideLaser.id)
  #expect(
    outside.commander.fittedEquipment(at: .laser(.front))?.component == outsideLaser.component)
  #expect(
    outside.commander.fittedEquipment(at: .laser(.front))?.provenance == outsideLaser.provenance)
  #expect(outside.commander.equipmentInventory?.revision == original.revision + 2)
  #expect(outside.commander.credits == game.commander.credits)
  #expect(
    Set(outside.commander.equipmentInventory?.items.map(\.id) ?? [])
      == Set(original.items.map(\.id)))
  for paused in [false, true] {
    var blocked = game
    let freshLaser = try #require(blocked.commander.fittedEquipment(at: .laser(.front)))
    let fresh = try #require(blocked.inventoryActionPreview(for: .equipment(freshLaser)).command)
    blocked.paused = paused
    blocked.docked = paused
    let refusal = blocked.performEquipmentMutation(.inventory(fresh))
    #expect(!refusal.applied && blocked.commander == game.commander)
  }
}

@Test func repeatedExchangePreviewsHaveStableProvisionalIdentitiesAndLeaveTheCommanderAlone() throws
{
  var game = try missionGearGame(missiles: 4)
  game.screen = .showroom
  game.showroom.selection = "SH013"
  game.commander.credits = 10_000_000
  let before = game.commander
  let first = try #require(game.shipTradeQuote)
  let second = try #require(game.shipTradeQuote)
  let firstProjection = try game.commander.projectedEquipmentTransfer(to: first.selected.id)
  let secondProjection = try game.commander.projectedEquipmentTransfer(to: second.selected.id)
  #expect(firstProjection == secondProjection && game.commander == before)
  #expect(first.selected.id == second.selected.id && first.balance == second.balance)
  #expect(first.issues == second.issues && first.allowed == second.allowed)
  #expect(game.selectedGameProfile?.fields.first { $0.key == "fitted_missiles" }?.number == 4)
  #expect(game.selectedGameProfile?.fields.first { $0.key == "fitted_lasers" }?.number == 1)
}

@Test func nativeProfilesCountLoadedWeaponsWithoutIncludingStoredCustodyOrCreatingEquipment() throws
{
  var game = try missionGearGame(missiles: 4)
  try game.commander.grantEquipment(
    LaserKind.beam.equipmentName, at: .laser(.rear), provenance: .grant("profile count fixture"))
  let full = game.commander.gameShipProfile
  #expect(full.fields.first { $0.key == "fitted_missiles" }?.number == 4)
  #expect(full.fields.first { $0.key == "fitted_lasers" }?.number == 2)
  #expect(full.fields.first { $0.key == "missile_capacity" }?.number == 4)
  #expect(full.fields.first { $0.key == "laser_facings" }?.number == 4)
  let round = try #require(missionHighestRound(game.commander))
  let front = try #require(game.commander.fittedEquipment(at: .laser(.front)))
  try missionStorePhysical(round, in: &game)
  try missionStorePhysical(front, in: &game)
  let before = game.commander
  let stored = game.commander.gameShipProfile
  #expect(stored.fields.first { $0.key == "fitted_missiles" }?.number == 3)
  #expect(stored.fields.first { $0.key == "fitted_lasers" }?.number == 1)
  #expect(game.commander == before)
  #expect(game.commander.equipmentInventory?.items.first { $0.id == round.id }?.location == nil)
  #expect(game.commander.equipmentInventory?.items.first { $0.id == front.id }?.location == nil)
  let legacy = Commander()
  #expect(legacy.gameShipProfile.fields.first { $0.key == "fitted_missiles" }?.number == 3)
  #expect(legacy.gameShipProfile.fields.first { $0.key == "fitted_lasers" }?.number == 1)
  #expect(legacy.equipmentInventory == nil)
}

@Test(arguments: 0..<6)
func hullExchangeRefusalsAndCancellationPublishNeitherPhysicalChangesNorScriptEvents(reason: Int)
  throws
{
  let fixture = try OwnedEquipmentObserverFixture()
  defer { fixture.clean() }
  var game = try missionGearGame(missiles: 4)
  game.scriptPacks = [fixture.pack]
  game.commander.credits = 10_000_000
  let id = try game.acceptScriptMission(fixture.pack)
  game.screen = .showroom
  game.showroom.selection = "SH013"
  game.key("showroom-trade")
  try #require(game.showroom.trading)
  switch reason {
  case 1: game.paused = true
  case 2: game.commander.credits = 0
  case 3: game.docked = false
  case 4:
    let first = game.commander.scriptState.nextEvent + 1
    game.commander.scriptState.pendingEvents = (0..<4096).map {
      ScriptEvent(
        sequence: first + UInt64($0), kind: "contact.requested", instance: id, values: [:])
    }
    game.commander.scriptState.nextEvent = first + 4095
  case 5: game.commander.scriptState.nextEvent = UInt64(Int64.max) - 1
  default: break
  }
  try #require(game.commander.valid)
  let before = game.commander
  let bodies = game.bodies
  if reason == 0 { game.shipTradeKey("return") } else { game.confirmShipTrade() }
  #expect(game.commander == before && game.bodies == bodies)
  #expect(game.commander.scriptState.instances[id]?.data["changes"] == .integer(0))
  #expect(game.commander.scriptState.instances[id]?.suspension == nil)
  if reason == 0 { #expect(!game.showroom.trading) }
  if reason == 4 || reason == 5 {
    game.screen = .inventory
    let round = try #require(missionHighestRound(game.commander))
    #expect(throws: EquipmentRuntimeError.unavailable) {
      try game.storeEquipment(round, expectedRevision: game.commander.equipmentInventory!.revision)
    }
    #expect(game.commander == before && game.bodies == bodies)
  }
}

private func ownedObserverSavedFiles(_ root: URL) throws -> [String: Data] {
  var result: [String: Data] = [:]
  for name in try FileManager.default.subpathsOfDirectory(atPath: root.path) {
    let file = root.appendingPathComponent(name)
    if try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
      result[name] = try Data(contentsOf: file)
    }
  }
  return result
}

@Test(arguments: [false, true])
func hullChangeEventAndOwnedFitShareTheirActualActorWriterCommitOrRollback(failing: Bool)
  async throws
{
  let fixture = try OwnedEquipmentObserverFixture()
  defer { fixture.clean() }
  var game = try ownedObserverStockCobraGame()
  game.scriptPacks = [fixture.pack]
  game.commander.credits = 10_000_000
  let id = try game.acceptScriptMission(fixture.pack)
  game.screen = .showroom
  game.showroom.selection = "SH013"
  game.key("showroom-trade")
  game.key("right")
  try #require(
    game.showroom.trading && game.showroom.confirmTrade && game.shipTradeQuote?.allowed == true)
  let parent = fixture.folder.appendingPathComponent("save")
  let save = parent.appendingPathComponent("commander.json")
  if failing { try Data("blocked save parent".utf8).write(to: parent) }
  let runtime = GameRuntime(game: game, saveURL: save)
  if !failing { try await runtime.save(to: save) }
  let before = await runtime.snapshot()
  let files = try ownedObserverSavedFiles(fixture.folder)
  await runtime.key("return")
  let after = await runtime.snapshot()
  if failing {
    #expect(after.commander == before.commander && after.bodies == before.bodies)
    #expect(after.showroom.trading == before.showroom.trading && after.screen == before.screen)
    #expect(try ownedObserverSavedFiles(fixture.folder) == files)
    #expect(after.message == "MISSION SAVE FAILED - ACTION NOT COMMITTED")
  } else {
    #expect(after.commander.shipID == "SH013" && !after.showroom.trading)
    #expect(after.commander.scriptState.instances[id]?.data["changes"] == .integer(1))
    #expect(after.commander.scriptState.instances[id]?.data["previous"] == .string("SH023"))
    #expect(after.commander.scriptState.instances[id]?.data["ship"] == .string("SH013"))
    #expect(after.commander.scriptState.instances[id]?.data["loaded"] == .integer(4))
    #expect(after.commander.scriptState.instances[id]?.data["fits"] == .integer(0))
    let nextEvent = after.commander.scriptState.nextEvent
    await runtime.key("return")
    #expect(await runtime.snapshot().commander.scriptState.nextEvent == nextEvent)
    let restored = GameRuntime(game: game)
    try await restored.load(from: save)
    let reloaded = await restored.snapshot()
    #expect(reloaded.commander.shipID == "SH013")
    #expect(reloaded.commander.scriptState.instances[id]?.data["changes"] == .integer(1))
    #expect(reloaded.commander.scriptState.pendingEvents.allSatisfy { $0.kind != "ship.changed" })
    #expect(reloaded.commander.valid)
  }
}

@Test(arguments: [false, true])
func nativeFittingEventsCommitWithTheirActualActorWriterAndRollbackOnFailure(failing: Bool)
  async throws
{
  let fixture = try OwnedEquipmentObserverFixture()
  defer { fixture.clean() }
  var game = try missionGearGame(missiles: 4)
  game.scriptPacks = [fixture.pack]
  let id = try game.acceptScriptMission(fixture.pack)
  let parent = fixture.folder.appendingPathComponent("save")
  let save = parent.appendingPathComponent("commander.json")
  if failing { try Data("blocked save parent".utf8).write(to: parent) }
  let runtime = GameRuntime(game: game, saveURL: save)
  if !failing { try await runtime.save(to: save) }
  let before = await runtime.snapshot()
  let round = try #require(missionHighestRound(before.commander))
  let store = try #require(before.inventoryActionPreview(for: .equipment(round)).command)
  let files = try ownedObserverSavedFiles(fixture.folder)
  let stored = await runtime.inventoryCommand(store)
  let after = await runtime.snapshot()
  if failing {
    #expect(!stored && after.commander == before.commander && after.bodies == before.bodies)
    #expect(try ownedObserverSavedFiles(fixture.folder) == files)
  } else {
    try #require(stored)
    #expect(after.commander.scriptState.instances[id]?.data["fits"] == .integer(1))
    #expect(
      after.commander.scriptState.instances[id]?.data["fit_item"] == .string(round.id.uuidString))
    #expect(after.commander.scriptState.instances[id]?.data["fitted"] == .bool(false))
    #expect(after.commander.missiles == 3)
    let held = try #require(after.commander.equipmentInventory?.items.first { $0.id == round.id })
    let fit = try #require(after.inventoryActionPreview(for: .equipment(held)).command)
    let refitted = await runtime.inventoryCommand(fit)
    try #require(refitted)
    let final = await runtime.snapshot()
    #expect(final.commander.missiles == 4)
    #expect(final.commander.scriptState.instances[id]?.data["fits"] == .integer(2))
    #expect(final.commander.scriptState.instances[id]?.data["fitted"] == .bool(true))
    #expect(final.commander.scriptState.instances[id]?.data["changes"] == .integer(0))
    let restored = GameRuntime(game: game)
    try await restored.load(from: save)
    #expect(await restored.snapshot().commander == final.commander)
  }
}
