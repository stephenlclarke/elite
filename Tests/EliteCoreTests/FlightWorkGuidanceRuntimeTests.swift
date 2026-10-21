import Foundation
import Testing

@testable import EliteCore

private func workRuntimeGame(module: WorkTargetSpecialty = .salvage, scoops: Bool = true) throws
  -> Game
{
  var game = Game(executive: false)
  if module == .mining {
    game.commander.shipID = "SH023"
    game.commander.fuel = game.commander.fuelCapacity
  }
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
  game.key("tab")
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
      game.key("tab")
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
  @Test func legacyDirectScoopDoesNotCreateWorkBrakingOrClearAnotherTrackingTarget() throws {
    var game = try workRuntimeGame()
    game.bodies = [.init(id: 81, hull: .cobra, position: .init(0, 0, 1500))]
    game.key("tab")
    let tracked = try #require(game.autoPilot.targetID)
    let weapons = game.weaponsTargetID
    game.speed = 8
    let velocity = game.flightWorldVelocity
    let before = game.commander.cargo[0]
    // Direct helper contract: normal tick adoption has deliberately not run for this new canister.
    let canister = SpaceBody(id: 90, hull: .cargo, position: .init(0, -20, 40))
    game.bodies.append(canister)
    #expect(canister.physical == nil && game.workGuidance == nil)
    game.scoopCargo()
    #expect(game.commander.cargo[0] == before + 1 && !game.bodies.contains { $0.id == 90 })
    #expect(game.workGuidance == nil && game.workBraking == nil)
    #expect(game.autoPilot.targetID == tracked && game.weaponsTargetID == weapons)
    #expect(game.speed == 8 && game.flightWorldVelocity == velocity)
  }

  @Test(arguments: [false, true])
  func collectionOfAMissingOrDifferentPhysicalParentCannotTakeWorkAuthority(otherActor: Bool)
    throws
  {
    var game = try workRuntimeGame()
    let parent = try addWorkCargo(&game, position: .init(0, -45, 1800))
    engageWorkCargo(&game)
    let target = game.autoPilot.targetID
    let weapons = game.weaponsTargetID
    let velocity = game.flightWorldVelocity
    var other = SpaceBody(id: 88, hull: .cargo, position: .init(0, -45, 55))
    if otherActor {
      let allocated = game.commander.flightSimulation.allocateActor()
      other.physical = .init(identity: try #require(allocated), population: .cargo)
    }
    game.workTargetCollected(other)
    #expect(game.workGuidance?.parent == parent && game.workBraking == nil)
    #expect(game.autoPilot.targetID == target && game.weaponsTargetID == weapons)
    #expect(game.flightWorldVelocity == velocity)
  }

  @Test func filterKeyUsesActualFittedModulesAndKeepsOriginalShipDefault() throws {
    var game = try workRuntimeGame()
    _ = try addWorkCargo(&game, position: .init(0, -45, 500))
    #expect(game.workTargetFilter == .ships)
    game.key("tab")
    #expect(game.autoPilot.targetID == nil)
    game.key("f")
    #expect(game.workTargetFilter == .mining)
    game.key("tab")
    #expect(game.autoPilot.targetID == nil)
    game.key("f")
    #expect(game.workTargetFilter == .salvage)
    game.key("tab")
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
    let cargoVelocity = try #require(game.bodies[0].physical?.velocity)
    #expect(motion.start == start && motion.acceleration.length > 0)
    let moved = game.moveWorkFrame(delta: 0.1)
    #expect(moved)
    #expect(game.commander.flightSimulation.pose == motion.end)
    #expect(game.approvedWorkMotion == nil && game.lastAppliedWorkMotion == motion)
    #expect(
      (game.flightWorldVelocity - motion.initialVelocity - motion.acceleration * 0.1).length < 1e-9)
    #expect(
      (game.modelPose(of: game.bodies[0]).position - beforeCargo.position - cargoVelocity * 0.1)
        .length < 1e-8)
    let correct = start.position + motion.initialVelocity * 0.1 + motion.acceleration * 0.005
    #expect((motion.end.position - correct).length < 1e-9)
    #expect((motion.end.position - start.position - game.flightWorldVelocity * 0.1).length > 1e-4)
  }

  @Test func realTickCollectsOneCargoAndBrakesAgainstCurrentSceneWithoutGhostPrimary() throws {
    var game = try workRuntimeGame()
    let collectedActor = try addWorkCargo(
      &game, position: .init(0, 0, 500), velocity: .init(0, 0, 10))
    engageWorkCargo(&game)
    // The cargo mesh is an octahedron: align with its selected real diagonal face.
    let state = try #require(game.workGuidance)
    let targetPose = game.modelPose(of: game.bodies[0])
    let normal = targetPose.orientation.apply(state.surface.normal).unit
    var desired = Basis3()
    desired.z = normal * -1
    var up = targetPose.orientation.y - desired.z * targetPose.orientation.y.dot(desired.z)
    if up.length < 1e-6 {
      up = targetPose.orientation.x - desired.z * targetPose.orientation.x.dot(desired.z)
    }
    desired.y = up.unit
    desired.x = desired.y.cross(desired.z).unit
    let old = game.commander.flightSimulation.pose
    game.bodies[0].orientation = desired.transposed.composed(
      with: old.orientation.composed(with: game.bodies[0].orientation))
    game.commander.flightSimulation.pose.orientation = desired
    game.bodies[0].position = .init(0, -45, 55)
    let actualNormal = game.commander.flightSimulation.pose.shipVector(
      game.modelPose(of: game.bodies[0]).orientation.apply(state.surface.normal))
    #expect((actualNormal - Vector3(0, 0, -1)).length < 1e-8)
    game.workGuidance?.velocity = game.bodies[0].physical?.velocity ?? .init(0, 0, 0)
    if let payload = game.bodies[0].physical?.payload, case .salvage(let lot) = payload {
      game.commander.salvageLedger.updateLot(
        lot,
        position: game.commander.flightSimulation.pose.systemPoint(game.bodies[0].position),
        velocity: game.bodies[0].physical?.velocity ?? .init(0, 0, 0))
    }
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
    let actor = try addWorkCargo(&game, position: .init(0, -45, 500))
    game.workTargetFilter = .salvage
    game.key("tab")
    #expect(game.workGuidance == nil && game.autoPilot.targetID == nil)
    #expect(game.workTargetCapabilities.miningModule && !game.workTargetCapabilities.salvageModule)
    let context = try #require(game.gameplayContext())
    let cargo = try #require(game.bodies.first { $0.physical?.identity == actor })
    let candidate = try #require(
      game.workTargetCandidate(for: cargo, context: context, frontVisible: true))
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
    game.key("return")
    _ = game.admitFlightFire(held: true)
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
    let context = try #require(game.gameplayContext())
    let largeAxis = try #require(
      game.collectibleHalfExtents(game.bodies[index], context: context))
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
    game.key("tab")
    #expect(game.workGuidance?.parent == original.physical?.identity)
    // Reach genuine hold with the trigger released before the first mining press.
    for _ in 0..<800 {
      game.tick(delta: 0.1)
      if game.workGuidance?.holding == true { break }
    }
    try #require(
      game.workGuidance?.parent == original.physical?.identity
        && game.workGuidance?.holding == true)
    try #require(game.selectedFlightTool == .miningLaser && !game.workFireSuspended)
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
    #expect(game.workRecoveryRock == rock.identity)
    #expect(game.workBraking != nil || game.workGuidance?.mode == .autoScoop(.mining))
    let native = Mesh.hull(.cargo)
    #expect(game.gameplayMesh(for: body).vertices == native.vertices)
    let before = game.commander.cargo[payload.amount.commodity.rawValue]
    var interceptedActualOre = false
    for _ in 0..<600 {
      if game.workGuidance?.mode == .autoScoop(.mining), game.workGuidance?.parent == actor {
        interceptedActualOre = true
      }
      game.tick(delta: 0.1)
      if game.commander.miningLedger.boundActor(for: payload.identity) == nil { break }
    }
    #expect(interceptedActualOre)
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
    let generated = try #require(fields.flatMap(\.rocks).first)
    // Deliberately author a custom large override; generated rocks have radii 18..<40.
    let rock = MiningRock(
      identity: generated.identity, position: generated.position,
      radius: 100, energy: generated.energy)
    game.miningFields = [.init(position: rock.position, rocks: [rock])]
    game.bodies[index].physical?.rock = rock.identity
    let scaled = game.gameplayMesh(for: game.bodies[index])
    #expect(scaled.vertices != Mesh.hull(.cargo).vertices)
    #expect(game.commander.cargoDebrisLedger.boundActor(for: payload.identity) == actor)
    #expect(!game.automaticScoopShapeCompatible(game.bodies[index], context: context))
    #expect(
      game.commander.cargoDebrisLedger.pendingPayloads.contains { $0.identity == payload.identity })
  }

  @Test func compactLongWorkStatusAndHintRemainInsideTheActualTargetPanel() throws {
    var game = try workRuntimeGame()
    _ = try addWorkCargo(&game, position: .init(0, -45, 1800))
    engageWorkCargo(&game)
    game.advanceWorkGuidance(delta: 0.02)
    game.viewportWidth = 512
    game.viewportHeight = 518
    let info = try #require(game.targetInformation)
    #expect(info.status == "APPROACHING SCOOP TARGET")
    for expanded in [false, true] {
      game.targetPanelExpanded = expanded
      let cockpit = CockpitLayout(game: game, width: 512, height: 518)
      let panel = TargetPanelLayout(game: game, info: info, cockpit: cockpit)
      #expect(panel.statuses.count > 1)
      let frame = Display.presentation(game, width: 512, height: 518)
      for line in panel.statuses {
        let label = try #require(frame.labels.first { $0.text == line })
        #expect(label.bounds.maxX <= 512 && label.bounds.maxY <= cockpit.flightClip.maxY)
      }
      #expect(panel.statuses.joined(separator: " ").contains(expanded ? "I: Hide" : "I: Detail"))
      #expect(game.commander.salvageLedger.pendingLots.count == 1)
    }
  }

  @Test(arguments: [false, true])
  func actualWorkCameraMovesStarsDuringApprovedMotionAndUnpoweredCoast(blocked: Bool) throws {
    var game = try workRuntimeGame()
    _ = try addWorkCargo(&game, position: .init(0, -45, 1800))
    engageWorkCargo(&game)
    game.workGuidance?.velocity = .init(0, 0, 18)
    if blocked {
      game.bodies.append(.init(id: 89, hull: .cargo, position: .init(0, 0, 0)))
      game.ensurePhysicalActors()
      game.bodies[1].rotationRate = 0
    }
    let start = game.commander.flightSimulation.pose
    let before = game.starfield.positions
    game.tick(delta: 0.02)
    let end = game.commander.flightSimulation.pose
    #expect((end.position - start.position).length > 0)
    #expect(game.starfield.positions.count == before.count)
    if blocked {
      #expect(
        game.lastAppliedWorkMotion == nil
          && game.workGuidance?.status == "SCOOP BLOCKED: PATH NOT CLEAR")
    } else {
      #expect(game.lastAppliedWorkMotion != nil)
    }
    for index in before.indices {
      let expected = end.shipPoint(start.systemPoint(before[index]))
      // This bounded frame deliberately has no recycle crossing.
      try #require(expected.length >= 300 && expected.length <= 9000)
      #expect((game.starfield.positions[index] - expected).length < 1e-8)
    }
    #expect(game.starfield.positions != before)
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

