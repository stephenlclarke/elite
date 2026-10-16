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
  try #require(ShipCatalogue.ship("SH128")?.game?.cargo == 0)
  #expect(throws: EquipmentRuntimeError.incompatibleFit) {
    try portable.projectedEquipmentTransfer(to: "SH128")
  }
  #expect(portable.accommodation == before.accommodation && trial.commander == before)
}

@Test func consumptionRetainsStoredBombsHyperdrivesAndEscapePods() throws {
  for (name, slot) in [
    ("Energy Bomb", ComponentFittingSlot.utility(.energyBomb)),
    ("Galactic Hyperdrive", .utility(.galacticHyperdrive)), ("Escape Pod", .utility(.escapePod)),
  ] {
    var game = try missionGearGame()
    try game.commander.grantEquipment(name, at: slot, provenance: .grant("consumption-fixture"))
    let spare = try #require(game.commander.fittedEquipment(at: slot))
    try missionStorePhysical(spare, in: &game)
    let purchase = try #require(Equipment.all.first { $0.name == name })
    game.commander.system = Plugh.systemID
    game.commander.credits = 1_000_000
    _ = try game.applyEquipmentPurchase(game.quoteEquipmentPurchase(purchase))
    let fitted = try #require(game.commander.fittedEquipment(at: slot))
    #expect(fitted.id != spare.id)
    game.launch()
    switch name {
    case "Energy Bomb": game.energyBomb()
    case "Galactic Hyperdrive": game.galacticJump()
    default: game.escapePod()
    }
    #expect(game.commander.equipmentInventory?.items.contains { $0.id == fitted.id } == false)
    #expect(
      game.commander.equipmentInventory?.items.first { $0.id == spare.id } == spare.moved(to: nil))
    #expect(game.commander.valid)
  }
}

@Test func scriptsObserveOnlyCommittedHullRefitAndActualAmmunitionEvents() throws {
  let folder = try missionGearFolder()
  defer { try? FileManager.default.removeItem(at: folder) }
  let example = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/mission-packs/scripted-courier")
  let directory = folder.appendingPathComponent("pack")
  try FileManager.default.copyItem(at: example, to: directory)
  let manifest = directory.appendingPathComponent("manifest.toml")
  let original = try String(contentsOf: manifest, encoding: .utf8)
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
      refitted=function(e,w,d) d.fits=d.fits+1; return {data=d,commands={}} end,
      spent=function(e,w,d) d.shots=d.shots+1; d.spent=e.item; return {data=d,commands={}} end
    }
    """
  try source.write(
    to: directory.appendingPathComponent("scripts/main.lua"), atomically: true, encoding: .utf8)
  let pack = try ScriptPackLibrary.read(directory)
  var game = try missionGearGame(missiles: 4)
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
  let held = try #require(game.commander.equipmentInventory?.items.first { $0.id == round.id })
  let fit = try #require(game.inventoryActionPreview(for: .equipment(held)).command)
  let applied = game.performInventoryCommand(fit)
  try #require(applied)
  game.drainScriptEvents()
  #expect(game.commander.scriptState.instances[id]?.data["fits"] == .integer(2))
  let spent = try #require(missionHighestRound(game.commander))
  game.launch()
  game.bodies = [SpaceBody(id: 1, hull: .sidewinder, position: .init(0, 0, 800))]
  game.missileArmed = true
  let fired = game.fireMissile()
  #expect(fired)
  game.drainScriptEvents()
  #expect(game.commander.scriptState.instances[id]?.data["shots"] == .integer(1))
  #expect(game.commander.scriptState.instances[id]?.data["spent"] == .string(spent.id.uuidString))
  try (original + "\n[[handlers]]\nevent=\"ship.changed\"\nfunction=\"changed\"\n").write(
    to: manifest, atomically: true, encoding: .utf8)
  #expect(throws: MissionPackError.self) { try ScriptPackLibrary.read(directory) }
}

@Test func actualInventoryCommandsStoreAndReuseLasersAndMissilesWithoutCharging() throws {
  var game = try missionGearGame()
  let cash = game.commander.credits
  let laser = try #require(game.commander.fittedEquipment(at: .laser(.front)))
  try missionStorePhysical(laser, in: &game)
  game.equipmentMount = .rear
  let held = try #require(game.commander.equipmentInventory?.items.first { $0.id == laser.id })
  let refit = try #require(game.inventoryActionPreview(for: .equipment(held)).command)
  #expect(game.performInventoryCommand(refit))
  #expect(game.commander.fittedEquipment(at: .laser(.rear))?.id == laser.id)
  let round = try #require(missionHighestRound(game.commander))
  let before = try #require(game.commander.equipmentInventory)
  try missionStorePhysical(round, in: &game)
  let stored = try #require(game.commander.equipmentInventory?.items.first { $0.id == round.id })
  let reload = try #require(game.inventoryActionPreview(for: .equipment(stored)).command)
  #expect(game.performInventoryCommand(reload))
  #expect(Set(game.commander.equipmentInventory!.items.map(\.id)) == Set(before.items.map(\.id)))
  #expect(game.commander.missiles == 3 && game.commander.valid && game.commander.credits == cash)
}

@Test func stowingAnExpansionOrTankNeverDiscardsCargoOrFuel() throws {
  var game = try missionGearGame()
  try game.commander.grantEquipment(
    "Large Cargo Bay", at: .utility(.cargoExpansion), provenance: .grant("stowage-fixture"))
  try game.commander.grantEquipment(
    FuelStorage.equipmentName, at: .fuelStorage(0), provenance: .grant("stowage-fixture"))
  game.commander.cargo[0] = 30
  game.commander.fuel = 140
  let before = game.commander
  for slot in [ComponentFittingSlot.utility(.cargoExpansion), .fuelStorage(0)] {
    let item = try #require(game.commander.fittedEquipment(at: slot))
    #expect(game.inventoryActionPreview(for: .equipment(item)).command == nil)
    #expect(game.commander == before)
  }
  game.commander.cargo[0] = 0
  game.commander.fuel = 70
  let tank = try #require(game.commander.fittedEquipment(at: .fuelStorage(0)))
  try missionStorePhysical(tank, in: &game)
  let stored = try #require(game.commander.equipmentInventory?.items.first { $0.id == tank.id })
  let refit = try #require(game.inventoryActionPreview(for: .equipment(stored)).command)
  #expect(game.performInventoryCommand(refit))
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
  #expect(!stale.applied && (await runtime.snapshot().commander) == before)
  for paused in [false, true] {
    var blocked = game
    blocked.paused = paused
    blocked.docked = paused
    let refusal = blocked.performEquipmentMutation(.inventory(command))
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
  #expect(first.projected == second.projected && game.commander == before)
  #expect(game.selectedGameProfile?.fields.first { $0.key == "fitted_missiles" }?.number == 4)
  #expect(game.selectedGameProfile?.fields.first { $0.key == "fitted_lasers" }?.number == 1)
}
