import Foundation
import Testing

@testable import EliteCore

/// Unit release boundaries use the authoritative clock; original native flight tests remain separate.
private func legacyCatalogueGame() throws -> Game {
  var game = try empFixture()
  let body = game.bodies[0]
  let actor = try #require(body.physical?.identity)
  let native = game.nativePhysicalActorState(for: body, identity: actor)
  game.bodies[0].physical = native
  try fitEliteEMPTestEnergy(&game)
  try #require(game.bodies[0].physical?.catalogueShipID == nil)
  try #require(game.bodies[0].physical?.npc?.resources?.profile == .legacyEnergyOnly)
  try #require(game.commander.valid)
  return game
}

private func releaseLegacyCataloguePulse(_ game: inout Game) throws {
  let began = game.fireEMPPirateBlaster()
  try #require(began)
  game.commander.flightSimulation.advancePhysicalTime(10)
  game.advanceEMPCharge(triggerHeld: true)
  try #require(game.commander.savedEMPCharge?.phase == .released)
}

private func expectLegacyCatalogueRefusal(
  _ game: inout Game, before: Commander, bodies: [SpaceBody], simulation: ScriptSimulationSave,
  audio: DischargeAudioState, energy: Double, heat: Double
) throws {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.sortedKeys]
  let beforeSimulation = try encoder.encode(simulation)
  let now = game.commander.flightSimulation.physicalTime
  game.advanceEMPCharge(triggerHeld: true)
  var expected = before
  expected.savedEMPCharge?.phase = .released
  expected.savedEMPCharge?.endedAt = now
  #expect(game.commander == expected && game.bodies == bodies)
  let afterSimulation = try encoder.encode(game.scriptSimulationSave)
  #expect(afterSimulation == beforeSimulation)
  #expect(game.dischargeAudio.epoch == audio.epoch && game.dischargeAudio.events == audio.events)
  #expect(game.energy == energy && game.laserHeat == heat)
  #expect(game.commander.savedEMPState == nil && game.commander.savedPlayerElectrical == nil)
  #expect(game.message == "EMP RELEASE REFUSED - TARGET OR EQUIPMENT CHANGED")
}

struct EMPLegacyCatalogueTests {
  @Test func actualNativeAliasPinsItsResolvedCatalogueAcrossPartialAndZeroPulses() throws {
    var game = try legacyCatalogueGame()
    let original = game.bodies[0]
    let actor = try #require(original.physical?.identity)
    let inventory = game.commander.equipmentInventory
    let native = try #require(ShipCatalogue.nativeShip(.cobra))
    try releaseLegacyCataloguePulse(&game)
    let partial = try #require(game.bodies.first { $0.id == original.id })
    #expect(partial.physical?.identity == actor && partial.hull == original.hull)
    #expect(partial.energy == original.energy)
    #expect(partial.physical?.catalogueShipID == native.id)
    #expect(partial.physical?.npc?.resources?.legacyElectricalRecharge == native.game?.recharge)
    #expect(partial.physical?.npc?.resources?.electrical?.remaining == 20)
    #expect(partial.physical?.npc?.ordinaryCargo == original.physical?.npc?.ordinaryCargo)
    #expect(game.commander.savedEMPState == nil && game.dischargeAudio.events.count == 1)
    game.advanceEMPCharge(triggerHeld: false)
    for _ in 0..<16 { game.tick(delta: 0.1) }
    try #require(game.fireCooldown == 0)
    let beforeZero = try #require(game.bodies.first { $0.physical?.identity == actor })
    try releaseLegacyCataloguePulse(&game)
    let source = try #require(game.bodies.first { $0.id == original.id }?.physical?.empSource)
    let record = try #require(game.commander.savedEMPState?.records[source])
    #expect(source == actor && record.originalBodyID == original.id)
    #expect(record.custody.original.body.physical?.catalogueShipID == native.id)
    #expect(record.custody.traffic?.catalogueShipID == native.id)
    #expect(record.custody.valid && record.valid && game.commander.valid)
    #expect(record.hull.body.energy == beforeZero.energy)
    #expect(record.cargo == beforeZero.physical?.npc?.ordinaryCargo)
    #expect(record.legal == beforeZero.physical?.npc?.legal)
    #expect(record.crewTotal == 1 && record.crewAboard == 1)
    #expect(record.hull.body.physical?.npc?.resources?.electrical?.remaining == 0)
    #expect(record.disableIncident.physicalTime == game.commander.flightSimulation.physicalTime)
    #expect(game.commander.equipmentInventory == inventory && game.dischargeAudio.events.count == 2)
  }