private func releasedResidualGame(_ velocity: Vector3) throws -> Game {
  var game = try workRuntimeGame()
  _ = try addWorkCargo(&game, position: .init(0, -45, 1800))
  engageWorkCargo(&game)
  game.workGuidance?.velocity = velocity
  game.key("q")
  return game
}

struct ManualResidualFlightTests {
  @Test(arguments: [Vector3(20, -10, 50), .init(90, 0, 0), .init(0, 0, -70)])
  func actualQKeepsAllMomentumThroughNeutralSteering(velocity: Vector3) throws {
    var game = try releasedResidualGame(velocity)
    #expect(game.manualResidualFlight && game.speed == 0 && game.autoPilot.targetID == nil)
    #expect(game.message == "MANUAL CONTROL - RELEASE HOLD")
    #expect((game.flightWorldVelocity - velocity).length < 1e-9)
    let start = game.commander.flightSimulation.pose
    var controls = Controls()
    controls.pitch = 0.2
    controls.yaw = -0.15
    controls.roll = 0.1
    game.tick(delta: 0.02, controls: controls)
    #expect((game.flightWorldVelocity - velocity).length < 1e-8)
    #expect(
      (game.commander.flightSimulation.pose.position - start.position - velocity * 0.02).length
        < 1e-8)
    #expect(game.commander.flightSimulation.pose.orientation != start.orientation)
    #expect(game.lastAppliedWorkMotion == nil)
  }

  @Test func firstSteerAndBrakeReleasesWorkAndBrakesTheWholeVectorOnce() throws {
    var game = try workRuntimeGame()
    _ = try addWorkCargo(&game, position: .init(0, -45, 1800))
    engageWorkCargo(&game)
    let initial = Vector3(80, -50, -120)
    game.workGuidance?.velocity = initial
    var controls = Controls()
    controls.pitch = 0.2
    controls.yaw = -0.1
    controls.roll = 0.1
    controls.throttle = -1
    let budget = game.commander.performance.acceleration * 18 * 0.05
    game.tick(delta: 0.05, controls: controls)
    let expected = initial * ((initial.length - budget) / initial.length)
    #expect(game.workGuidance == nil && game.manualResidualFlight && game.speed == 0)
    #expect((game.flightWorldVelocity - expected).length < 1e-8)
    #expect(abs((initial - game.flightWorldVelocity).length - budget) < 1e-8)
    #expect(game.lastAppliedWorkMotion == nil)
  }

  @Test func brakeReleaseCruisesAndRepeatedBrakingStopsExactlyWithoutReversal() throws {
    var game = try releasedResidualGame(.init(17, 9, 4))
    var controls = Controls()
    controls.throttle = -1
    game.tick(delta: 0.02, controls: controls)
    let cruise = game.flightWorldVelocity
    controls.throttle = 0
    game.tick(delta: 0.02, controls: controls)
    #expect((game.flightWorldVelocity - cruise).length < 1e-8)
    controls.throttle = -1
    for _ in 0..<10 {
      let before = game.flightWorldVelocity
      game.tick(delta: 0.02, controls: controls)
      #expect(before.dot(game.flightWorldVelocity) >= -1e-9)
    }
    #expect(game.flightWorldVelocity == .init(0, 0, 0))
    #expect(!game.manualResidualFlight && game.speed == 0)
  }

  @Test func forwardThrustCapsTotalVelocityAndCannotSnapExternalOverspeed() throws {
    let maximum = 32.0 * 18
    for initial in [
      Vector3(0, 0, maximum - 1), .init(maximum - 1, 0, 0), .init(0, 0, maximum + 100),
    ] {
      var game = try releasedResidualGame(initial)
      #expect(game.commander.performance.speed * 18 == maximum)
      let budget = game.commander.performance.acceleration * 18 * 0.1
      var controls = Controls()
      controls.throttle = 1
      game.tick(delta: 0.1, controls: controls)
      #expect((game.flightWorldVelocity - initial).length <= budget + 1e-8)
      if initial.length <= maximum {
        #expect(game.flightWorldVelocity.length <= maximum + 1e-8)
        #expect(game.flightWorldVelocity.z >= initial.z)
      } else {
        #expect((game.flightWorldVelocity - initial).length < 1e-8)
      }
    }
  }

  @Test func actualSpeedGaugeShowsLateralDriftWithZeroScalarSpeed() throws {
    let game = try releasedResidualGame(.init(90, 0, 0))
    #expect(game.speed == 0 && game.cockpitSpeed == 5)
    let layout = CockpitLayout(game: game, width: 768, height: 768)
    let frame = Display.cockpit(game, width: 768, height: 768)
    let lines = frame.graphics.compactMap { graphic -> WireLine? in
      guard case .line(let line) = graphic,
        abs(line.y0 - layout.instrumentsTop - 5) < 1e-8, line.x0 > 768 / 2
      else { return nil }
      return line
    }
    let background = try #require(lines.first { $0.ink == .blue })
    let filled = try #require(lines.first { $0.ink == .green && $0.x1 > $0.x0 })
    let ratio = (filled.x1 - filled.x0) / (background.x1 - background.x0)
    #expect(abs(ratio - 5 / game.commander.performance.speed) < 1e-8)
  }

  @Test func successfulBoundariesClearResidualAndFailedSnapshotsPreserveIt() async throws {
    var game = try releasedResidualGame(.init(20, -10, 50))
    let velocity = game.flightWorldVelocity
    let commander = game.commander
    try #require(commander.savedEquipmentVersion == 3 && commander.usesModularDriveSaveVersion)
    game.bodies[0].physical?.velocity = .init(.nan, 0, 0)
    game.dock()
    #expect(!game.docked && game.manualResidualFlight && game.flightWorldVelocity == velocity)
    #expect(game.commander == commander)
    game.arrive()
    #expect(game.manualResidualFlight && game.flightWorldVelocity == velocity)
    #expect(game.commander == commander)
    game.bodies[0].physical?.velocity = .init(0, 0, 0)
    game.dock()
    #expect(game.docked && !game.manualResidualFlight && game.autoPilot.velocity == .init(0, 0, 0))
    // Retain the real successful dock, including its nonempty ordinary salvage ledger and bindings.
    let docked = game
    try #require(docked.bodies.isEmpty && docked.dockedAtMainStation && docked.screen == .status)
    try #require(
      docked.commander.npcPersistence.count == 0 && docked.commander.savedEMPState == nil)
    try #require(
      docked.commander.alienStorageState == nil && docked.commander.nativeStations != nil)
    try #require(
      docked.commander.scriptState.instances.isEmpty && docked.commander.contracts.boards.isEmpty)
    try #require(docked.commander.scriptState.calendarLedger != nil)
    let lots = docked.commander.salvageLedger.pendingLots
    try #require(!lots.isEmpty)
    #expect(Set(lots.map(\.identity)) == Set(commander.salvageLedger.pendingLots.map(\.identity)))
    for lot in lots {
      #expect(
        docked.commander.salvageLedger.boundActor(for: lot.identity)
          == commander.salvageLedger.boundActor(for: lot.identity))
    }
    #expect(docked.commander.equipmentInventory == commander.equipmentInventory)
    #expect(docked.commander.equipmentPurchaseHistory == commander.equipmentPurchaseHistory)
    #expect(
      docked.commander.credits == commander.credits && docked.commander.cargo == commander.cargo)
    // With no live actors, only current equipment mirroring and mining-policy storage can normalize.
    var expectedCommander = docked.commander
    try expectedCommander.prepareEquipment()
    expectedCommander.mirrorFittedEquipment()
    expectedCommander.miningLedger = docked.commander.miningLedger
    try #require(expectedCommander.salvageLedger == docked.commander.salvageLedger)
    try #require(expectedCommander.nativeStations == docked.commander.nativeStations)
    try #require(expectedCommander.scriptState == docked.commander.scriptState)
    let expectedWorldBytes = try ScriptValueStorage.encoder().encode(docked.scriptWorldSave)
    let expectedWorldValue = try JSONSerialization.jsonObject(with: expectedWorldBytes)
    let expectedWorld = try #require(expectedWorldValue as? NSDictionary)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("docked.json")
    let writer = GameRuntime(game: docked)
    try await writer.save(to: file)
    let published = await writer.snapshot()
    try #require(published.commander == expectedCommander)
    let bytes = try Data(contentsOf: file)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    try #require(pointer.format == "elite-script-save" && pointer.schemaVersion == 26)
    try #require(pointer.scope == "commander" && pointer.valueCodec == ScriptValueStorage.codec)
    let generation = try ScriptSaveStore.generationDirectory(pointer.generation, from: file)
    let names = ["commander.json", "missions.json", "world.json", "contracts.json"]
    try #require(Set(pointer.hashes.keys) == Set(names))
    let (stored, storedWorld) = try ScriptSaveStore.read(bytes, from: file)
    try #require(
      stored == expectedCommander && storedWorld.valid && storedWorld.consistent(with: stored))
    let storedWorldBytes = try ScriptValueStorage.encoder().encode(storedWorld)
    let storedWorldValue = try JSONSerialization.jsonObject(with: storedWorldBytes)
    let storedWorldObject = try #require(storedWorldValue as? NSDictionary)
    try #require(storedWorldObject.isEqual(expectedWorld))
    var chunks: [String: Data] = [:]
    for name in names {
      let chunk = try Data(contentsOf: generation.appendingPathComponent(name))
      try #require(ScriptPackLibrary.hash(chunk) == pointer.hashes[name])
      chunks[name] = chunk
    }
    let originalGenerations = try FileManager.default.contentsOfDirectory(
      atPath: file.appendingPathExtension("missions").path)
    try #require(originalGenerations == [pointer.generation])
    let originalChunkNames = try FileManager.default.contentsOfDirectory(atPath: generation.path)
    try #require(Set(originalChunkNames) == Set(names))
    game.launch()
    #expect(
      !game.manualResidualFlight && game.speed == 8 && game.autoPilot.velocity == .init(0, 0, 0))
    let launchedCommander = game.commander
    let launchedWorld = try ScriptValueStorage.encoder().encode(game.scriptWorldSave)
    let launchedVelocity = game.flightWorldVelocity
    let launchedAutopilot = game.autoPilot.velocity
    let launchedResidual = game.manualResidualFlight
    let launchedPaused = game.paused
    let launchedTool = game.selectedFlightTool
    let refusedCurrent = game.load(commander)
    let afterRefusalWorld = try ScriptValueStorage.encoder().encode(game.scriptWorldSave)
    #expect(
      !refusedCurrent && game.commander == launchedCommander && afterRefusalWorld == launchedWorld)
    #expect(
      game.manualResidualFlight == launchedResidual && game.autoPilot.velocity == launchedAutopilot)
    #expect(game.flightWorldVelocity == launchedVelocity)
    #expect(game.paused == launchedPaused && game.selectedFlightTool == launchedTool)
    let reader = GameRuntime(game: game)
    try await reader.load(from: file, persistMigrations: false)
    game = await reader.snapshot()
    #expect(game.commander == expectedCommander && game.dockedAtMainStation && !game.paused)
    #expect(
      game.docked && !game.manualResidualFlight
        && game.flightWorldVelocity == .init(0, 0, 0))
    #expect(game.autoPilot.velocity == .init(0, 0, 0))
    let restoredWorldBytes = try ScriptValueStorage.encoder().encode(game.scriptWorldSave)
    let restoredWorldValue = try JSONSerialization.jsonObject(with: restoredWorldBytes)
    let restoredWorld = try #require(restoredWorldValue as? NSDictionary)
    #expect(restoredWorld.isEqual(expectedWorld))
    let afterBytes = try Data(contentsOf: file)
    #expect(afterBytes == bytes)
    for name in names {
      let chunk = try Data(contentsOf: generation.appendingPathComponent(name))
      #expect(chunk == chunks[name])
    }
    let afterGenerations = try FileManager.default.contentsOfDirectory(
      atPath: file.appendingPathExtension("missions").path)
    let afterChunkNames = try FileManager.default.contentsOfDirectory(atPath: generation.path)
    #expect(
      afterGenerations == originalGenerations && Set(afterChunkNames) == Set(originalChunkNames))
    game = try releasedResidualGame(velocity)
    game.arrive()
    #expect(!game.manualResidualFlight && game.autoPilot.velocity == .init(0, 0, 0))
    #expect(abs(game.speed * 18 - velocity.length) < 1e-8)
  }

  @Test func newTargetSelectionPreservesReleasedMomentumUntilItsControllerTakesOwnership() throws {
    let velocity = Vector3(20, -10, 50)
    var game = try releasedResidualGame(velocity)
    game.workTargetFilter = .ships
    game.bodies.append(.init(id: 90, hull: .cobra, position: .init(0, 0, 3000)))
    game.key("tab")
    #expect(game.autoTargetBody?.id == 90 && game.manualResidualFlight)
    #expect((game.flightWorldVelocity - velocity).length < 1e-8)
    var controls = Controls()
    controls.throttle = -1
    game.tick(delta: 0.02, controls: controls)
    #expect(game.autoPilot.targetID == nil && game.flightWorldVelocity.length < velocity.length)
    game.bodies = [.init(id: 0, hull: .station, position: .init(0, 0, 10000))]
    let before = game.flightWorldVelocity
    game.key("tab")
    #expect(game.dockingComputer && !game.manualResidualFlight)
    #expect((game.flightWorldVelocity - before).length < 1e-8)
  }

  @Test func solarScoopingUsesActualForwardCruiseAndRefusesLateralOrReverseDrift() throws {
    for velocity in [Vector3(0, 0, 144), .init(144, 0, 0), .init(0, 0, -144)] {
      var game = try releasedResidualGame(velocity)
      game.commander.fuel = 0
      game.celestials = [.init(kind: .sun, position: .init(0, 0, 3000), radius: 1100)]
      game.tick(delta: 0.1)
      game.tick(delta: 0.1)
      if velocity.z > 0 {
        #expect(game.commander.fuel > 0 && game.solarScoopState == .collecting)
      } else {
        #expect(game.commander.fuel == 0 && game.solarScoopState == .turnTowardSun)
      }
    }
  }

  @Test func ordinaryZeroResidualAndAngularTouchContractRemainUnchanged() throws {
    var game = try workRuntimeGame()
    game.speed = 10
    var controls = Controls()
    controls.throttle = -1
    game.tick(delta: 0.1, controls: controls)
    #expect(!game.manualResidualFlight && abs(game.speed - 8.8) < 1e-8)
    var pad = TrackpadInput()
    for count in [1, 2, 3] {
      _ = pad.update(
        positions: Array(repeating: SIMD2<Double>(0.5, 0.5), count: count), spinMode: true)
      #expect(pad.spinControls.throttle == 0)
    }
  }
}

