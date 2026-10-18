import Foundation
import Testing

@testable import EliteCore

struct NativeStationAutoDockTests {
  @Test(arguments: NativeStationGeometry.Kind.allCases)
  func actualRSelectionFliesMisalignedCraftFromBeyondApproachIntoTheSelectedStation(
    kind: NativeStationGeometry.Kind
  ) async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try nativeAutoDockStart(kind)
    try await verifyActualNativeAutoDock(&game, kind: kind, storage: storage)
  }
}

private func nativeAutoDockStart(_ kind: NativeStationGeometry.Kind) throws -> Game {
  var game = try NativeStationTestFixture.launched()
  let before = game.commander
  let limits = game.workLimits
  try game.commander.grantEquipment(
    TargetingTier.docking.equipmentName, at: .targetingCore, provenance: .legacyUnknown)
  try #require(game.commander.hasAutomaticDocking)
  #expect(
    game.commander.fittedEquipment(at: .targetingCore)?.node.key
      == TargetingTier.docking.equipmentName)
  #expect(game.workLimits == limits && game.commander.shipID == before.shipID)
  #expect(game.commander.credits == before.credits && game.commander.cargo == before.cargo)
  #expect(game.commander.equipmentPurchaseHistory == before.equipmentPurchaseHistory)
  let body = try #require(
    game.bodies.first { $0.nativeStationIdentity?.definition == kind.sourceDefinition })
  let identity = try #require(body.nativeStationIdentity)
  let saved = try #require(game.commander.nativeStations?.pose(for: identity))
  let orientation = try #require(
    saved.orientation(at: game.commander.flightSimulation.physicalTime))
  let source = try #require(NativeStationSource.binding(for: identity))
  let port = source.geometry.docking
  var local = Basis3()
  local.y = port.up
  local.z = port.outward * -1
  local.x = local.y.cross(local.z)
  let right = local.x
  local.rotate(pitch: 0.25, roll: 0.6, yaw: 0.4)
  var pose = ShipPose()
  pose.position =
    saved.position
    + orientation.apply(
      port.center + port.outward * (body.stationApproachDistance + 1800)
        + right * 350 + port.up * 150)
  pose.orientation = local.transformed(by: orientation)
  // Only the initial fixture is reframed; every subsequent pose comes from native movement.
  NativeStationTestFixture.reframe(&game, to: pose)
  game.speed = 0
  let selected = try #require(game.bodies.first { $0.nativeStationIdentity == identity })
  try #require(selected.entrancePosition.length > selected.stationApproachDistance + 1000)
  try #require(
    selected.entranceNormal.z > -0.98 || selected.entranceUp.y < 0.98)
  let radius = game.commander.playerMesh.vertices.map(\.length).max() ?? .infinity
  for other in game.bodies {
    let otherRadius = game.gameplayMesh(for: other).vertices.map(\.length).max() ?? .infinity
    try #require(other.position.length > radius + otherRadius + 8)
  }
  let anchors = try #require(game.commander.flightSimulation.anchors)
  for celestial in [anchors.planet, anchors.sun] {
    try #require((pose.position - celestial.position).length > radius + celestial.radius + 8)
  }
  try #require(game.commander.valid && !game.docked && !game.paused)
  return game
}

