import Foundation
import Testing

@testable import EliteCore

private func workRuntimeGame(module: WorkTargetSpecialty = .salvage, scoops: Bool = true) throws
  -> Game
{
  var game = Game(executive: false)
  try game.commander.prepareEquipment(legacy: false)
  try game.commander.grantEquipment(
    "Targeting: Military", at: .targetingCore, provenance: .grant("work fixture"))
  try game.commander.grantEquipment(
    "Targeting: " + (module == .mining ? "Mining" : "Salvage") + " Module",
    at: module == .mining ? .targetingMining : .targetingSalvage, provenance: .grant("work fixture")
  )
  if scoops {
    try game.commander.grantEquipment(
      "Fuel Scoops", at: .utility(.fuelScoops), provenance: .grant("work fixture"))
  }
  game.launch()
  game.speed = 0
  game.bodies = []
  game.celestials = []
  game.miningFields = []
  game.salvageSites = []
  game.commander.npcPersistence = .init()
  return game
}

private func addWorkCargo(
  _ game: inout Game, position: Vector3, velocity: Vector3 = .init(0, 0, 0),
  oversized: Bool = false, preserveBodies: Bool = false
) throws -> ActorIdentity {
  // Issue a real structural lot, then admit and acknowledge it through the runtime allocator.
  let selectedProfile =
    oversized
    ? SalvageCatalogue.all.first {
      $0.sections.contains { $0.technologyDefinitionIDs.contains("spare-escape-pod") }
    }
    : SalvageCatalogue.profile(catalogueShipID: "SH005")
  let profile = try #require(selectedProfile)
  let section = try #require(
    profile.sections.first {
      oversized ? $0.technologyDefinitionIDs.contains("spare-escape-pod") : $0.structural
    })
  let incident = game.commander.flightSimulation.allocateIncident()
  let lineage = try #require(incident)
  let wreck = WreckIdentity(system: game.systemIdentity, site: 88, lineage: lineage)
  for _ in 0..<320 {
    let allocated = game.commander.flightSimulation.allocateIncident()
    let operation = try #require(allocated)
    _ = game.commander.salvageLedger.advance(
      wreck: wreck, section: section,
      pose: .init(position: .init(0, 0, 3000)), velocity: velocity,
      angularVelocity: .init(0, 0, 0), tool: .cutter, elapsed: 1, operation: operation,
      conditions: .init(
        toolInstalled: true, inRange: true, aligned: true,
        lineOfSight: true, resourcesAvailable: true, ownershipAuthorized: true))
    if game.commander.salvageLedger.pendingLots.contains(where: {
      $0.identity.section.wreck == wreck
    }) {
      break
    }
  }
  let lot = try #require(
    game.commander.salvageLedger.pendingLots.first {
      guard $0.identity.section.wreck == wreck else { return false }
      if !oversized { return true }
      if case .technology(let id, _, _) = $0.content { return id == "spare-escape-pod" }
      return false
    })
  for other in game.commander.salvageLedger.pendingLots where other.identity != lot.identity {
    _ = game.commander.salvageLedger.destroy(lot: other.identity, protection: .init())
  }
  if !preserveBodies {
    for old in game.bodies {
      if let actor = old.physical?.identity { game.commander.salvageLedger.cull(actor: actor) }
    }
    game.bodies = []
    game.nextBodyID = 88
  } else {
    game.nextBodyID = (game.bodies.map(\.id).max() ?? 87) + 1
  }
  game.admitPendingSalvage()
  let index = try #require(
    game.bodies.firstIndex { $0.physical?.payload == .salvage(lot.identity) })
  let actor = try #require(game.bodies[index].physical?.identity)
  #expect(game.commander.salvageLedger.boundActor(for: lot.identity) == actor)
  game.bodies[index].position = position
  game.bodies[index].rotationRate = 0
  game.bodies[index].physical?.canonicalSpin = true
  game.commander.salvageLedger.updateLot(
    lot.identity,
    position: game.commander.flightSimulation.pose.systemPoint(position), velocity: velocity)
  #expect(
    oversized || (lot.halfExtents.x <= 16 && lot.halfExtents.y <= 16 && lot.halfExtents.z <= 16))
  return actor
}

