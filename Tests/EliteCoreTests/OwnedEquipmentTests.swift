import Foundation
import Testing

@testable import EliteCore

private func gearFolder() throws -> URL {
  let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
    "gear-" + UUID().uuidString)
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  return folder
}

@Test func replacingOwnedWeaponsAndComputersStoresTheOriginalIdentities() throws {
  var commander = Commander()
  commander.installTargetingComputer(.basic)
  commander.installNavigationComputer(.basic)
  commander.installShieldBooster(.pulse)
  commander.synchronizeEquipmentInventory(force: true)
  let old = try #require(commander.ownedEquipment)
  commander.installLaser(.beam, on: .front)
  commander.installTargetingComputer(.military)
  commander.installNavigationComputer(.military)
  commander.installShieldBooster(.military)
  let upgraded = try #require(commander.ownedEquipment)
  #expect(Set(old.items.map(\.id)).isSubset(of: Set(upgraded.items.map(\.id))))
  #expect(upgraded.stored.count == 4 && commander.valid)
  commander.installLaser(.beam, on: .front)
  commander.installTargetingComputer(.basic)
  #expect(commander.ownedEquipment == upgraded)
}

@Test func anOccupiedCabinBlocksAZeroHoldHullWhileItsPersonAndEquipmentRemainOwned() throws {
  let example = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(
      "docs/mission-packs/scripted-passengers")
  let pack = try ScriptPackLibrary.read(example)
  var library = Game(executive: false)
  library.scriptPacks = [pack]
  let trial = try library.makeScriptTrial(packDigest: pack.digest, seed: 9)
  let before = trial.commander
  let plan = before.equipmentTransfer(to: "SH128")
  #expect(!plan.issues.isEmpty)
  #expect(plan.commander.accommodation.people == before.accommodation.people)
  #expect(plan.commander.accommodation.fitted == before.accommodation.fitted)
  #expect(plan.commander.accommodation.storedBerths.isEmpty)
  #expect(trial.commander == before)
}

@Test func consumptionRetainsStoredBombsHyperdrivesAndEscapePods() throws {
  for name in ["Energy Bomb", "Galactic Hyperdrive", "Escape Pod"] {
    var game = Game(executive: false)
    game.commander.equipment.insert(name)
    game.commander.synchronizeEquipmentInventory(force: true)
    let fitted = try #require(game.ownedFittedGear(named: name))
    var stored = OwnedGear(kind: .module(name), slot: .module(name))
    stored.fittedSlot = nil
    game.commander.ownedEquipment?.items.append(stored)
    game.launch()
    switch name {
    case "Energy Bomb": game.energyBomb()
    case "Galactic Hyperdrive": game.galacticJump()
    default: game.escapePod()
    }
    #expect(game.commander.ownedEquipment?.items.contains { $0.id == fitted.id } == false)
    #expect(game.commander.ownedEquipment?.stored.contains { $0.id == stored.id } == true)
    #expect(game.commander.valid)
  }
}

@Test func scriptsObserveOnlyCommittedHullRefitAndActualAmmunitionEvents() throws {
  let folder = try gearFolder()
  defer { try? FileManager.default.removeItem(at: folder) }
  let example = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(
      "docs/mission-packs/scripted-courier")
  let directory = folder.appendingPathComponent("pack")
  try FileManager.default.copyItem(at: example, to: directory)
  let manifest = directory.appendingPathComponent("manifest.toml")
  let original = try String(contentsOf: manifest, encoding: .utf8)
  var text = original.replacingOccurrences(
    of: "\"cargo-v2\"]", with: "\"cargo-v2\", \"owned-equipment-v2\"]")
  text +=
    "\n[[handlers]]\nevent = \"ship.changed\"\nfunction = \"changed\"\n[[handlers]]\nevent = \"equipment.changed\"\nfunction = \"refitted\"\n[[handlers]]\nevent = \"gear.consumed\"\nfunction = \"spent\"\n"
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
  var game = Game(executive: false)
  game.scriptPacks = [pack]
  game.screen = .showroom
  game.showroom.selection = "SH001"
  game.commander.credits = 10_000_000
  game.commander.missiles = 4
  let id = try game.acceptScriptMission(pack)
  _ = game.shipTradeQuote
  game.key("showroom-trade")
  game.key("return")
  #expect(game.commander.scriptState.instances[id]?.data["changes"] == .integer(0))
  game.key("showroom-trade")
  game.key("right")
  game.key("return")
  let state = try #require(game.commander.scriptState.instances[id])
  #expect(state.suspension == nil && state.data["changes"] == .integer(1))
  #expect(state.data["previous"] == .string("SH023") && state.data["ship"] == .string("SH001"))
  #expect(state.data["loaded"] == .integer(1) && state.data["stored"] == .integer(3))
  game.key("escape")
  game.key("3")
  game.selection = Equipment.all.firstIndex { $0.name == "Missile" }!
  game.key("s")
  game.key("r")
  #expect(game.commander.scriptState.instances[id]?.data["fits"] == .integer(2))
  let missile = try #require(game.commander.ownedEquipment?.fitted.first { $0.kind == .missile })
  game.launch()
  game.bodies = [SpaceBody(id: 1, hull: .sidewinder, position: .init(0, 0, 800))]
  game.missileArmed = true
  let fired = game.fireMissile()
  #expect(fired)
  game.drainScriptEvents()
  #expect(game.commander.scriptState.instances[id]?.data["shots"] == .integer(1))
  #expect(game.commander.scriptState.instances[id]?.data["spent"] == .string(missile.id.uuidString))
  try original.write(to: manifest, atomically: true, encoding: .utf8)
  try (original + "\n[[handlers]]\nevent=\"ship.changed\"\nfunction=\"changed\"\n").write(
    to: manifest, atomically: true, encoding: .utf8)
  #expect(throws: MissionPackError.self) { try ScriptPackLibrary.read(directory) }
}