extension FlightWorkGuidanceRuntimeTests {
  @Test func acquisitionSelectsImmediatelyAndManualWeaponOverrideSurvivesHoldReadiness() throws {
    var game = try actualLargeWorkHold()
    let parent = try #require(game.workGuidance?.parent)
    #expect(game.selectedFlightTool == .salvageCutter)
    #expect(game.workGuidance?.parent == parent)
    _ = game.admitFlightFire(held: true)
    game.key("w")
    #expect(game.selectedFlightTool == .combatLaser)
    #expect(game.workGuidance?.parent == parent && game.workGuidance?.manualToolOverride == true)
    game.key("i")
    #expect(game.workGuidance?.parent == parent)
    for _ in 0..<30 {
      game.advanceWorkGuidance(delta: 0.02)
      _ = game.moveWorkFrame(delta: 0.02)
    }
    #expect(game.workGuidance?.holding == true)
    #expect(game.selectedFlightTool == .combatLaser)
    #expect(game.workGuidance?.manualToolOverride == true)
    let staleHeld = game.admitFlightFire(held: true)
    #expect(!staleHeld)
    game.key("return")
    let freshPress = game.admitFlightFire(held: true)
    #expect(freshPress)
    #expect(game.workGuidance?.parent == parent)
  }

  @Test func actualAcquisitionNeverSubstitutesCombatForAnAbsentDefaultCutter() throws {
    var game = try actualLargeWorkHold()
    let cutter = try #require(game.commander.fittedEquipment(at: .utility(.salvageCutter)))
    let revision = try #require(game.commander.equipmentInventory?.revision)
    try game.commander.storeEquipment(cutter, expectedRevision: revision)
    let parent = try #require(game.workGuidance?.parent)
    let body = try #require(game.bodies.first { $0.physical?.identity == parent })
    game.beginWorkGuidance(body: body, mode: .hold(.salvage), velocity: game.flightWorldVelocity)
    #expect(game.selectedFlightTool == .salvageCutter)
    #expect(game.deriveFlightWeaponDisplay().status == "NOT FITTED")
    let before = game.dischargeAudio.events
    var held = Controls()
    held.fire = true
    game.tick(delta: 0.02, controls: held)
    #expect(game.dischargeAudio.events == before && game.workGuidance?.parent == parent)
  }
}

