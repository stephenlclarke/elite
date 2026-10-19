import Foundation
import Testing

@testable import EliteCore

private func nativeStationClearanceScene() throws -> (Game, SpaceBody) {
  var game = Game(executive: false)
  game.screen = .status
  try game.commander.prepareEquipment(legacy: false)
  game.launch()
  try #require(!game.docked && game.commander.valid)
  let station = try #require(
    game.bodies.first {
      $0.nativeStationIdentity?.definition == NativeStationGeometry.Kind.waystation.sourceDefinition
    })
  try #require(game.nativeStationBodyIsCurrent(station))
  return (game, station)
}

@Test(arguments: ["profiled-skirmish", "scripted-patrol"])
func originalMissionCoordinatesAdmitBesideActualNativeWaystation(example: String) throws {
  let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/mission-packs/" + example)
  let pack = try ScriptPackLibrary.read(directory)
  var game = Game(executive: false)
  game.screen = .status
  try game.commander.prepareEquipment(legacy: false)
  game.scriptPacks = [pack]
  let id = try game.acceptScriptMission(pack)
  game.launch()
  try #require(!game.docked)
  let station = try #require(game.bodies.first { $0.nativeStationIdentity != nil })
  let anchor = try #require(game.scriptAnchor)
  let definition = try #require(pack.manifest.encounters?.first)
  let lead = try #require(definition.actors.first { $0.id == "lead" })
  try #require(lead.x == 0 && lead.y == 0 && lead.z == 3000)
  let before = game.bodies
  game.emitScriptEvent("station.undocked")
  game.drainScriptEvents()
  let encounter = try #require(
    game.commander.scriptState.instances[id]?.ownedEncounters[definition.id])
  try #require(encounter.admitted && encounter.actors.count == 2)
  let sources = try game.retainedMissionActorAdmissionSources()
  let source = try #require(sources.first { $0.instanceID == id })
  let template = try #require(source.actors.first { $0.alias == "lead" })
  let center = game.commander.flightSimulation.pose.systemPoint(
    anchor.position + anchor.orientation.apply(.init(lead.x, lead.y, lead.z)))
  let identity = try #require(station.nativeStationIdentity)
  let geometry = try #require(NativeStationSource.binding(for: identity)?.geometry)
  let radius = try #require(geometry.mesh.vertices.map(\.length).max())
  // Prove the real example exercises the conservative sphere-overlap fallback.
  #expect((center - game.modelPose(of: station).position).length < radius + template.radius + 64)
  #expect(
    game.missionActorClearsNativeStation(center: center, radius: template.radius, body: station))
  #expect(game.bodies.filter { $0.missionInstanceID == id }.count == 2)
  for body in before { #expect(game.bodies.contains { $0 == body }) }
  #expect(game.commander.valid)
}

// The existing accepted basis/current-pose tolerances are part of this regression.
// A transpose is not an inverse for this genuine tolerated scale.
@inline(never)
private func verifyToleratedStationBasisClearance(
  _ original: borrowing Game, station: SpaceBody, radius: Double
) throws {
  var game = copy original
  var scaled = station
  scaled.orientation.z = scaled.orientation.z * 1.000001
  let index = try #require(game.bodies.firstIndex { $0.id == scaled.id })
  game.bodies[index] = scaled
  let pose = game.modelPose(of: scaled)
  let world = try #require(game.commander.nativeStations)
  try #require(pose.orientation.validRotation && game.nativeStationBodyIsCurrent(scaled))
  try #require(world.bodyRigidPoseIsConsistent(scaled, flight: game.commander.flightSimulation))
  let identity = try #require(scaled.nativeStationIdentity)
  let geometry = try #require(NativeStationSource.binding(for: identity)?.geometry)
  let vertex = try #require(geometry.mesh.vertices.first { $0.z == geometry.bounds.maximum.z })
  let surface = pose.systemPoint(vertex)
  let center = surface + .init(0, 0, radius + 63.9999)
  #expect((center - surface).length - radius < 64)
  #expect(!game.missionActorClearsNativeStation(center: center, radius: radius, body: scaled))
}

@Test func actualRigidStationBoundsRetainClearanceAndRejectInteriorAtCurrentSpin() throws {
  var (game, station) = try nativeStationClearanceScene()
  let radius = try #require(Mesh.hull(.sidewinder).vertices.map(\.length).max())
  try verifyToleratedStationBasisClearance(game, station: station, radius: radius)
  for elapsed in [0.0, 0.1] {
    if elapsed > 0 {
      game.tick(delta: elapsed)
      station = try #require(game.bodies.first { $0.id == station.id })
    }
    let identity = try #require(station.nativeStationIdentity)
    let geometry = try #require(NativeStationSource.binding(for: identity)?.geometry)
    let pose = game.modelPose(of: station)
    let minimum = geometry.bounds.minimum
    let middle = (minimum + geometry.bounds.maximum) * 0.5
    let vertex = try #require(geometry.mesh.vertices.first)
    #expect(
      !game.missionActorClearsNativeStation(
        center: pose.systemPoint(vertex), radius: radius, body: station))
    #expect(
      !game.missionActorClearsNativeStation(
        center: pose.systemPoint(middle), radius: radius, body: station))
    for clearance in [0.0, 63, 64] {
      let point = pose.systemPoint(.init(0, 0, minimum.z - radius - clearance))
      #expect(!game.missionActorClearsNativeStation(center: point, radius: radius, body: station))
    }
    let clear = pose.systemPoint(.init(0, 0, minimum.z - radius - 65))
    #expect(game.missionActorClearsNativeStation(center: clear, radius: radius, body: station))
    let far = pose.systemPoint(.init(0, 0, minimum.z - radius - 2000))
    #expect(game.missionActorClearsNativeStation(center: far, radius: radius, body: station))
  }
  #expect(station.rotation != 0)
}

@Test(arguments: [
  "missing-identity", "foreign-source", "missing-world", "stale-condition", "stale-pose",
  "invalid-basis", "missing-physical",
])
func nativeStationClearanceCannotUseStaleOrMissingSourceEvenFarAway(field: String) throws {
  var (game, station) = try nativeStationClearanceScene()
  let center = game.modelPose(of: station).position + .init(0, 0, 10000)
  try #require(game.missionActorClearsNativeStation(center: center, radius: 80, body: station))
  switch field {
  case "missing-identity": station.nativeStationIdentity = nil
  case "foreign-source":
    let original = try #require(station.nativeStationIdentity)
    station.nativeStationIdentity = .init(
      world: original.world, system: original.system, definition: original.definition,
      version: original.version, key: "absent-source")
  case "missing-world": game.commander.nativeStations = nil
  case "stale-condition": station.energy -= 1
  case "stale-pose": station.position = station.position + .init(1, 0, 0)
  case "invalid-basis": station.orientation.x = .init(0, 0, 0)
  default: station.physical = nil
  }
  #expect(!game.missionActorClearsNativeStation(center: center, radius: 80, body: station))
}