@Test func actualEquipmentKeysStoreAndReuseLasersAndMissilesWithoutCharging() throws {
  var game = Game(executive: false)
  game.screen = .equipment
  game.selection = Equipment.all.firstIndex { $0.name == "Pulse Laser" }!
  let cash = game.commander.credits
  game.key("s")
  let laser = try #require(game.commander.ownedEquipment?.stored.first)
  #expect(game.commander.laser(on: .front) == nil && laser.kind == .laser(.pulse))
  game.equipmentMount = .rear
  game.key("r")
  #expect(game.commander.laser(on: .rear) == .pulse)
  #expect(
    game.commander.ownedEquipment?.items.first { $0.id == laser.id }?.fittedSlot == .laser(.rear))
  game.selection = Equipment.all.firstIndex { $0.name == "Missile" }!
  let missileIDs = Set(
    game.commander.ownedEquipment!.items.filter { $0.kind == .missile }.map(\.id))
  game.key("s")
  #expect(game.commander.missiles == 2 && game.commander.valid)
  game.key("r")
  #expect(game.commander.missiles == 3 && game.commander.valid)
  #expect(
    Set(game.commander.ownedEquipment!.items.filter { $0.kind == .missile }.map(\.id)) == missileIDs
  )
  #expect(game.commander.credits == cash)
}

@Test func stowingAnExpansionOrTankNeverDiscardsCargoOrFuel() throws {
  var game = Game(executive: false)
  game.screen = .equipment
  game.commander.equipment.insert("Large Cargo Bay")
  game.commander.cargo[0] = 30
  game.commander.fuelStorageUnits = 1
  game.commander.fuel = 140
  game.commander.synchronizeEquipmentInventory(force: true)
  let before = game.commander
  for name in ["Large Cargo Bay", FuelStorage.equipmentName] {
    game.selection = Equipment.all.firstIndex { $0.name == name }!
    game.key("s")
    #expect(game.commander == before)
  }
  game.commander.cargo[0] = 0
  game.commander.fuel = 70
  game.key("s")
  #expect(game.commander.fuelStorageUnits == 0 && game.commander.valid)
  game.key("r")
  #expect(game.commander.fuelStorageUnits == 1 && game.commander.fuel == 70)
}

@Test func actorFitQuotesAreStaleAfterAnotherOwnedRefitAndOutstationsCannotRefit() async throws {
  var game = Game(executive: false)
  game.screen = .equipment
  game.commander.synchronizeEquipmentInventory(force: true)
  let laser = try #require(
    game.commander.ownedEquipment?.items.first {
      if case .laser = $0.kind { return true }
      return false
    })
  let runtime = GameRuntime(game: game)
  let quote = await runtime.ownedGearFitQuote(laser.id, fitted: false)
  #expect(quote.allowed)
  try await runtime.confirmOwnedGearFit(quote)
  let before = await runtime.snapshot().commander
  await #expect(throws: MissionPackError.self) { try await runtime.confirmOwnedGearFit(quote) }
  #expect(await runtime.snapshot().commander == before)
  var outside = game
  outside.dockedAtMainStation = false
  #expect(!outside.ownedGearFitQuote(laser.id, fitted: false).allowed)
  outside.dockedAtMainStation = true
  outside.paused = true
  #expect(!outside.ownedGearFitQuote(laser.id, fitted: false).allowed)
}

@Test func repeatedExchangePreviewsHaveStableProvisionalIdentitiesAndLeaveTheCommanderAlone() throws
{
  var game = Game(executive: false)
  game.screen = .showroom
  game.showroom.selection = "SH001"
  game.commander.credits = 10_000_000
  let before = game.commander
  let a = try #require(game.shipTradeQuote)
  let b = try #require(game.shipTradeQuote)
  #expect(a.projected == b.projected && game.commander == before)
  #expect(game.selectedGameProfile?.fields.first { $0.key == "fitted_missiles" }?.number == 1)
  #expect(game.selectedGameProfile?.fields.first { $0.key == "fitted_lasers" }?.number == 1)
}