extension FlightWorkGuidanceRuntimeTests {
  @Test func liveCatalogueCapitalAcquiresGeometryHoldWithoutBecomingSalvage() throws {
    var game = try workRuntimeGame(scoops: false)
    let ship = try #require(ShipCatalogue.ship("SH043"))
    try #require(ship.catalogue.isCapital && ship.catalogue.capitalSubtype == .vessel)
    let craft = try #require(ship.game)
    game.bodies = [.init(id: 70, hull: .cobra, position: .init(0, 0, 20000))]
    game.ensurePhysicalActors()
    game.bodies[0].physical?.catalogueShipID = ship.id
    game.bodies[0].physical?.npc?.resources = .stock(craft)
    let body = game.bodies[0]
    let context = try #require(game.gameplayContext())
    let candidate = try #require(
      game.workTargetCandidate(
        for: body, context: context,
        frontVisible: true))
    #expect(candidate.kind == .capitalShip)
    #expect(game.recoverableMetadata(for: body, context: context) == nil)
    let surface = try #require(game.holdSurfaceMetadata(for: body, context: context))
    #expect(surface.wreck == nil && surface.workSurfaces.isEmpty)
    let commander = game.commander
    game.key("tab")
    #expect(game.workGuidance?.parent == body.physical?.identity)
    #expect(game.workGuidance?.mode == .hold(.salvage))
    #expect(game.selectedFlightTool == .salvageCutter)
    #expect(game.bodies[0].physical?.salvage == nil)
    #expect(game.commander == commander && game.dischargeAudio.events.isEmpty)
    let cut = game.fireSalvageCutter(delta: 0.1)
    #expect(!cut && game.nativeSalvageWork == nil)
    let module = try #require(game.commander.fittedEquipment(at: .targetingSalvage))
    let revision = try #require(game.commander.equipmentInventory?.revision)
    try game.commander.storeEquipment(module, expectedRevision: revision)
    game.key("q")
    game.key("tab")
    #expect(game.autoPilot.targetActor == body.physical?.identity)
    #expect(game.workGuidance == nil && game.workBraking == nil && !game.dockingComputer)
  }

  @Test(arguments: [SalvageOwnership.claimed, .occupied, .missionProtected])
  func nativeProtectedParentPermitsHoldButEveryCutterGuardRemains(ownership: SalvageOwnership)
    throws
  {
    var (game, _) = try NativePagedSalvageFixture.game()
    let index = try #require(game.bodies.firstIndex { $0.physical?.salvage?.wreck != nil })
    let old = try #require(game.bodies[index].physical?.salvage)
    let claimant = ownership == .claimed ? game.commander.flightSimulation.player : nil
    game.bodies[index].physical?.salvage = .init(
      category: old.category, ownership: ownership,
      claimant: claimant,
      wreck: old.wreck, section: old.section, lot: old.lot, bounds: old.bounds,
      workSurfaces: old.workSurfaces)
    game.workTargetFilter = .salvage
    let commander = game.commander
    let resources = [game.energy, game.laserHeat, game.fireCooldown]
    game.key("tab")
    #expect(game.workGuidance?.parent == game.bodies[index].physical?.identity)
    #expect(game.workGuidance?.mode == .hold(.salvage))
    let cut = game.fireSalvageCutter(delta: 0.1)
    #expect(!cut && game.commander == commander && game.nativeSalvageWork == nil)
    #expect(game.dischargeAudio.events.isEmpty)
    #expect([game.energy, game.laserHeat, game.fireCooldown] == resources)
  }
}