private func engageWorkCargo(_ game: inout Game) {
  game.workTargetFilter = .salvage
  game.key("r")
}

private func actualLargeWorkHold() throws -> Game {
  let base = try workRuntimeGame(scoops: false)
  for profile in SalvageCatalogue.all {
    for section in profile.sections {
      var game = base
      try game.commander.grantEquipment(
        "Salvage Cutter", at: .utility(.salvageCutter), provenance: .grant("hold fixture"))
      let allocated = game.commander.flightSimulation.allocateActor()
      let actor = try #require(allocated)
      let wreck = WreckIdentity(system: game.systemIdentity, site: 89, lineage: 99)
      let normal = section.normal.unit
      let z = normal * -1
      let up = abs(z.y) < 0.8 ? Vector3(0, 1, 0) : .init(1, 0, 0)
      var frame = Basis3()
      frame.z = z
      frame.x = up.cross(z).unit
      frame.y = z.cross(frame.x).unit
      let orientation = frame.transposed
      var body = SpaceBody(
        id: 89, hull: .cobra,
        position: Vector3(0, 0, 400) - orientation.apply(section.localPosition))
      body.orientation = orientation
      body.rotationRate = 0
      body.physical = .init(
        identity: actor, population: .wreck,
        catalogueShipID: profile.catalogueShipID, canonicalSpin: true,
        salvage: .init(
          category: .wreck, ownership: .abandoned, claimant: nil,
          wreck: wreck, section: nil, lot: nil, bounds: profile.bounds,
          workSurfaces: profile.surfaces(wreck: wreck)))
      game.bodies = [body]
      game.workTargetFilter = .salvage
      game.key("r")
      guard let state = game.workGuidance else { continue }
      let model = game.modelPose(of: game.bodies[0])
      let outward = model.orientation.apply(state.surface.normal).unit
      var desired = Basis3()
      desired.z = outward * -1
      var desiredUp = model.orientation.y - desired.z * model.orientation.y.dot(desired.z)
      if desiredUp.length < 1e-6 {
        desiredUp = model.orientation.x - desired.z * model.orientation.x.dot(desired.z)
      }
      desired.y = desiredUp.unit
      desired.x = desired.y.cross(desired.z).unit
      let radius = game.commander.playerMesh.vertices.map(\.length).max() ?? 0
      let old = game.commander.flightSimulation.pose
      let next = ShipPose(
        position: model.systemPoint(state.surface.point)
          + outward * (max(120, 2 * radius) + radius + 1), orientation: desired)
      game.bodies[0].position = next.shipPoint(old.systemPoint(game.bodies[0].position))
      game.bodies[0].orientation = next.orientation.transposed.composed(
        with: old.orientation.composed(with: game.bodies[0].orientation))
      game.commander.flightSimulation.pose = next
      game.advanceWorkGuidance(delta: 0.02)
      if game.approvedWorkMotion != nil { return game }
    }
  }
  throw SaveError.invalidCommander
}

private func genuineNativeDebris() throws -> (Game, TypedCargoPayload, ActorIdentity) {
  var game = try workRuntimeGame()
  var source = SpaceBody(id: 44, hull: .cobra, position: .init(0, 0, 1500))
  source.energy = 1
  game.bodies = [source]
  game.ensurePhysicalActors()
  game.bodies[0].physical?.npc?.ordinaryCargo = [.init(commodity: .food, quantity: 1)]
  let sourceActor = try #require(game.bodies[0].physical?.identity)
  let player = try #require(game.commander.flightSimulation.player)
  let allocated = game.makeAttackOrigin(owner: player)
  let origin = try #require(allocated)
  _ = game.applyCombatHit(
    .init(target: .body(44), distance: 1500, point: source.position),
    origin: origin, kind: .laser, damage: 1000, laser: .pulse)
  game.commander.crimeLedger.finishEmission(origin.emissionID)
  game.resolveDestroyed()
  game.admitPendingCargo()
  let payload = try #require(game.commander.cargoDebrisLedger.pendingPayloads.first)
  guard case .wreck(let original, _) = payload.identity else { throw SaveError.invalidCommander }
  #expect(original == sourceActor)
  let index = try #require(game.bodies.firstIndex { $0.physical?.payload == payload.identity })
  let actor = try #require(game.bodies[index].physical?.identity)
  return (game, payload, actor)
}

