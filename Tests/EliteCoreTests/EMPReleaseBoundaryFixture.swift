import Foundation
import Testing

@testable import EliteCore

/// Controlled unit boundary, not a native flight or timing acceptance helper.
/// The target remains an ordinary, powered catalogue-backed craft until the real pulse drains it.
/// Damage readings are arranged at release time; no custody, crew or disabled flags are fabricated.
@discardableResult
func releaseDamagedEMPBoundary(
  _ game: inout Game, seed: UInt64? = 0,
  beforeRelease: ((inout Game) throws -> Void)? = nil
) throws -> Bool {
  let began = game.fireEMPPirateBlaster()
  guard began else { return false }
  if let seed { game.seedScriptTrial(seed) }
  let charge = try #require(game.commander.savedEMPCharge)
  #expect(charge.phase == .charging && game.commander.savedEMPState == nil)
  game.commander.flightSimulation.advancePhysicalTime(10)
  let contact = try game.nearestMissionCollision(
    from: .init(0, 0, 0), direction: .init(0, 0, 1),
    range: try EMPPulseProfile.resolve(for: game.commander).range,
    radius: 0, includePlayer: false)
  let hit = try #require(contact?.hit)
  guard case .body(let id) = hit.target else { throw SaveError.invalidCommander }
  let index = try #require(game.bodies.firstIndex { $0.id == id })
  let original = game.bodies[index]
  try #require(original.physical?.identity == charge.target && original.physical?.empSource == nil)
  var resources = try #require(original.physical?.npc?.resources)
  let power = try EMPPulseProfile.resolve(for: game.commander).power
  let remaining = min(resources.energyCapacity, power / 2)
  let front = (hit.point - original.position).dot(original.modelVector(.init(0, 0, 1))) >= 0
  let shield = min(front ? resources.frontCapacity : resources.rearCapacity, power - remaining)
  let opposite = front ? resources.rearShield : resources.frontShield
  if front { resources.frontShield = shield } else { resources.rearShield = shield }
  let now = game.commander.flightSimulation.physicalTime
  var reserve = try #require(
    ElectricalReserve(
      capacity: resources.energyCapacity, recharge: resources.electricalRecharge, at: now))
  let damaged = reserve.drain(resources.energyCapacity - remaining, at: now)
  try #require(damaged && reserve.remaining > 0 && reserve.disabledAt == nil)
  resources.electrical = reserve
  game.bodies[index].physical?.npc?.resources = resources
  try beforeRelease?(&game)
  let audioCount = game.dischargeAudio.events.count
  game.advanceEMPCharge(triggerHeld: true)
  let actual = try #require(game.bodies.first { $0.id == id })
  let drained = try #require(actual.physical?.npc?.resources)
  #expect(game.commander.savedEMPCharge?.phase == .released)
  #expect(game.dischargeAudio.events.count == audioCount + 1)
  #expect((front ? drained.frontShield : drained.rearShield) == 0)
  #expect((front ? drained.rearShield : drained.frontShield) == opposite)
  #expect(drained.electrical?.remaining == 0 && drained.electrical?.disabledAt == now)
  #expect(
    actual.energy == original.energy && actual.physical?.identity == original.physical?.identity)
  try #require(actual.physical?.empSource != nil && game.isEMPDisabled(actual))
  return true
}