@Test func failedHullExchangeSavePublishesNeitherGearNorCashAndCanBeRetried() async throws {
  let folder = try gearFolder()
  defer { try? FileManager.default.removeItem(at: folder) }
  let directory = folder.appendingPathComponent("save")
  let file = directory.appendingPathComponent("commander.json")
  var game = Game(executive: false)
  game.screen = .showroom
  game.showroom.selection = "SH001"
  game.commander.credits = 10_000_000
  game.commander.missiles = 4
  let runtime = GameRuntime(game: game, saveURL: file)
  let before = await runtime.snapshot().commander
  try await runtime.save(to: file)
  let bytes = try Data(contentsOf: file)
  let backup = folder.appendingPathComponent("backup")
  try FileManager.default.moveItem(at: directory, to: backup)
  try Data("blocked".utf8).write(to: directory)
  await runtime.key("showroom-trade")
  await runtime.key("right")
  await runtime.key("return")
  #expect(await runtime.snapshot().commander == before)
  #expect(await runtime.snapshot().showroom.trading)
  #expect(try Data(contentsOf: backup.appendingPathComponent("commander.json")) == bytes)
  try FileManager.default.removeItem(at: directory)
  try FileManager.default.moveItem(at: backup, to: directory)
  await runtime.key("return")
  let after = await runtime.snapshot().commander
  #expect(after.shipID == "SH001" && after.missiles == 1 && after.valid)
  #expect(after.ownedEquipment?.stored.filter { $0.kind == .missile }.count == 3)
  let (saved, _) = try ScriptSaveStore.read(Data(contentsOf: file), from: file)
  #expect(saved == after)
}

@Test func hullTransfersStoreAndRefitTheSameLasersMissilesAndEmptyCabins() throws {
  var commander = Commander()
  commander.missiles = 4
  commander.equipment.insert("Large Cargo Bay")
  for mount in LaserMount.allCases { commander.installLaser(.military, on: mount) }
  let cabin = PassengerBerth()
  commander.accommodation.ownedBerths = [cabin]
  commander.accommodation.fitted = [cabin.id]
  commander.synchronizeEquipmentInventory(force: true)
  let before = try #require(commander.ownedEquipment)
  let down = commander.equipmentTransfer(to: "SH001")
  #expect(down.issues.isEmpty)
  #expect(down.commander.missiles == 1 && down.commander.accommodation.fitted.isEmpty)
  #expect(down.commander.laser(on: .front) == .military && down.commander.laser(on: .rear) == nil)
  #expect(down.commander.ownedEquipment?.stored.count == 7)
  #expect(down.commander.valid)
  let up = down.commander.equipmentTransfer(to: "SH023")
  #expect(up.issues.isEmpty && up.commander.valid)
  #expect(up.commander.ownedEquipment?.stored.isEmpty == true)
  #expect(Set(up.commander.ownedEquipment!.items.map(\.id)) == Set(before.items.map(\.id)))
  #expect(up.commander.missiles == 4 && up.commander.accommodation.fitted == [cabin.id])
}

@Test func firingAfterAStoredTransferConsumesOneActualMissileWithoutRecreatingIt() throws {
  var commander = Commander()
  commander.missiles = 4
  let down = commander.equipmentTransfer(to: "SH001")
  let before = try #require(down.commander.ownedEquipment)
  var game = Game(executive: false)
  let loaded = game.load(down.commander)
  #expect(loaded)
  game.launch()
  game.bodies = [SpaceBody(id: 1, hull: .sidewinder, position: .init(0, 0, 800))]
  game.missileArmed = true
  let launched = game.fireMissile()
  #expect(launched)
  let fired = game.commander
  let inventory = try #require(fired.ownedEquipment)
  #expect(inventory.stored.count == 3 && inventory.items.count == before.items.count - 1)
  let up = fired.equipmentTransfer(to: "SH023")
  #expect(up.commander.missiles == 3)
  #expect(
    Set(up.commander.ownedEquipment!.items.map(\.id)).isSubset(of: Set(before.items.map(\.id))))
  let decoded = try JSONDecoder().decode(Commander.self, from: JSONEncoder().encode(up.commander))
  #expect(decoded == up.commander && decoded.valid)
}

@Test func ownedGearRejectsDuplicateIdentitiesSlotsAndUnsupportedFittedChanges() throws {
  var commander = Commander()
  commander.synchronizeEquipmentInventory(force: true)
  var inventory = try #require(commander.ownedEquipment)
  let original = inventory.items[0]
  inventory.items.append(original)
  #expect(!inventory.valid)
  inventory.items.removeLast()
  inventory.items[0].condition = 4000
  #expect(!inventory.valid)
  inventory.items[0].fittedSlot = nil
  inventory.items[0].modifications = ["source-upgrade": 7]
  #expect(inventory.valid)
  commander.ownedEquipment = inventory
  commander.applyOwnedEquipmentFit()
  let transfer = commander.equipmentTransfer(to: "SH001")
  let preserved = try #require(
    transfer.commander.ownedEquipment?.items.first { $0.id == original.id })
  #expect(preserved.condition == 4000 && preserved.modifications["source-upgrade"] == 7)
  #expect(preserved.fittedSlot == nil)
}
