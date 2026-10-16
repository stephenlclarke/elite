import Foundation
import Testing

@testable import EliteCore

struct NativeAmmunitionRuntimeTests {
  private func flight(rounds: Int = 3) throws -> Game {
    var game = Game(executive: false)
    game.commander.missiles = rounds
    try game.commander.prepareEquipment(legacy: false)
    game.launch()
    game.speed = 0
    game.commander.flightSimulation.pose.position = .init(0, 0, -3000)
    game.bodies = [.init(id: 70, hull: .cobra, position: .init(0, 0, 1800))]
    game.ensurePhysicalActors()
    game.weaponsTargetID = 70
    game.missileArmed = true
    return game
  }

  @Test func nativeLaunchUsesTheHighestOccupiedPhysicalPylonEvenWithAHole() throws {
    var game = try flight()
    let inventory = try #require(game.commander.equipmentInventory)
    let hole = try #require(game.commander.fittedEquipment(at: .missilePylon(1)))
    let last = try #require(game.commander.fittedEquipment(at: .missilePylon(2)))
    var stored = inventory
    try stored.store(
      expected: hole, expectedRevision: stored.revision,
      context: EquipmentRuntimeCatalog.context(
        owner: inventory.owner, hull: inventory.activeHull,
        performance: game.commander.nativePerformance))
    game.commander.savedEquipmentInventory = stored
    game.commander.mirrorFittedEquipment()
    let before = game.commander
    let launched = game.fireMissile()
    #expect(launched)
    let origin = try #require(
      game.bodies.first { $0.physical?.ordnance != nil }?.physical?.attackOrigin)
    #expect(origin.playerAmmunition == .physical(item: last.id))
    #expect(game.commander.missiles == 1 && game.commander.valid)
    #expect(game.commander.equipmentInventory?.revision == stored.revision + 1)
    #expect(game.commander.equipmentInventory?.items.contains { $0.id == last.id } == false)
    let held = try #require(game.commander.equipmentInventory?.items.first { $0.id == hole.id })
    #expect(held == hole.moved(to: nil))
    #expect(game.commander.equipmentPurchaseHistory == before.equipmentPurchaseHistory)
  }

  @Test func virtualNativeLaunchNeverSpendsAPhysicalRoundOrMintsAnEmptyRack() throws {
    for count in [0, 3] {
      var game = try flight(rounds: count)
      game.commander.unlimitedMissiles = true
      let before = game.commander
      let launched = game.fireMissile()
      #expect(launched)
      let origin = try #require(
        game.bodies.first { $0.physical?.ordnance != nil }?.physical?.attackOrigin)
      #expect(origin.playerAmmunition == .virtualUnlimited)
      #expect(game.commander.equipmentInventory == before.equipmentInventory)
      #expect(game.commander.equipmentPurchaseHistory == before.equipmentPurchaseHistory)
      #expect(game.commander.missiles == count && game.commander.valid)
      let saved = try JSONDecoder().decode(
        Commander.self, from: JSONEncoder().encode(game.commander))
      #expect(saved.equipmentInventory == before.equipmentInventory && saved.missiles == count)
    }
  }

  @Test func refusedNativeProjectileAdmissionPreservesInventoryAndEverySimulationAllocator() throws
  {
    var game = try flight()
    for id in 100..<132 {
      game.bodies.append(.init(id: id, hull: .missile, position: .init(Double(id) * 10, 0, 4000)))
    }
    game.ensurePhysicalActors()
    let original = game
    let launched = game.fireMissile()
    #expect(!launched)
    #expect(game.commander == original.commander && game.bodies == original.bodies)
    #expect(game.nextBodyID == original.nextBodyID && game.missileArmed == original.missileArmed)
    #expect(game.commander.flightSimulation == original.commander.flightSimulation)
    #expect(game.commander.crimeLedger == original.commander.crimeLedger)
    #expect(game.commander.scriptState == original.commander.scriptState)
  }

  private func observer(_ definition: String, outcome: ScriptOutcome = .active) -> ScriptInstance {
    var instance = ScriptInstance(
      id: UUID(), definition: definition, version: "1.0.0",
      digest: String(repeating: "a", count: 64))
    instance.outcome = outcome
    return instance
  }

  @Test func personalPhysicalConsumptionBroadcastsToEveryActiveObserver() throws {
    var game = try flight()
    let observers = [observer("observer/first"), observer("observer/second")]
    for instance in observers { game.commander.scriptState.instances[instance.id] = instance }
    #expect(game.commander.valid)
    let round = try #require(game.commander.fittedEquipment(at: .missilePylon(2)))
    let launched = game.fireMissile()
    #expect(launched && game.commander.valid)
    let events = game.commander.scriptState.pendingEvents
    #expect(events.count == 2 && Set(events.map(\.instance)) == Set(observers.map(\.id)))
    #expect(
      events.allSatisfy {
        $0.kind == "gear.consumed" && $0.values["item"] == .string(round.id.uuidString)
          && $0.values["name"] == .string("Missile")
      })
    #expect(events.map(\.sequence) == [1, 2])
  }

  @Test func inactiveIssuerStillRecordsConsumptionAndItsActiveObserverReceivesTheEvent() throws {
    var game = try flight()
    var issuer = observer("issuer/rounds", outcome: .abandoned)
    let watcher = observer("observer/active")
    let round = try #require(game.commander.fittedEquipment(at: .missilePylon(2)))
    let source = EquipmentIssueSource(
      mission: issuer.id, resource: "rounds", packDigest: issuer.digest)
    issuer.gearIssues["rounds"] = .init(
      resource: "rounds", kind: .missile, items: [round.id],
      loan: true, returnRemaining: true, savedGearVersion: 2, source: source, node: round.node,
      displacements: [])
    game.commander.scriptState.instances = [issuer.id: issuer, watcher.id: watcher]
    let inventory = try #require(game.commander.equipmentInventory)
    let issued = OwnedEquipmentItem(
      id: round.id, node: round.node,
      provenance: .missionIssue(
        mission: issuer.id, resource: "rounds", index: 0, packDigest: issuer.digest),
      location: round.location)
    game.commander.savedEquipmentInventory = try inventory.applyingBatch(
      items: inventory.items.map { $0.id == round.id ? issued : $0 },
      expectedRevision: inventory.revision,
      context: EquipmentRuntimeCatalog.context(
        owner: inventory.owner, hull: inventory.activeHull,
        performance: game.commander.nativePerformance))
    #expect(game.commander.valid)
    let launched = game.fireMissile()
    #expect(launched && game.commander.valid)
    #expect(
      game.commander.scriptState.instances[issuer.id]?.gearIssues["rounds"]?.consumed == [round.id])
    #expect(game.commander.scriptState.pendingEvents.map(\.instance) == [watcher.id])
  }

  @Test func anInsufficientWholeBroadcastBudgetRefusesEveryPhysicalAndQueueEffect() throws {
    for queueFull in [false, true] {
      var game = try flight()
      let observers = [observer("observer/first"), observer("observer/second")]
      for instance in observers { game.commander.scriptState.instances[instance.id] = instance }
      if queueFull {
        game.commander.scriptState.nextEvent = 4095
        let context = game.scriptEventContext(observers[0])
        game.commander.scriptState.pendingEvents = (1...4095).map { sequence in
          ScriptEvent(
            sequence: UInt64(sequence), kind: "fixture", instance: observers[0].id,
            values: [:], context: context)
        }
      } else {
        game.commander.scriptState.nextEvent = UInt64(Int64.max) - 2
      }
      #expect(game.commander.valid)
      let before = game
      let launched = game.fireMissile()
      #expect(!launched && game.commander == before.commander && game.bodies == before.bodies)
      #expect(
        game.inventoryContextEpoch == before.inventoryContextEpoch
          && game.nextBodyID == before.nextBodyID)
    }
  }

  private func pinAllocator(_ key: String, game: inout Game) throws {
    var object = try #require(
      JSONSerialization.jsonObject(
        with: JSONEncoder().encode(game.commander.flightSimulation)) as? [String: Any])
    object[key] = NSNumber(value: UInt64.max - 1)
    game.commander.flightSimulation = try JSONDecoder().decode(
      FlightSimulationState.self,
      from: JSONSerialization.data(withJSONObject: object))
    #expect(game.commander.valid)
  }

  @Test func validNearBoundaryNativeAllocatorsCannotPublishAnInvalidLaunch() throws {
    for key in ["nextActor", "nextSpawn", "nextEmission", "nextIncident"] {
      var game = try flight()
      try pinAllocator(key, game: &game)
      let before = game
      let launched = game.fireMissile()
      #expect(!launched && game.commander == before.commander && game.bodies == before.bodies)
      #expect(
        game.inventoryContextEpoch == before.inventoryContextEpoch
          && game.nextBodyID == before.nextBodyID)
    }
  }

  @Test func aBombWhoseRequiredDeathIncidentCannotBeRecordedRetainsItsDeviceAndVictim() throws {
    var game = try flight()
    try game.commander.grantEquipment(
      "Energy Bomb", at: .utility(.energyBomb), provenance: .standard)
    try pinAllocator("nextIncident", game: &game)
    let before = game
    game.energyBomb()
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    #expect(
      game.inventoryContextEpoch == before.inventoryContextEpoch
        && game.nextBodyID == before.nextBodyID)
  }
}