extension FlightWorkGuidanceRuntimeTests {
  @Test(arguments: [Vector3(0, 0, 0), .init(0.01, 0.02, 0.03), .init(0.2, 0.001, 0.5)])
  func nativeOreAdmissionAndSelectionPreserveRequestedPhysicalSpin(omega: Vector3) throws {
    var game = try workRuntimeGame(module: .mining)
    try game.commander.grantEquipment(
      "Mining Laser", at: .utility(.miningLaser), provenance: .grant("native ore spin fixture"))
    let anchors = try #require(game.commander.flightSimulation.anchors)
    let field = try #require(MiningFields.generate(anchors: anchors, seed: game.gameplaySeed).first)
    let rock = try #require(field.rocks.first)
    game.miningFields = [.init(position: field.position, rocks: [rock])]
    game.commander.flightSimulation.pose.position = rock.position - .init(0, 0, 500)
    game.activateNearbyMiningFields()
    // Stop before the next ecology tick admits the actual terminal hit's native output.
    for _ in 0..<300 {
      _ = game.fireMiningWorkTool()
      if game.commander.miningLedger.isDepleted(rock.identity) { break }
      game.tick(delta: 0.1)
    }
    try #require(game.commander.miningLedger.isDepleted(rock.identity))
    let context = try #require(game.gameplayContext())
    let requests = game.commander.miningLedger.pendingSpawnRequests(
      context: context, fields: game.miningFields)
    var request = try #require(requests.first)
    let payload = try #require(request.payload)
    try #require(
      request.identity.producer == .mining && request.angularVelocity == Vector3(0, 0, 0))
    // Vary only the not-yet-admitted request; existing body momentum is never rewritten.
    request.angularVelocity = omega
    let receipts = game.admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit, revision: context.revision,
        batches: [.init(requests: [request], atomic: true)], intents: []))
    game.commander.miningLedger.acknowledge(receipts: receipts)
    let actor = try #require(receipts.first?.actor)
    let admitted = try #require(game.bodies.first { $0.physical?.identity == actor })
    #expect(game.commander.miningLedger.boundActor(for: payload) == actor)
    #expect(
      admitted.physical?.spawnIdentity == request.identity && admitted.physical?.payload == payload)
    #expect(admitted.physical?.angularVelocity == omega && admitted.physical?.canonicalSpin == true)
    #expect(admitted.rotation == 0 && admitted.rotationRate == 0)
    let native = Mesh.hull(.cargo)
    #expect(game.gameplayMesh(for: admitted).vertices == native.vertices)
    #expect(game.gameplayMesh(for: admitted).faces == native.faces)
    let before = game.modelPose(of: admitted)
    #expect((before.orientation.x - request.orientation.x).length < 1e-9)
    #expect((before.orientation.y - request.orientation.y).length < 1e-9)
    #expect((before.orientation.z - request.orientation.z).length < 1e-9)

    let legacySequence =
      (game.bodies.compactMap { $0.physical?.spawnIdentity?.sequence }.max() ?? 0) + 1
    let legacy = SpawnRequest(
      identity: .init(
        system: context.system, visit: context.visit, sequence: legacySequence, member: 0),
      population: .cargo, hull: .cargo, position: request.position + .init(1000, 0, 0),
      orientation: Basis3(), velocity: .init(0, 0, 0), npc: nil, rock: nil, payload: nil,
      priority: .ordinary)
    let legacyContext = try #require(game.gameplayContext())
    let legacyReceipts = game.admitEncounterPlan(
      .init(
        system: legacyContext.system, visit: legacyContext.visit, revision: legacyContext.revision,
        batches: [.init(requests: [legacy], atomic: true)], intents: []))
    let legacyActor = try #require(legacyReceipts.first?.actor)
    let legacyBefore = try #require(game.bodies.first { $0.physical?.identity == legacyActor })
    #expect(legacyBefore.rotationRate == 0.5 && legacyBefore.physical?.canonicalSpin != true)

    game.workTargetFilter = .mining
    game.key("tab")
    try #require(
      game.workGuidance?.parent == actor && game.workGuidance?.mode == .autoScoop(.mining))
    let selected = try #require(game.bodies.first { $0.physical?.identity == actor })
    #expect(game.modelPose(of: selected) == before)
    #expect(selected.physical?.angularVelocity == omega && selected.physical?.canonicalSpin == true)
    game.tick(delta: 0.05)
    let advanced = try #require(game.bodies.first { $0.physical?.identity == actor })
    #expect(advanced.physical?.angularVelocity == omega)
    #expect(game.commander.miningLedger.boundActor(for: payload) == actor)
    let orientation = game.modelPose(of: advanced).orientation
    if omega.length == 0 {
      #expect((orientation.x - before.orientation.x).length < 1e-9)
      #expect((orientation.y - before.orientation.y).length < 1e-9)
      #expect((orientation.z - before.orientation.z).length < 1e-9)
    } else {
      #expect(orientation != before.orientation)
    }
    let legacyAfter = try #require(game.bodies.first { $0.physical?.identity == legacyActor })
    #expect(legacyAfter.rotationRate == 0.5 && legacyAfter.rotation > legacyBefore.rotation)
    // Fast requested spin remains fast; admission must not manufacture scoop eligibility.
    let radius = try #require(native.vertices.map(\.length).max())
    let physical = try #require(advanced.physical)
    #expect(physical.angularVelocity.length * radius == omega.length * radius)
    if omega.z == 0.5 {
      #expect(omega.length * radius > ScoopApproachController.maximumRelativeSpeed)
    }
  }
}