struct FlightWorkGuidanceRuntimeTests {
  @Test func filterKeyUsesActualFittedModulesAndKeepsOriginalShipDefault() throws {
    var game = try workRuntimeGame()
    _ = try addWorkCargo(&game, position: .init(0, -45, 500))
    #expect(game.workTargetFilter == .ships)
    game.key("r")
    #expect(game.autoPilot.targetID == nil)
    game.key("f")
    #expect(game.workTargetFilter == .mining)
    game.key("r")
    #expect(game.autoPilot.targetID == nil)
    game.key("f")
    #expect(game.workTargetFilter == .salvage)
    game.key("r")
    #expect(game.workGuidance?.mode == .autoScoop(.salvage))
    game.key("f")
    #expect(game.workTargetFilter == .all && game.workGuidance == nil)
    game.key("f")
    #expect(game.workTargetFilter == .ships)
    let help = PlayerHelp.pages(for: game).flatMap(\.rows).joined(separator: " ")
    #expect(help.contains("F - SHIPS / MINING / SALVAGE / ALL"))
  }

  @Test func approvedActualMeshEndpointIsAppliedOnceWithoutEndVelocityEuler() throws {
    var game = try workRuntimeGame()
    let actor = try addWorkCargo(&game, position: .init(0, -45, 500))
    engageWorkCargo(&game)
    #expect(game.workGuidance?.parent == actor)
    let start = game.commander.flightSimulation.pose
    game.advanceWorkGuidance(delta: 0.1)
    let motion = try #require(game.approvedWorkMotion)
    let beforeCargo = game.modelPose(of: game.bodies[0])
    #expect(motion.start == start && motion.acceleration.length > 0)
    let moved = game.moveWorkFrame(delta: 0.1)
    #expect(moved)
    #expect(game.commander.flightSimulation.pose == motion.end)
    #expect(game.approvedWorkMotion == nil && game.lastAppliedWorkMotion == motion)
    #expect(
      (game.flightWorldVelocity - motion.initialVelocity - motion.acceleration * 0.1).length < 1e-9)
    #expect((game.modelPose(of: game.bodies[0]).position - beforeCargo.position).length < 1e-8)
    let correct = start.position + motion.initialVelocity * 0.1 + motion.acceleration * 0.005
    #expect((motion.end.position - correct).length < 1e-9)
    #expect((motion.end.position - start.position - game.flightWorldVelocity * 0.1).length > 1e-4)
  }

  @Test func realTickCollectsOneCargoAndBrakesAgainstCurrentSceneWithoutGhostPrimary() throws {
    var game = try workRuntimeGame()
    let collectedActor = try addWorkCargo(
      &game, position: .init(0, -45, 55), velocity: .init(0, 0, 10))
    engageWorkCargo(&game)
    game.workGuidance?.velocity = .init(0, 0, 10)
    let before = game.commander.cargoTonnes
    game.tick(delta: 0.02)
    #expect(game.commander.cargoTonnes == before + 1)
    #expect(!game.bodies.contains { $0.id == 88 })
    #expect(game.workGuidance == nil && game.workBraking != nil)
    #expect(game.autoPilot.targetID == nil && game.weaponsTargetID == nil)
    #expect(game.message.hasPrefix("RECOVERED"))
    let velocity = game.flightWorldVelocity
    game.advanceWorkGuidance(delta: 0.02)
    let brake = try #require(game.approvedWorkMotion)
    #expect(brake.initialVelocity == velocity && brake.acceleration.dot(velocity) < 0)
    let snapshot = game.workObstacles(excluding: nil, delta: 0.02)
    let current = try #require(snapshot)
    #expect(!current.contains { $0.identity == collectedActor })
    let moved = game.moveWorkFrame(delta: 0.02)
    #expect(moved)
    #expect(game.flightWorldVelocity.length < velocity.length)
    game.scoopCargo()
    #expect(game.commander.cargoTonnes == before + 1)
  }

  @Test func otherPodStillBlocksPostCaptureBrakingAndReceivesNoThrust() throws {
    var game = try workRuntimeGame()
    _ = try addWorkCargo(&game, position: .init(0, -45, 55))
    engageWorkCargo(&game)
    game.workGuidance?.velocity = .init(0, 0, 25)
    let collected = game.bodies[0]
    game.workTargetCollected(collected)
    game.bodies = []
    let allocated = game.commander.flightSimulation.allocateActor()
    let other = try #require(allocated)
    var obstruction = SpaceBody(id: 89, hull: .cargo, position: .init(0, 0, 0))
    obstruction.rotationRate = 0
    obstruction.physical = .init(identity: other, population: .cargo, canonicalSpin: true)
    game.bodies = [obstruction]
    let energy = game.energy
    game.advanceWorkGuidance(delta: 0.1)
    #expect(game.approvedWorkMotion == nil && game.energy == energy)
    let snapshot = game.workObstacles(excluding: nil, delta: 0.1)
    let obstacles = try #require(snapshot)
    #expect(obstacles.count == 1 && obstacles[0].identity == other)
    _ = game.moveWorkFrame(delta: 0.1)
    #expect(game.flightWorldVelocity == .init(0, 0, 25))
  }

  @Test func actualApertureOverspeedRefusesCollectionAndKeepsTheTarget() throws {
    var game = try workRuntimeGame()
    _ = try addWorkCargo(&game, position: .init(0, -45, 55))
    engageWorkCargo(&game)
    game.workGuidance?.velocity = .init(0, 0, 100)
    let cargo = game.commander.cargo
    game.scoopCargo()
    #expect(game.commander.cargo == cargo && game.bodies.count == 1)
    #expect(game.workGuidance != nil)
  }

  @Test func manualAndDamageInterruptionsPreserveActualMomentumAndSuppressHeldTool() throws {
    for damage in [false, true] {
      var game = try workRuntimeGame()
      _ = try addWorkCargo(&game, position: .init(0, -45, 500))
      engageWorkCargo(&game)
      let velocity = Vector3(20, -10, 50)
      game.workGuidance?.velocity = velocity
      if damage {
        game.applyDamage(1, front: true)
        #expect(game.workFireSuspended)
      } else {
        game.key("q")
      }
      #expect(game.workGuidance == nil && game.autoPilot.targetID == nil)
      #expect((game.flightWorldVelocity - velocity).length < 1e-9)
      let before = game.commander.flightSimulation.pose.position
      game.tick(delta: 0.02)
      #expect(
        (game.commander.flightSimulation.pose.position - before - velocity * 0.02).length < 1e-8)
      #expect(!game.workFireSuspended)
    }
  }

  @Test func displayIDReuseNeverFollowsANewPhysicalActor() throws {
    var game = try workRuntimeGame()
    let original = try addWorkCargo(&game, position: .init(0, -45, 500))
    engageWorkCargo(&game)
    let replacement = try addWorkCargo(&game, position: .init(0, -45, 500))
    #expect(original != replacement && game.autoTargetBody == nil)
    game.advanceWorkGuidance(delta: 0.02)
    #expect(game.workGuidance == nil && game.approvedWorkMotion == nil)
    #expect(game.message == "WORK TARGET UNAVAILABLE")
  }

  @Test func actualLegacyAIIsPlannedOnceBeforeTheProofAndNotMovedAgain() throws {
    var game = try workRuntimeGame()
    _ = try addWorkCargo(&game, position: .init(0, -45, 1000))
    engageWorkCargo(&game)
    var enemy = SpaceBody(id: 99, hull: .sidewinder, position: .init(3000, 2000, 3000))
    enemy.hostile = true
    game.bodies.append(enemy)
    game.ensurePhysicalActors()
    let before = game.modelPose(of: game.bodies[1]).position
    game.planWorkScene(delta: 0.1)
    let planned = try #require(game.plannedLegacyWorkMotion[99])
    let afterPlanning = game.modelPose(of: game.bodies[1]).position
    #expect((afterPlanning - before - planned.velocity * 0.1).length < 1e-8)
    game.advanceWorkGuidance(delta: 0.1)
    _ = game.moveWorkFrame(delta: 0.1)
    let after = game.modelPose(of: game.bodies[1]).position
    #expect((after - afterPlanning).length < 1e-8)
    #expect(game.workScenePlanned)
  }

  @Test func miningAndSalvageNeverInheritEachOthersFittedModule() throws {
    var game = try workRuntimeGame(module: .mining)
    _ = try addWorkCargo(&game, position: .init(0, -45, 500))
    game.workTargetFilter = .all
    game.key("r")
    #expect(game.workGuidance == nil && game.autoPilot.targetID == nil)
    let context = try #require(game.gameplayContext())
    let candidate = try #require(
      game.workTargetCandidate(for: game.bodies[0], context: context, frontVisible: true))
    #expect(
      WorkTargetSelection.evaluate(
        candidate, system: context.system, visit: context.visit,
        capabilities: game.workTargetCapabilities) == .refused(.missingModule(.salvage)))
    #expect(game.workTargetCapabilities.core == .military)
  }

  @Test func realLargeHullHoldsSelectsItsCutterAndDoesNotRetargetACollectedChild() throws {
    var game = try actualLargeWorkHold()
    let parent = try #require(game.workGuidance?.parent)
    let section = try #require(game.workGuidance?.surface.section)
    for _ in 0..<30 {
      game.advanceWorkGuidance(delta: 0.02)
      _ = game.moveWorkFrame(delta: 0.02)
    }
    #expect(game.workGuidance?.holding == true && game.selectedFlightTool == .salvageCutter)
    let beforeEnergy = game.bodies[0].energy
    game.fireSelectedFlightTool(delta: 0.1)
    #expect(game.commander.salvageLedger.progress(section) == 0.1)
    #expect(game.bodies[0].energy == beforeEnergy)
    try game.commander.grantEquipment(
      "Fuel Scoops", at: .utility(.fuelScoops), provenance: .grant("child fixture"))
    let child = try addWorkCargo(&game, position: .init(0, -45, 55), preserveBodies: true)
    let before = game.commander.cargoTonnes
    game.scoopCargo()
    #expect(game.commander.cargoTonnes == before + 1)
    #expect(!game.bodies.contains { $0.physical?.identity == child })
    #expect(game.workGuidance?.parent == parent && game.autoPilot.targetActor == parent)
    #expect(game.workGuidance?.mode == .hold(.salvage))
  }

  @Test func changedSectionAuthorityCancelsAnOtherwiseIdenticalLargeParent() throws {
    var game = try actualLargeWorkHold()
    let metadata = try #require(game.bodies[0].physical?.salvage)
    game.bodies[0].physical?.salvage = .init(
      category: metadata.category,
      ownership: metadata.ownership, claimant: metadata.claimant, wreck: metadata.wreck,
      section: metadata.section, lot: metadata.lot, bounds: metadata.bounds, workSurfaces: [])
    game.advanceWorkGuidance(delta: 0.02)
    #expect(game.workGuidance == nil && game.approvedWorkMotion == nil)
    #expect(game.message == "WORK TARGET UNAVAILABLE")
  }

  @Test func actualHeldManualSteeringCannotContinueCuttingUntilFireIsReleased() throws {
    var game = try actualLargeWorkHold()
    let section = try #require(game.workGuidance?.surface.section)
    for _ in 0..<30 {
      game.advanceWorkGuidance(delta: 0.02)
      _ = game.moveWorkFrame(delta: 0.02)
    }
    #expect(game.workGuidance?.holding == true && game.selectedFlightTool == .salvageCutter)
    var controls = Controls()
    controls.pitch = 0.001
    controls.fire = true
    let before = game.commander.salvageLedger.progress(section)
    let heat = game.laserHeat
    game.tick(delta: 0.02, controls: controls)
    #expect(game.workGuidance == nil && game.workFireSuspended)
    #expect(game.commander.salvageLedger.progress(section) == before && game.laserHeat <= heat)
    controls.pitch = 0
    game.tick(delta: 0.02, controls: controls)
    #expect(game.workFireSuspended && game.commander.salvageLedger.progress(section) == before)
    controls.fire = false
    game.tick(delta: 0.02, controls: controls)
    #expect(!game.workFireSuspended)
    controls.fire = true
    game.tick(delta: 0.02, controls: controls)
    #expect(game.commander.salvageLedger.progress(section) > before && game.laserHeat > heat)
  }

  @Test func genuineDestroyedNPCDebrisUsesNativeCanisterGeometryAndCollectsOnlyOnce() throws {
    var (game, payload, actor) = try genuineNativeDebris()
    let index = try #require(game.bodies.firstIndex { $0.physical?.identity == actor })
    let native = Mesh.hull(.cargo)
    #expect(game.gameplayMesh(for: game.bodies[index]).vertices == native.vertices)
    game.bodies[index].position = .init(0, -45, 55)
    game.bodies[index].rotationRate = 0
    game.persistCargoPoses()
    engageWorkCargo(&game)
    #expect(game.workGuidance?.parent == actor)
    let largeAxis = try #require(game.collectibleHalfExtents(game.bodies[index]))
    #expect(max(largeAxis.x, max(largeAxis.y, largeAxis.z)) > 16)
    game.workGuidance?.velocity = game.bodies[index].physical?.velocity ?? .init(0, 0, 0)
    let before = game.commander.cargo[0]
    game.scoopCargo()
    #expect(game.commander.cargo[0] == before + 1)
    #expect(game.commander.cargoDebrisLedger.boundActor(for: payload.identity) == nil)
    #expect(!game.bodies.contains { $0.physical?.identity == actor })
    #expect(game.workBraking != nil && game.workGuidance == nil)
    let snapshot = game.workObstacles(excluding: nil, delta: 0.02)
    let obstacles = try #require(snapshot)
    #expect(!obstacles.contains { $0.identity == actor })
    game.scoopCargo()
    #expect(game.commander.cargo[0] == before + 1)
  }

  @Test func unknownNativeCanisterCannotBorrowTheBoundOrdinaryPayloadException() throws {
    var game = try workRuntimeGame()
    game.bodies = [.init(id: 41, hull: .cargo, position: .init(0, -45, 55))]
    game.ensurePhysicalActors()
    let context = try #require(game.gameplayContext())
    #expect(!game.automaticScoopShapeCompatible(game.bodies[0], context: context))
    engageWorkCargo(&game)
    #expect(game.workGuidance == nil)
    #expect(game.message == "ITEM TOO LARGE FOR SCOOPS")
  }

  @Test func genuinelyGeneratedRockHandsItsAcknowledgedOreToAutomaticRecovery() throws {
    var game = try workRuntimeGame(module: .mining)
    try game.commander.grantEquipment(
      "Mining Laser", at: .utility(.miningLaser), provenance: .grant("mining fixture"))
    let anchors = try #require(game.commander.flightSimulation.anchors)
    let field = try #require(MiningFields.generate(anchors: anchors, seed: game.gameplaySeed).first)
    let rock = try #require(field.rocks.first)
    game.miningFields = [.init(position: field.position, rocks: [rock])]
    game.commander.flightSimulation.pose.position = rock.position - .init(0, 0, 500)
    game.activateNearbyMiningFields()
    let original = try #require(game.bodies.first { $0.physical?.rock == rock.identity })
    game.workTargetFilter = .mining
    game.key("r")
    #expect(game.workGuidance?.parent == original.physical?.identity)
    var controls = Controls()
    controls.fire = true
    for _ in 0..<800 {
      game.tick(delta: 0.1, controls: controls)
      if game.commander.miningLedger.isDepleted(rock.identity) { break }
    }
    #expect(game.commander.miningLedger.isDepleted(rock.identity))
    let payload = try #require(game.commander.miningLedger.pendingPayloads.first)
    let body = try #require(game.bodies.first { $0.physical?.payload == payload.identity })
    let actor = try #require(body.physical?.identity)
    #expect(game.commander.miningLedger.boundActor(for: payload.identity) == actor)
    #expect(game.workGuidance?.mode == .autoScoop(.mining))
    #expect(game.workGuidance?.parent == actor)
    let native = Mesh.hull(.cargo)
    #expect(game.gameplayMesh(for: body).vertices == native.vertices)
    let before = game.commander.cargo[payload.amount.commodity.rawValue]
    for _ in 0..<600 {
      game.tick(delta: 0.1)
      if game.commander.miningLedger.boundActor(for: payload.identity) == nil { break }
    }
    #expect(
      game.commander.cargo[payload.amount.commodity.rawValue] == before + payload.amount.quantity)
    #expect(
      !game.commander.miningLedger.pendingPayloads.contains { $0.identity == payload.identity })
    #expect(!game.bodies.contains { $0.physical?.identity == actor })
    let cargo = game.commander.cargo
    game.scoopCargo()
    #expect(game.commander.cargo == cargo)
  }

  @Test func actualOversizedSalvageCannotBorrowOrdinaryCanisterCaptureRules() throws {
    var game = try workRuntimeGame()
    let actor = try addWorkCargo(&game, position: .init(0, -45, 55), oversized: true)
    let lot = try #require(game.commander.salvageLedger.pendingLots.first)
    #expect(lot.halfExtents.z > 16)
    let context = try #require(game.gameplayContext())
    #expect(!game.automaticScoopShapeCompatible(game.bodies[0], context: context))
    engageWorkCargo(&game)
    #expect(game.workGuidance == nil && game.message == "ITEM TOO LARGE FOR SCOOPS")
    let before = game.commander
    game.scoopCargo()
    #expect(game.commander == before && game.bodies.contains { $0.physical?.identity == actor })
    #expect(game.message == "SALVAGE: OVERSIZED")
  }

  @Test func currentBoundCustomScaledCargoCannotBorrowTheNativeCanisterException() throws {
    var (game, payload, actor) = try genuineNativeDebris()
    let context = try #require(game.gameplayContext())
    let index = try #require(game.bodies.firstIndex { $0.physical?.identity == actor })
    #expect(game.automaticScoopShapeCompatible(game.bodies[index], context: context))
    let anchors = try #require(game.commander.flightSimulation.anchors)
    let fields = MiningFields.generate(anchors: anchors, seed: game.gameplaySeed)
    let rock = try #require(fields.flatMap(\.rocks).first { $0.radius > 45 })
    game.miningFields = fields
    game.bodies[index].physical?.rock = rock.identity
    let scaled = game.gameplayMesh(for: game.bodies[index])
    #expect(scaled.vertices != Mesh.hull(.cargo).vertices)
    #expect(game.commander.cargoDebrisLedger.boundActor(for: payload.identity) == actor)
    #expect(!game.automaticScoopShapeCompatible(game.bodies[index], context: context))
    #expect(
      game.commander.cargoDebrisLedger.pendingPayloads.contains { $0.identity == payload.identity })
  }

  @Test func canonicalizingVisibleLegacySpinDoesNotMoveAnyMeshVertex() throws {
    var game = try workRuntimeGame()
    let actor = try addWorkCargo(&game, position: .init(40, -55, 800))
    game.bodies[0].physical?.canonicalSpin = nil
    game.bodies[0].rotation = 1.2
    game.bodies[0].rotationRate = -0.3
    game.bodies[0].orientation.rotate(pitch: 0.3, roll: -0.2, yaw: 0.4)
    let mesh = game.gameplayMesh(for: game.bodies[0])
    let before = mesh.vertices.map(game.modelPose(of: game.bodies[0]).systemPoint)
    game.canonicalizeWorkTarget(actor)
    let after = mesh.vertices.map(game.modelPose(of: game.bodies[0]).systemPoint)
    #expect(zip(before, after).allSatisfy { ($0 - $1).length < 1e-8 })
    #expect(game.bodies[0].rotation == 0 && game.bodies[0].rotationRate == 0)
    #expect(game.bodies[0].physical?.canonicalSpin == true)
    #expect((game.bodies[0].physical?.angularVelocity.length ?? 0) > 0)
  }
}
