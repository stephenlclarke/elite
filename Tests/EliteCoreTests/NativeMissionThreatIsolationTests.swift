import Foundation
import Testing

@testable import EliteCore

private func actualMissileThreatBytes(_ ledger: CrimeLedger) throws -> Data {
  let encoded = try JSONEncoder().encode(ledger)
  let decoded = try JSONSerialization.jsonObject(with: encoded)
  let object = try #require(decoded as? [String: Any])
  let missiles = try #require(object["missiles"] as? [[String: Any]])
  try #require(missiles.count == 1)
  return try JSONSerialization.data(withJSONObject: missiles, options: [.sortedKeys])
}

struct NativeMissionThreatIsolationTests {
  @Test func interceptingArchivedPlasmaCannotFinishAnUnrelatedCurrentMissileWithTheSameEmissionID()
    throws
  {
    var (historical, _, index) = try actualMissionBridgeGame()
    historical.ensurePhysicalActors()
    historical.celestials = []
    historical.bodies[index].position = .init(0, -25, 3000)
    historical.bodies[index].orientation.x = .init(-1, 0, 0)
    historical.bodies[index].orientation.y = .init(0, 1, 0)
    historical.bodies[index].orientation.z = .init(0, 0, -1)
    historical.bodies[index].rotation = 0
    historical.bodies[index].scriptNPC?.intent = .init(
      request: "archive-collision", mode: .attack, target: nil, player: true,
      offset: .init(0, 0, 0), speed: 0, tolerance: 1)
    historical.bodies[index].scriptNPC?.velocity = .init(0, 0, 0)
    let sourceID = historical.bodies[index].id
    let component = try #require(historical.bodies[index].scriptNPC?.components["turret"])
    // Two genuine allocator timelines: the retained projectile is historical data, while the
    // current native missile uses its own real allocator and targeted-launch ledger entry.
    var current = historical
    _ = try historical.fireMissionNativeWeapon(
      bodyID: sourceID, weaponID: "plasma", componentID: component.identity)
    let emitted = try #require(historical.bodies.first { $0.scriptShot != nil })
    let shotID = try #require(emitted.scriptShot?.identity)
    _ = try historical.stepMissionNativeProjectile(projectileID: shotID, delta: 1)
    historical.persistScriptActors()
    var retained = try #require(historical.commander.scriptState.projectiles[shotID])
    let archive = try #require(retained.body.scriptShot?.nativeAttribution)
    retained.presence = .unloaded
    for index in current.bodies.indices where current.bodies[index].scriptNPC != nil {
      current.bodies[index].scriptNPC?.intent = nil
      current.bodies[index].position.x += 3000
    }
    current.weaponsTargetID = sourceID
    current.missileArmed = true
    let fired = current.fireMissile()
    try #require(fired)
    let missile = try #require(current.bodies.first { $0.physical?.ordnance != nil })
    let ordnance = try #require(missile.physical?.ordnance)
    try #require(ordnance.origin.emissionID == archive.origin.emissionID)
    current.commander.flightSimulation.advancePhysicalTime(0.1)
    current.advanceGameplayOrdnance(allowEnemyECM: false)
    try #require(current.bodies.first { $0.id == missile.id }?.energy ?? 0 > 0)
    current.commander.scriptState.projectiles[shotID] = retained
    let admission = try current.admitRetainedMissionProjectile(shotID)
    current.commander.scriptState.projectiles[shotID]?.body.id = admission.bodyID
    current.commander.scriptState.projectiles[shotID]?.presence = .present
    let contact = try current.nearestMissionCollision(
      from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 6000,
      radius: 0, includePlayer: false)
    try #require(contact?.hit.target == .body(admission.bodyID))
    let threats = try actualMissileThreatBytes(current.commander.crimeLedger)
    current.screen = .front
    current.fireLaser()
    #expect(current.bodies.first { $0.id == admission.bodyID }?.energy == 0)
    #expect(current.bodies.first { $0.id == missile.id }?.energy ?? 0 > 0)
    #expect(try actualMissileThreatBytes(current.commander.crimeLedger) == threats)
  }

  @Test func actualNativeMissileInterceptionStillFinishesItsOwnCurrentThreat() throws {
    var (game, _, index) = try actualMissionBridgeGame()
    game.bodies[index].position = .init(2000, 0, 3000)
    game.celestials = []
    game.weaponsTargetID = game.bodies[index].id
    game.missileArmed = true
    let launched = game.fireMissile()
    try #require(launched)
    let missile = try #require(game.bodies.first { $0.physical?.ordnance != nil })
    _ = try actualMissileThreatBytes(game.commander.crimeLedger)
    let contact = try game.nearestMissionCollision(
      from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 6000,
      radius: 0, includePlayer: false)
    try #require(contact?.hit.target == .body(missile.id))
    game.screen = .front
    game.fireLaser()
    #expect(game.bodies.first { $0.id == missile.id }?.energy == 0)
    let bytes = try JSONEncoder().encode(game.commander.crimeLedger)
    let decoded = try JSONSerialization.jsonObject(with: bytes)
    let object = try #require(decoded as? [String: Any])
    let threats = try #require(object["missiles"] as? [[String: Any]])
    #expect(threats.isEmpty)
  }

}