private func nativeTwentyReleaseGame() throws -> (Game, MiningRock) {
  var game = try workRuntimeGame(module: .mining)
  try game.commander.grantEquipment(
    "Mining Laser", at: .utility(.miningLaser), provenance: .grant("native release fixture"))
  let anchors = try #require(game.commander.flightSimulation.anchors)
  let fields = MiningFields.generate(anchors: anchors, seed: game.gameplaySeed)
  let field = try #require(
    fields.first { $0.rocks.contains { $0.identity.field == 5 && $0.identity.rock == 0 } })
  let rock = try #require(field.rocks.first { $0.identity.field == 5 && $0.identity.rock == 0 })
  try #require(AsteroidBeltDefinition.chunk(for: rock.identity)?.units == 20)
  game.miningFields = [.init(position: field.position, rocks: [rock])]
  game.commander.flightSimulation.pose.position = rock.position - .init(0, 0, 1000)
  game.activateNearbyMiningFields()
  for _ in 0..<300 {
    _ = game.fireMiningWorkTool()
    if game.commander.miningLedger.isDepleted(rock.identity) { break }
    game.tick(delta: 0.1)
  }
  try #require(game.commander.miningLedger.isDepleted(rock.identity))
  try #require(game.commander.miningLedger.pendingPayloads.count == 20)
  return (game, rock)
}