/// Drive saved random ejection times through the production admission boundary.
/// Used only by custody/persistence unit scenes; native flight must use actual ticks.
func ejectScheduledEMPCrewBoundary(_ game: inout Game, source: ActorIdentity) throws {
  let record = try #require(game.commander.savedEMPState?.records[source])
  let episode = try #require(record.disableEpisodes.last)
  try #require(!episode.legacyTiming && !episode.ejections.isEmpty)
  let times = episode.ejections.map { episode.incident.physicalTime + $0.delay }.sorted()
  try #require(times.allSatisfy { $0 < episode.deadline })
  for time in times {
    // Real elapsed physics lets an admitted pod clear the next person's unchanged aperture.
    let target = time + 1e-6
    while game.commander.flightSimulation.physicalTime < target {
      let now = game.commander.flightSimulation.physicalTime
      game.tick(delta: min(0.1, target - now))
      try #require(!game.docked && game.screen != .gameOver)
      try #require(game.commander.flightSimulation.physicalTime > now)
    }
    game.advanceEMPActors()
  }
  let after = try #require(game.commander.savedEMPState?.records[source])
  try #require(after.crewAboard == 0 && after.pods.count == record.crewTotal)
  #expect(Set(after.pods.compactMap { $0.body.physical?.empCrewPod }).count == record.crewTotal)
}

/// Fit a real top normal energy component without enabling other secret-mode policies.
func fitEliteEMPTestEnergy(_ game: inout Game) throws {
  try game.commander.grantEquipment(Equipment.eliteEnergyUnit, at: .energy, provenance: .xyzzy)
  #expect(
    game.commander.fittedComponent(at: .energy)?.grade
      == EquipmentModuleTemplates.energy.grades[3].identity)
  #expect(try EMPPulseProfile.resolve(for: game.commander).power == 80)
}

/// Native inputs, live target resources and the original 800-frame aiming budget.
/// Charge, cooldown, reacquisition and every pulse share that budget; no actor or clock is moved.
@discardableResult
func disableNativeEMPActor(_ actor: ActorIdentity, game: inout Game) throws -> Int {
  game.selectFlightTool(.empPirateBlaster)
  for frame in 0..<800 {
    let body = try #require(game.bodies.first { $0.physical?.identity == actor })
    if game.isEMPDisabled(body) { return 800 - frame }
    var controls = Controls()
    controls.yaw = max(
      -1,
      min(
        1,
        atan2(body.position.x, body.position.z)
          / max(0.001, game.commander.performance.yaw * 0.1)))
    controls.pitch = max(
      -1,
      min(
        1,
        atan2(body.position.y, hypot(body.position.x, body.position.z))
          / max(0.001, game.commander.performance.pitch * 0.1)))
    let range = try EMPPulseProfile.resolve(for: game.commander).range
    let contact = try game.nearestMissionCollision(
      from: .init(0, 0, 0), direction: .init(0, 0, 1), range: range,
      radius: 0, includePlayer: false)
    let ready = game.commander.savedEMPCharge == nil && game.fireCooldown <= 0
    controls.fire =
      game.commander.savedEMPCharge?.phase == .charging
      || (ready && contact?.hit.target == .body(body.id))
    game.tick(delta: 0.1, controls: controls)
    try #require(game.screen != .gameOver && !game.docked)
  }
  let body = try #require(game.bodies.first { $0.physical?.identity == actor })
  try #require(
    game.isEMPDisabled(body),
    "Actual EMP flight did not reach electrical zero within the original frame budget")
  return 0
}

func nativeEMPHulls(_ game: Game, source: ActorIdentity) -> [SpaceBody] {
  let binding = game.commander.savedEMPState?.records[source]?.hull.binding
  return game.bodies.filter { body in
    guard let physical = body.physical, physical.empCrewPod == nil else { return false }
    return physical.empSource == source || physical.identity == binding
      || game.commander.npcPersistence.logicalIdentity(for: physical.identity) == source
  }
}

func expectOriginalEMPCrewConserved(_ record: EMPHullRecord) {
  let escaped = record.pods.compactMap { $0.body.physical?.empCrewPod?.ordinal }
  let held = record.crewCaptures.flatMap(\.ordinals)
  let dead = record.deceasedOrdinals
  let all = record.aboardOrdinals + escaped + held + dead
  #expect(all.count == record.crewTotal && Set(all) == Set(0..<record.crewTotal))
  #expect(
    record.crewAboard + record.pods.count + record.capturedCrewCount + record.lostCrewCount
      == record.crewTotal)
  #expect(record.valid)
}
