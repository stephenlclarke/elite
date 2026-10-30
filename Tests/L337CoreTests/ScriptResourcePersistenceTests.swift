import Foundation
import Testing

@testable import L337Core

private func grandfatheredMissionResources() throws -> Commander {
  var commander = try PreDriveCommanderSaveFixture.commander()
  let inventory = try #require(commander.equipmentInventory)
  var items = inventory.items
  for slot in [ComponentFittingSlot.energy, .shield] {
    let original = try #require(commander.fittedEquipment(at: slot))
    let component = try #require(original.component)
    var statistics = component.statistics
    if slot == .energy {
      statistics[.energyCapacity] = 1e100
    } else {
      statistics[.frontShieldCapacity] = 1e95
      statistics[.rearShieldCapacity] = 1e90
    }
    // Retain actual native hardware identity and acquisition history in an admitted old save.
    let changed = ComponentInstance(
      id: component.id, origin: component.origin, statistics: statistics,
      grade: component.grade, features: component.features, receipts: component.receipts)
    let replacement = OwnedEquipmentItem(
      id: original.id, node: original.node, provenance: original.provenance,
      component: changed, location: original.location, boundHull: original.boundHull)
    items = items.map { $0.id == original.id ? replacement : $0 }
  }
  commander.savedEquipmentInventory = try .init(
    owner: inventory.owner, activeHull: inventory.activeHull, revision: inventory.revision,
    items: items)
  commander.mirrorFittedEquipment()
  try #require(commander.valid)
  return commander
}

struct ScriptResourcePersistenceTests {
  @Test func admittedHighNativeResourcesStartAMissionAndRoundTripThroughCurrentFormat() async throws
  {
    let fixture = try GearScriptFixture(requiredReturn: false, accepted: "")
    defer { fixture.clean() }
    let commander = try grandfatheredMissionResources()
    let raw = fixture.root.appendingPathComponent("grandfathered.json")
    let originalRawBytes = try JSONEncoder().encode(commander)
    try originalRawBytes.write(to: raw)
    var host = Game(executive: false)
    host.scriptPacks = [fixture.pack]
    let runtime = GameRuntime(game: host)
    try await runtime.load(from: raw, persistMigrations: false)
    var admitted = await runtime.snapshot()
    let inventory = try #require(admitted.commander.equipmentInventory)
    let originalInventory = try #require(commander.equipmentInventory)
    #expect(
      inventory.owner == originalInventory.owner
        && inventory.activeHull == originalInventory.activeHull)
    #expect(admitted.commander.equipmentPurchaseHistory == commander.equipmentPurchaseHistory)
    for item in originalInventory.items {
      #expect(inventory.items.first { $0.id == item.id } == item)
    }
    let originalIDs = Set(originalInventory.items.map(\.id))
    let additions = inventory.items.filter { !originalIDs.contains($0.id) }
    try #require(additions.count == 1)
    let drive = try #require(additions.first)
    try #require(drive.isReservedStockDrive && drive.location?.slot == .drive)
    let retainedRawBytes = try Data(contentsOf: raw)
    let rawObject = try JSONSerialization.jsonObject(with: retainedRawBytes) as? [String: Any]
    #expect(rawObject?["savedEquipmentVersion"] as? Int == 2)
    let decodedRaw = try JSONDecoder().decode(Commander.self, from: retainedRawBytes)
    #expect(decodedRaw == commander && retainedRawBytes == originalRawBytes)
    #expect(
      admitted.commander.credits == commander.credits && admitted.commander.cargo == commander.cargo
    )
    #expect(
      admitted.commander.name == commander.name && admitted.commander.shipID == commander.shipID)
    #expect(
      admitted.commander.fuel == commander.fuel && admitted.commander.missiles == commander.missiles
    )
    #expect(admitted.energy == commander.performance.energy && admitted.energy > 1e12)
    #expect(admitted.frontShield == commander.shieldCapacity && admitted.frontShield > 1e12)
    #expect(admitted.rearShield == commander.rearShieldCapacity && admitted.rearShield > 1e12)
    admitted.screen = .status
    let id = try admitted.acceptScriptMission(fixture.pack)
    try #require(admitted.commander.scriptState.instances[id]?.suspension == nil)
    try #require(admitted.commander.scriptState.instances[id]?.outcome == .active)
    #expect(admitted.commander.equipmentInventory == inventory)
    let save = fixture.root.appendingPathComponent("mission.json")
    try GameRuntime.writeCommander(&admitted, to: save)
    let bytes = try Data(contentsOf: save)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == 26)
    let (saved, world) = try ScriptSaveStore.read(bytes, from: save)
    #expect(saved.valid && world.valid && world.consistent(with: saved))
    #expect(saved.equipmentInventory == inventory)
    #expect(world.energy == admitted.energy && world.frontShield == admitted.frontShield)
    #expect(world.rearShield == admitted.rearShield)
    let restored = GameRuntime(game: host)
    try await restored.load(from: save)
    let loaded = await restored.snapshot()
    #expect(loaded.energy == admitted.energy && loaded.frontShield == admitted.frontShield)
    #expect(loaded.rearShield == admitted.rearShield)
    #expect(loaded.commander.equipmentInventory == inventory)
    #expect(
      loaded.commander.scriptState.instances[id] == admitted.commander.scriptState.instances[id])
    try await restored.save(to: save)
    let (resaved, resavedWorld) = try ScriptSaveStore.read(Data(contentsOf: save), from: save)
    #expect(resaved.equipmentInventory == inventory && resavedWorld.energy == loaded.energy)
    #expect(
      resavedWorld.frontShield == loaded.frontShield && resavedWorld.rearShield == loaded.rearShield
    )
  }

  @Test(arguments: ["energy", "front", "rear"])
  func resourceJoinPreservesLegacyEnvelopeButRefusesBeyondItsOwnNativeCapacity(field: String) throws
  {
    let commander = try grandfatheredMissionResources()
    var game = Game(executive: false)
    game.commander = commander
    var world = game.scriptWorldSave
    let capacity: Double
    switch field {
    case "energy": capacity = commander.performance.energy
    case "front": capacity = commander.shieldCapacity
    default: capacity = commander.rearShieldCapacity
    }
    func set(_ value: Double, in world: inout ScriptWorldSave) {
      switch field {
      case "energy": world.energy = value
      case "front": world.frontShield = value
      default: world.rearShield = value
      }
    }
    set(capacity, in: &world)
    #expect(world.valid && world.consistent(with: commander))
    set(capacity.nextUp, in: &world)
    #expect(world.valid && !world.consistent(with: commander))
    let ordinary = Commander()
    set(1e12, in: &world)
    #expect(world.valid && world.consistent(with: ordinary))
    set(1e12.nextUp, in: &world)
    #expect(world.valid && !world.consistent(with: ordinary))
    for invalid in [-1.0, Double.infinity, Double.nan] {
      set(invalid, in: &world)
      #expect(!world.valid)
    }
  }
}