  @Test func retainedPartialNativeAliasSurvivesStrictSaveAndCanReachActualZero() async throws {
    var game = try legacyCatalogueGame()
    let original = game.bodies[0]
    let actor = try #require(original.physical?.identity)
    let native = try #require(ShipCatalogue.nativeShip(.cobra)?.game)
    var resources = try #require(original.physical?.npc?.resources)
    resources.legacyElectricalRecharge = native.recharge
    var reserve = try #require(
      ElectricalReserve(
        capacity: resources.energyCapacity, recharge: native.recharge,
        at: game.commander.flightSimulation.physicalTime))
    let drained = reserve.drain(resources.energyCapacity - 20, at: reserve.physicalTime)
    try #require(drained && reserve.remaining == 20 && reserve.disabledAt == nil)
    resources.electrical = reserve
    game.bodies[0].physical?.npc?.resources = resources
    let refusals = game.persistNPCStates()
    try #require(refusals.isEmpty && game.commander.valid)
    let directory = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
      .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("commander.json")
    try GameRuntime.writeCommander(&game, to: file)
    let bytes = try Data(contentsOf: file)
    let originalFiles = try ScriptFinanceTestFixture.files(directory)
    let (stored, world) = try ScriptSaveStore.read(bytes, from: file)
    #expect(stored.npcPersistence.snapshot(for: actor)?.catalogueShipID == nil)
    #expect(
      stored.npcPersistence.snapshot(for: actor)?.npc.resources?.legacyElectricalRecharge
        == native.recharge)
    #expect(world.bodies.first { $0.id == original.id }?.physical?.catalogueShipID == nil)
    let runtime = GameRuntime(game: game)
    try await runtime.load(from: file, persistMigrations: false)
    var loaded = await runtime.snapshot()
    let retained = try #require(loaded.bodies.first { $0.id == original.id })
    try #require(retained.physical?.catalogueShipID == nil)
    try #require(retained.physical?.npc?.resources?.electrical?.remaining == 20)
    try releaseLegacyCataloguePulse(&loaded)
    let source = try #require(loaded.bodies.first { $0.id == original.id }?.physical?.empSource)
    let record = try #require(loaded.commander.savedEMPState?.records[source])
    #expect(source == actor && record.valid && record.custody.valid && loaded.commander.valid)
    #expect(record.custody.original.body.physical?.catalogueShipID == "SH023")
    #expect(record.custody.traffic?.catalogueShipID == "SH023")
    #expect(
      record.hull.body.energy == retained.energy
        && record.cargo == retained.physical?.npc?.ordinaryCargo)
    #expect(record.crewTotal == 1 && record.crewAboard == 1)
    let finalBytes = try Data(contentsOf: file)
    let finalFiles = try ScriptFinanceTestFixture.files(directory)
    #expect(finalBytes == bytes && finalFiles == originalFiles)
  }

  @Test(arguments: [false, true])
  func unknownCatalogueOrForgedRechargeCannotPublishIdentityOrPulse(invalidRecharge: Bool) throws {
    var game = try legacyCatalogueGame()
    let began = game.fireEMPPirateBlaster()
    try #require(began)
    if invalidRecharge {
      let recharge = try #require(ShipCatalogue.nativeShip(.cobra)?.game?.recharge)
      game.bodies[0].physical?.npc?.resources?.legacyElectricalRecharge = recharge + 1
    } else {
      game.bodies[0].physical?.catalogueShipID = "UNKNOWN-EMP-CATALOGUE"
    }
    game.commander.flightSimulation.advancePhysicalTime(10)
    let before = game.commander
    let bodies = game.bodies
    let simulation = game.scriptSimulationSave
    let audio = game.dischargeAudio
    let energy = game.energy
    let heat = game.laserHeat
    try expectLegacyCatalogueRefusal(
      &game, before: before, bodies: bodies, simulation: simulation,
      audio: audio, energy: energy, heat: heat)
    #expect(
      game.bodies[0].physical?.catalogueShipID == (invalidRecharge ? nil : "UNKNOWN-EMP-CATALOGUE"))
  }

  @Test func lateUnrelatedCaptureRefusalRollsBackTheNewNativeAliasPinAndWholePulse() throws {
    var game = try legacyCatalogueGame()
    game.bodies.append(.init(id: 99, hull: .cobra, position: .init(4000, 1000, 9000)))
    game.nextBodyID = 100
    game.ensurePhysicalActors()
    let bad = try #require(game.bodies.firstIndex { $0.id == 99 })
    let native = try #require(ShipCatalogue.nativeShip(.cobra)?.game)
    game.bodies[bad].physical?.catalogueShipID = "SH023"
    game.bodies[bad].physical?.npc?.resources = .stock(native)
    game.bodies[bad].energy = native.energy * 2
    let began = game.fireEMPPirateBlaster()
    try #require(began && game.commander.valid)
    game.commander.flightSimulation.advancePhysicalTime(10)
    let before = game.commander
    let bodies = game.bodies
    let simulation = game.scriptSimulationSave
    let audio = game.dischargeAudio
    let energy = game.energy
    let heat = game.laserHeat
    try expectLegacyCatalogueRefusal(
      &game, before: before, bodies: bodies, simulation: simulation,
      audio: audio, energy: energy, heat: heat)
    #expect(game.bodies[0].physical?.catalogueShipID == nil)
    #expect(game.bodies[0].physical?.npc?.resources?.legacyElectricalRecharge == nil)
    game.bodies.removeAll { $0.id == 99 }
    game.advanceEMPCharge(triggerHeld: false)
    try releaseLegacyCataloguePulse(&game)
    #expect(game.bodies[0].physical?.catalogueShipID == "SH023")
    #expect(game.dischargeAudio.events.count == 1 && game.dischargeAudio.events.first?.id == 1)
  }
}