private func fillNativeOreAdmissionCapacity(_ game: inout Game) throws {
  let context = try #require(game.gameplayContext())
  let sequence = (game.bodies.compactMap { $0.physical?.spawnIdentity?.sequence }.max() ?? 0) + 1
  let existing = game.bodies.filter { $0.physical?.population == .cargo }.count
  let remaining = max(0, PopulationClass.cargo.maximum - existing)
  let requests = (0..<remaining).map { index in
    SpawnRequest(
      identity: .init(
        system: context.system, visit: context.visit,
        sequence: sequence + UInt64(index), member: 0),
      population: .cargo, hull: .cargo,
      position: context.player.position
        + Vector3(Double(index % 8) * 250 - 875, Double(index / 8) * 250 - 375, -8000),
      orientation: Basis3(), velocity: .init(0, 0, 0),
      npc: nil, rock: nil, payload: nil, priority: .ordinary)
  }
  let receipts = game.admitEncounterPlan(
    .init(
      system: context.system, visit: context.visit, revision: context.revision,
      batches: [.init(requests: requests, atomic: false)], intents: []))
  try #require(
    receipts.count == remaining && receipts.allSatisfy { $0.actor != nil && $0.refusal == nil })
}

extension FlightWorkGuidanceRuntimeTests {
  @Test func freshTwentyPodOutputUsesNativeSafeAdmission() throws {
    var (game, _) = try nativeTwentyReleaseGame()
    let context = try #require(game.gameplayContext())
    let requests = game.commander.miningLedger.pendingSpawnRequests(
      context: context, fields: game.miningFields)
    try #require(requests.count == 20)
    let original = try #require(requests.first)
    let unsafe = SpawnRequest(
      identity: original.identity, population: original.population, hull: original.hull,
      position: context.player.position, orientation: original.orientation,
      velocity: original.velocity, npc: original.npc, rock: original.rock,
      payload: original.payload, priority: original.priority)
    let refused = game.admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit, revision: context.revision,
        batches: [.init(requests: [unsafe], atomic: true)], intents: []))
    #expect(refused.first?.refusal == .unsafePosition && refused.first?.actor == nil)
    let receipts = game.admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit, revision: context.revision,
        batches: [.init(requests: requests, atomic: false)], intents: []))
    game.commander.miningLedger.acknowledge(receipts: receipts)
    #expect(receipts.count == 20 && receipts.allSatisfy { $0.actor != nil && $0.refusal == nil })
    for request in requests {
      let payload = try #require(request.payload)
      let actor = try #require(game.commander.miningLedger.boundActor(for: payload))
      let body = try #require(game.bodies.first { $0.physical?.identity == actor })
      #expect((game.modelPose(of: body).position - request.position).length < 1e-8)
      #expect(body.physical?.velocity == request.velocity)
    }
  }

  @Test func pendingOreRecoveryWaitsExpiresAndQPreservesMomentum() throws {
    var (game, rock) = try nativeTwentyReleaseGame()
    try fillNativeOreAdmissionCapacity(&game)
    let pending = game.commander.miningLedger.pendingPayloads
    game.workRecoveryRock = rock.identity  // Initial recovery phase, not a cargo or motion grant.
    game.selectNextMinedOre()
    let deadline = try #require(game.workRecoveryAdmissionDeadline)
    #expect(game.workRecoveryRock == rock.identity)
    #expect(game.message == "ORE RECOVERY WAITING FOR SAFE ADMISSION")
    var cancelled = game
    var controls = Controls()
    controls.throttle = 1
    cancelled.tick(delta: 0.1, controls: controls)
    let momentum = cancelled.flightWorldVelocity
    try #require(momentum.length > 0 && cancelled.workRecoveryRock == rock.identity)
    cancelled.key("q")
    #expect(cancelled.workRecoveryRock == nil && cancelled.workRecoveryAdmissionDeadline == nil)
    #expect(cancelled.flightWorldVelocity == momentum)
    #expect(cancelled.commander.miningLedger.pendingPayloads == pending)

    for _ in 0..<610 {
      game.tick(delta: 0.1)
      if game.workRecoveryRock == nil { break }
    }
    #expect(game.workRecoveryRock == nil && game.workRecoveryAdmissionDeadline == nil)
    #expect(game.commander.flightSimulation.physicalTime >= deadline)
    #expect(game.commander.flightSimulation.physicalTime < deadline + 0.11)
    #expect(game.message == "ORE RECOVERY BLOCKED - SAFE ADMISSION UNAVAILABLE")
    #expect(game.commander.miningLedger.pendingPayloads == pending)
    #expect(game.flightWorldVelocity == Vector3(0, 0, 0))
  }

  @Test func pendingOreRecoveryResumesAndFinishesOnlyWithoutPending() throws {
    var (game, rock) = try nativeTwentyReleaseGame()
    game.workRecoveryRock = rock.identity
    game.selectNextMinedOre()
    try #require(game.workRecoveryAdmissionDeadline != nil)
    game.tick(delta: 0.1)
    #expect(game.workGuidance?.mode == .autoScoop(.mining))
    #expect(game.workRecoveryAdmissionDeadline == nil && game.workRecoveryRock == rock.identity)
    let pending = game.commander.miningLedger.pendingPayloads
    for payload in pending {
      let destroyed = game.commander.miningLedger.destroy(payload: payload.identity)
      #expect(destroyed)
    }
    game.key("q")
    game.workRecoveryRock = rock.identity
    game.selectNextMinedOre()
    #expect(game.workRecoveryRock == nil && game.workRecoveryAdmissionDeadline == nil)
    #expect(game.message == "ORE RECOVERY FINISHED")
    #expect(game.commander.miningLedger.pendingPayloads.isEmpty)
  }

  @Test func boundButIneligibleOreRecoveryReportsBlocked() throws {
    var (game, rock) = try nativeTwentyReleaseGame()
    game.admitPendingOre()
    let pending = game.commander.miningLedger.pendingPayloads
    try #require(pending.count == 20)
    for payload in pending {
      try #require(game.commander.miningLedger.boundActor(for: payload.identity) != nil)
    }
    game.commander.cargo[0] = game.commander.standardCargoCapacity  // Initial owned full-hold case.
    game.workRecoveryRock = rock.identity
    game.selectNextMinedOre()
    #expect(game.workRecoveryRock == nil && game.workRecoveryAdmissionDeadline == nil)
    #expect(game.message == "ORE RECOVERY BLOCKED - UNCOLLECTED ORE REMAINS")
    #expect(game.commander.miningLedger.pendingPayloads == pending)
  }
}
