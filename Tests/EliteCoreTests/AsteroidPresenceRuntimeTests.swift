import Foundation
import Testing

@testable import EliteCore

private func changedPresenceSystem() throws -> StarSystem {
  try #require(
    Universe.galaxy().first { system in
      !AsteroidBeltDefinition.isPresent(system: system, galaxy: 0, policy: .legacyUniform)
        && AsteroidBeltDefinition.isPresent(system: system, galaxy: 0, policy: .economyWeighted)
    })
}
private func legacyMiningIncident(_ system: SystemIdentity) -> CombatIncident {
  .init(
    id: 1, physicalTime: 1,
    origin: .init(
      emissionID: 1, owner: .init(system: system, visit: 1, entity: 0),
      emittedAt: 1, ownerLegalAtEmission: .init()),
    victim: nil, kind: .laser, outcome: .hit, position: .init(0, 0, 0),
    victimLegalBeforeAttack: nil, firstAggressor: nil, victimRole: nil,
    victimIsStation: false, laser: .mining, mount: .front)
}

struct AsteroidPresenceRuntimeTests {
  @Test func nativeSceneAndMinerPlannerShareTheSameResolvedAbsenceAndLegacyClusters() throws {
    var game = Game(executive: false)
    game.commander.system = try #require(
      game.systems.first {
        $0.government == 7 && !MiningLedger().ringPresence(system: $0, galaxy: 0)
      }?.id)
    game.launch()
    try #require(!game.docked && game.miningFields.isEmpty)
    game.bodies = [.init(id: 80, hull: .cobra, position: .init(0, 0, 5000))]
    game.nextBodyID = 81
    game.ensurePhysicalActors()
    game.bodies[0].physical?.npc?.role = .miner
    let actor = try #require(game.bodies[0].physical?.identity)
    let context = try #require(game.gameplayContext())
    #expect(context.miningPresence == .init(ringPresent: false, includingLegacy: false))
    let idle = try #require(TrafficIntent.intents(context: context).first { $0.actor == actor })
    #expect(idle.action == .navigate(position: context.actors[0].position, speedUnitsPerSecond: 0))
    game.commander.miningLedger = .legacyUnworked()
    try game.migrateMiningPresence(legacyMissing: false)
    game.rebuildMiningFields()
    let legacy = try #require(game.gameplayContext())
    #expect(legacy.miningPresence?.includingLegacy == true)
    #expect(game.miningFields.contains { $0.rocks.contains { $0.identity.field < 4 } })
    let planned = try #require(TrafficIntent.intents(context: legacy).first { $0.actor == actor })
    let actualNearest = try #require(
      game.miningFields.min {
        ($0.position - legacy.actors[0].position).length
          < ($1.position - legacy.actors[0].position).length
      })
    #expect(
      planned.action
        == .navigate(
          position: actualNearest.position,
          speedUnitsPerSecond: legacy.actors[0].maximumSpeedUnitsPerSecond))
  }

  @Test func actualLegacyLoadPinsCurrentAbsenceAndAllHistoricalGalaxiesIncludingPlugh() async throws
  {
    var game = Game(executive: false)
    game.commander.system = try changedPresenceSystem().id
    game.launch()
    try #require(!game.docked)
    var ledger = MiningLedger.legacyUnworked()
    game.commander.discoverPlugh(in: 3)
    let identity = SystemIdentity(galaxy: 3, system: Plugh.systemID)
    var flight = FlightSimulationState()
    flight.enter(identity, arriving: false)
    let anchors = try #require(flight.anchors)
    let rock = try #require(
      MiningFields.generate(
        anchors: anchors, seed: AsteroidBeltDefinition.seed(for: Plugh.system(galaxy: 3)),
        ringPresent: false, includingLegacy: true
      ).flatMap(\.rocks).first)
    let hit = ledger.hit(rock: rock, incident: legacyMiningIncident(identity), damage: 1)
    try #require(hit != .ignored)
    game.commander.miningLedger = ledger
    game.ensureScriptCalendar(origin: .inactiveLegacyMigration)
    game.rebuildMiningFields()
    let original = game.commander
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("commander.json")
    try ScriptSaveStore.write(commander: original, world: game.scriptWorldSave, to: file)
    let oldPointer = try JSONDecoder().decode(ScriptSavePointer.self, from: Data(contentsOf: file))
    try #require(oldPointer.schemaVersion < 26)
    let runtime = GameRuntime()
    try await runtime.load(from: file)
    let restored = await runtime.snapshot()
    let migrated = restored.commander.miningLedger
    #expect(migrated.usesEconomyWeightedPresence && migrated.retainsLegacyFields)
    #expect(migrated.requiredPresencePinSystems == ledger.requiredPresencePinSystems)
    #expect(migrated.remainingEnergy(for: rock) == ledger.remainingEnergy(for: rock))
    #expect(!migrated.ringPresence(system: game.currentSystem, galaxy: 0))
    #expect(restored.commander.flightSimulation == original.flightSimulation)
    #expect(restored.commander.cargo == original.cargo && restored.commander.fuel == original.fuel)
    #expect(restored.miningFields.allSatisfy { $0.rocks.allSatisfy { $0.identity.field < 4 } })
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: Data(contentsOf: file))
    #expect(pointer.schemaVersion == 26)
    try await runtime.load(from: file)
    let twice = await runtime.snapshot()
    #expect(twice.commander.miningLedger == migrated)
  }

  @Test func firstStationSavePersistsFreshWeightedPolicyInsteadOfBecomingLegacyOnReload()
    async throws
  {
    var game = Game(executive: false)
    game.commander.system = try changedPresenceSystem().id
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: file)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: Data(contentsOf: file))
    #expect(pointer.schemaVersion == 26)
    let loaded = GameRuntime()
    try await loaded.load(from: file)
    let restored = await loaded.snapshot()
    #expect(restored.commander.miningLedger.usesEconomyWeightedPresence)
    #expect(
      restored.resolvedMiningPresence.ringPresent
        && !restored.resolvedMiningPresence.includingLegacy)
  }

  @Test func futurePresenceKeysRejectNullAndOlderHeadersBeforeAnyMiningStateCanDisappear() throws {
    for key in ["legacyClusters", "presenceOverrides"] {
      let bytes = try JSONSerialization.data(withJSONObject: ["savedMiningLedger": [key: NSNull()]])
      #expect(throws: SaveError.self) { try EconomyMiningVersionedSave.rejectFields(bytes) }
      var object = try #require(
        JSONSerialization.jsonObject(
          with: JSONEncoder().encode(MiningLedger())) as? [String: Any])
      object[key] = NSNull()
      let poisoned = try JSONSerialization.data(withJSONObject: object)
      #expect(throws: (any Error).self) {
        _ = try JSONDecoder().decode(MiningLedger.self, from: poisoned)
      }
    }
    let generation = try JSONSerialization.data(withJSONObject: [
      "savedMiningLedger": ["generation": 2]
    ])
    #expect(throws: SaveError.self) { try EconomyMiningVersionedSave.rejectFields(generation) }
  }
}