private func verifyActualNativeAutoDock(
  _ game: inout Game, kind: NativeStationGeometry.Kind, storage: NativeStationTestStorage
) async throws {
  let station = try #require(
    game.bodies.first { $0.nativeStationIdentity?.definition == kind.sourceDefinition })
  let identity = try #require(station.nativeStationIdentity)
  let actor = try #require(station.physical?.identity)
  let main = try #require(game.bodies.first { $0.id == 0 })
  let mainActor = try #require(main.physical?.identity)
  try #require(main.nativeStationIdentity == nil && mainActor.entity == 1)
  let initialRange = station.entrancePosition.length
  let initialRotation = station.rotation
  let source = try #require(NativeStationSource.binding(for: identity))
  let maximumSpeed = game.workLimits.speed
  let alignmentSpeed = min(144, maximumSpeed)
  let maximumAcceleration = min(240, game.workLimits.acceleration)
  let property = game.commander
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  try await runtime.save(to: storage.url)
  let initialFile = try Data(contentsOf: storage.url)
  // Tab chooses the real live target through the ordinary selection cycle.
  for _ in 0...game.bodies.count {
    await runtime.key("tab")
    game = await runtime.snapshot()
    if game.autoPilot.targetActor == actor { break }
  }
  try #require(game.autoPilot.targetID == station.id && game.autoPilot.targetActor == actor)
  try #require(game.autoTargetBody?.nativeStationIdentity == identity && game.dockingComputer)
  await runtime.setControls(Controls())
  var phases = Set<String>()
  var sawApproach = false
  var sawAlignment = false
  var sawAlignedFinal = false
  var sawRollCorrection = false
  var sawSourceRotation = false
  var retainedMainActor = true
  var retainedSelectedActor = true
  var healthy = true
  var maximumStep = 0.0
  var observedMaximumSpeed = 0.0
  var travelled = 0.0
  let delta = 0.02
  // The same bounded full-approach budget used by the native station guidance tests.
  for _ in 0..<9000 where !game.docked && healthy {
    let before = game.commander.flightSimulation.pose.position
    let beforeVelocity = game.flightWorldVelocity
    let beforeApproachSpeed = game.autoPilot.velocity.length
    game = await runtime.advance(delta: delta)
    let step = (game.commander.flightSimulation.pose.position - before).length
    travelled += step
    maximumStep = max(maximumStep, step)
    observedMaximumSpeed = max(observedMaximumSpeed, game.autoPilot.velocity.length)
    healthy = !game.paused && game.screen != .gameOver && game.energy > 0
    if game.docked { break }
    #expect(
      (game.flightWorldVelocity - beforeVelocity).length <= maximumAcceleration * delta + 1e-6)
    if game.autoPilot.status != "APPROACHING" {
      // Alignment/final entry keep the reference ceiling; inherited momentum brakes gradually.
      #expect(game.autoPilot.velocity.length <= max(alignmentSpeed, beforeApproachSpeed) + 1e-6)
    }
    phases.insert(game.autoPilot.status)
    sawApproach = sawApproach || game.autoPilot.status == "APPROACHING"
    sawAlignment =
      sawAlignment || game.autoPilot.status == "ALIGNING"
      || game.autoPilot.status == "MATCHING SPIN"
    sawRollCorrection = sawRollCorrection || abs(game.roll) > 1e-4
    if let current = game.autoTargetBody {
      retainedSelectedActor =
        retainedSelectedActor && current.nativeStationIdentity == identity
        && current.physical?.identity == actor
      sawSourceRotation = sawSourceRotation || abs(current.rotation - initialRotation) > 1e-4
      sawAlignedFinal =
        sawAlignedFinal
        || (game.autoPilot.finalApproach && game.autoPilot.facingError < 0.03
          && abs(game.autoPilot.phaseError) < 0.08 && game.autoPilot.rateError < 0.06
          && abs(game.roll + source.rotationRate * current.orientation.z.z) < 0.1)
    } else {
      retainedSelectedActor = false
    }
    retainedMainActor =
      retainedMainActor
      && game.bodies.contains {
        $0.id == 0 && $0.hull == .station && $0.nativeStationIdentity == nil
          && $0.physical?.identity == mainActor
      }
  }
  #expect(
    game.docked && !game.dockedAtMainStation && healthy,
    Comment(
      rawValue: "\(kind): phases=\(phases.sorted()), status=\(game.autoPilot.status), "
        + "goal=\(game.autoPilot.positionError), facing=\(game.autoPilot.facingError), "
        + "phase=\(game.autoPilot.phaseError), rate=\(game.autoPilot.rateError)"))
  #expect(sawApproach && sawAlignment && sawAlignedFinal && sawRollCorrection)
  #expect(retainedSelectedActor && retainedMainActor)
  #expect(maximumStep <= maximumSpeed * delta + 1e-6)
  #expect(observedMaximumSpeed <= maximumSpeed + 1e-6)
  #expect(travelled > initialRange - source.geometry.docking.tunnelDepth)
  #expect(sawSourceRotation == (source.rotationRate != 0))
  let receipt = try #require(game.commander.nativeStations?.ledger.currentDock)
  #expect(receipt.station == identity)
  #expect(receipt.dockingBinding == .init(actor: actor, bodyID: station.id))
  #expect(receipt.commanderOwner == property.equipmentOwnerID && receipt.sequence == 1)
  #expect(game.commander.nativeStations?.currentMainDock == nil)
  #expect(game.nativeStationDockEvidenceIsCurrent)
  let board = try #require(await runtime.nativeStationBoardContext())
  #expect(board.service.receipt == receipt && game.acceptsNativeStationBoardContext(board))
  #expect(game.commander.credits == property.credits && game.commander.cargo == property.cargo)
  #expect(game.commander.equipmentInventory == property.equipmentInventory)
  #expect(game.commander.equipmentPurchaseHistory == property.equipmentPurchaseHistory)
  #expect(game.commander.accommodation == property.accommodation)
  let (disk, _) = try ScriptSaveStore.read(Data(contentsOf: storage.url), from: storage.url)
  #expect(disk == game.commander && disk.nativeStations?.ledger.currentDock == receipt)
  #expect(try Data(contentsOf: storage.url) != initialFile)
}
