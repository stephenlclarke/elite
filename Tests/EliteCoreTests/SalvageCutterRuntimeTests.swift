import Foundation
import Testing

@testable import EliteCore

private func cutterRuntimeGame() throws -> (Game, WreckSectionIdentity) {
  var game = Game(executive: false)
  game.launch()
  game.speed = 0
  game.bodies = []
  game.celestials = []
  try game.commander.prepareEquipment(legacy: false)
  try game.commander.grantEquipment(
    "Salvage Cutter", at: .utility(.salvageCutter), provenance: .grant("runtime fixture"))
  let allocatedIdentity = game.commander.flightSimulation.allocateActor()
  let identity = try #require(allocatedIdentity)
  let wreck = WreckIdentity(system: game.systemIdentity, site: 88, lineage: 99)
  // Find an actually visible section, rather than assuming a hull centre is a cutting point.
  for profile in SalvageCatalogue.all {
    for section in profile.sections {
      let z = section.normal.unit * -1
      let cardinal = abs(z.y) < 0.8 ? Vector3(0, 1, 0) : .init(1, 0, 0)
      var frame = Basis3()
      frame.z = z
      frame.x = cardinal.cross(z).unit
      frame.y = z.cross(frame.x).unit
      let orientation = frame.transposed
      var body = SpaceBody(
        id: 88, hull: .cobra,
        position: Vector3(0, 0, 200) - orientation.apply(section.localPosition))
      body.orientation = orientation
      body.rotationRate = 0
      body.physical = .init(
        identity: identity, population: .civilian, catalogueShipID: profile.catalogueShipID,
        salvage: .init(
          category: .wreck, ownership: .abandoned, claimant: nil, wreck: wreck,
          section: nil, lot: nil, bounds: profile.bounds,
          workSurfaces: profile.surfaces(wreck: wreck)))
      game.bodies = [body]
      guard
        let hit = GameplayRaycast.nearest(
          origin: .init(0, 0, 0), direction: .init(0, 0, 1), maxDistance: 300,
          bodies: game.bodies, meshOverrides: game.gameplayMeshOverrides),
        hit.target == .body(body.id), (hit.point - Vector3(0, 0, 200)).length < 0.001
      else { continue }
      return (game, .init(wreck: wreck, section: section.index))
    }
  }
  throw SaveError.invalidCommander
}

struct SalvageCutterRuntimeTests {
  @Test func anActualClaimantRefusesCuttingEvenIfTheOwnershipLabelSaysAbandoned() throws {
    var (game, _) = try cutterRuntimeGame()
    let old = try #require(game.bodies[0].physical?.salvage)
    let claimant = try #require(game.commander.flightSimulation.player)
    game.bodies[0].physical?.salvage = .init(
      category: old.category, ownership: .abandoned, claimant: claimant, wreck: old.wreck,
      section: old.section, lot: old.lot, bounds: old.bounds, workSurfaces: old.workSurfaces)
    let before = game.commander
    let energy = game.energy
    let accepted = game.fireSalvageCutter(delta: 0.1)
    #expect(!accepted && game.commander == before && game.energy == energy)
  }

  @Test func realSectionWorkUsesTheSelectedCutterAndFiniteResourcesWithoutCombatDamage() throws {
    var (game, section) = try cutterRuntimeGame()
    game.selectFlightTool(.salvageCutter)
    let before = game.commander
    let energy = game.energy
    let heat = game.laserHeat
    let bodyEnergy = game.bodies[0].energy
    game.fireSelectedFlightTool(delta: 0.1)
    #expect(game.commander.salvageLedger.progress(section) == 0.1)
    #expect(abs(game.energy - (energy - 0.2)) < 1e-10)
    #expect(abs(game.laserHeat - (heat + 0.6)) < 1e-10)
    #expect(game.bodies[0].energy == bodyEnergy && game.laserFlash > 0)
    #expect(game.commander.crimeLedger == before.crimeLedger)
    #expect(game.commander.equipmentInventory == before.equipmentInventory)
    #expect(game.commander.cargo == before.cargo && game.commander.credits == before.credits)
  }

  @Test(arguments: [SalvageOwnership.claimed, .occupied, .missionProtected])
  func actualProtectedOwnershipRefusesBeforeLedgerResourceOrIdentityMutation(
    ownership: SalvageOwnership
  ) throws {
    var (game, _) = try cutterRuntimeGame()
    let old = try #require(game.bodies[0].physical?.salvage)
    game.bodies[0].physical?.salvage = .init(
      category: old.category, ownership: ownership, claimant: nil, wreck: old.wreck,
      section: old.section, lot: old.lot, bounds: old.bounds, workSurfaces: old.workSurfaces)
    let before = game.commander
    let bodies = game.bodies
    let energy = game.energy
    let heat = game.laserHeat
    let accepted = game.fireSalvageCutter(delta: 0.1)
    #expect(!accepted && game.commander == before && game.bodies == bodies)
    #expect(game.energy == energy && game.laserHeat == heat)
  }

  @Test func actualOccludingShipPreventsSectionWorkAndCannotBeDamagedByTheCutter() throws {
    var (game, _) = try cutterRuntimeGame()
    game.bodies.insert(.init(id: 99, hull: .sidewinder, position: .init(0, 0, 80)), at: 0)
    game.ensurePhysicalActors()
    let before = game.commander
    let bodies = game.bodies
    let energy = game.energy
    let accepted = game.fireSalvageCutter(delta: 0.1)
    #expect(!accepted && game.commander == before && game.bodies == bodies)
    #expect(game.energy == energy)
  }

  @Test func realPartialCutAndCurrentWreckPoseSurviveExplicitSave() async throws {
    var (game, section) = try cutterRuntimeGame()
    let accepted = game.fireSalvageCutter(delta: 0.1)
    #expect(accepted)
    game.bodies[0].position.x += 37
    let expected = game.modelPose(of: game.bodies[0])
    let runtime = GameRuntime(game: game)
    let save = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: save) }
    try await runtime.save(to: save)
    let saved = try JSONDecoder().decode(Commander.self, from: Data(contentsOf: save))
    #expect(saved.salvageLedger.progress(section) == 0.1)
    #expect(saved.salvageLedger.wreckMotion(for: section.wreck)?.pose == expected)
    #expect(saved.equipmentInventory == game.commander.equipmentInventory)
  }
}

private func releasedCutterGame(systemOffset: Int = 0) throws -> (Game, SalvageLot, Int) {
  var (game, _) = try cutterRuntimeGame()
  if systemOffset != 0 {
    // A second genuine visit produces foreign-system custody, not a forged pending lot.
    game.commander.system = (game.commander.system + systemOffset) % 256
    game.beginGameplayVisit(arriving: false)
    let original = game.bodies[0]
    let physical = try #require(original.physical)
    let allocatedActor = game.commander.flightSimulation.allocateActor()
    let actor = try #require(allocatedActor)
    let old = try #require(physical.salvage)
    let wreck = WreckIdentity(system: game.systemIdentity, site: 88, lineage: 99)
    let profile = try #require(SalvageCatalogue.profile(catalogueShipID: physical.catalogueShipID!))
    game.bodies[0].physical = .init(
      identity: actor, population: .civilian, catalogueShipID: profile.catalogueShipID,
      salvage: .init(
        category: .wreck, ownership: old.ownership, claimant: nil, wreck: wreck,
        section: nil, lot: nil, bounds: profile.bounds, workSurfaces: profile.surfaces(wreck: wreck)
      ))
  }
  try game.commander.grantEquipment(
    "Fuel Scoops", at: .utility(.fuelScoops), provenance: .grant("fixture"))
  for _ in 0..<320 {
    let accepted = game.fireSalvageCutter(delta: 0.1)
    #expect(accepted)
    if let lot = game.commander.salvageLedger.pendingLots.first {
      let body = try #require(game.bodies.first { $0.physical?.payload == .salvage(lot.identity) })
      #expect(game.commander.salvageLedger.boundActor(for: lot.identity) == body.physical?.identity)
      return (game, lot, body.id)
    }
  }
  throw SaveError.invalidCommander
}

extension SalvageCutterRuntimeTests {
  @Test func anAcknowledgedOldVisitBodyCannotCollectAfterTheActualFlightContextChanges() throws {
    var (game, lot, bodyID) = try releasedCutterGame()
    let index = try #require(game.bodies.firstIndex { $0.id == bodyID })
    let bound = try #require(game.bodies[index].physical?.identity)
    game.bodies[index].position = .init(0, -12, 40)
    game.commander.flightSimulation.enter(game.systemIdentity, arriving: false)
    #expect(game.commander.salvageLedger.boundActor(for: lot.identity) == bound)
    #expect(bound.visit != game.commander.flightSimulation.visit)
    let before = game.commander
    let bodies = game.bodies
    game.scoopCargo()
    #expect(game.commander == before && game.bodies == bodies)
  }

  @Test func actualReleasedAndAcknowledgedLotCollectsThroughTheScoopOnlyOnce() throws {
    var (game, lot, bodyID) = try releasedCutterGame()
    let index = try #require(game.bodies.firstIndex { $0.id == bodyID })
    game.bodies[index].position = .init(0, -12, 40)
    let before = game.commander.cargo
    game.scoopCargo()
    #expect(!game.bodies.contains { $0.id == bodyID })
    #expect(!game.commander.salvageLedger.pendingLots.contains { $0.identity == lot.identity })
    #expect(game.commander.salvageLedger.boundActor(for: lot.identity) == nil)
    if case .commodity(let amount) = lot.content {
      #expect(
        game.commander.cargo[amount.commodity.rawValue] == before[amount.commodity.rawValue]
          + amount.quantity)
    } else {
      #expect(game.commander.salvageLedger.inventory.contains { $0.identity == lot.identity })
    }
    let collected = game.commander
    game.scoopCargo()
    #expect(game.commander == collected)
  }

  @Test(arguments: ["wrong actor", "stale visit", "foreign lot"])
  func staleOrForeignBodyCannotCollectAnotherActualActorsAcknowledgedLot(mismatch: String) throws {
    var (game, lot, bodyID) = try releasedCutterGame()
    let original = try #require(game.bodies.first { $0.id == bodyID })
    let allocatedActor = game.commander.flightSimulation.allocateActor()
    let allocated = try #require(allocatedActor)
    var actor = allocated
    var referenced = lot.identity
    if mismatch == "stale visit" {
      actor = .init(system: allocated.system, visit: allocated.visit + 1, entity: allocated.entity)
    } else if mismatch == "foreign lot" {
      let (foreign, foreignLot, _) = try releasedCutterGame(systemOffset: 1)
      game.commander.salvageLedger = foreign.commander.salvageLedger
      referenced = foreignLot.identity
    }
    var wrong = SpaceBody(id: 990, hull: .cargo, position: .init(0, -12, 40))
    wrong.physical = .init(identity: actor, population: .cargo, payload: .salvage(referenced))
    game.bodies.append(wrong)
    let before = game.commander
    let bodies = game.bodies
    game.scoopCargo()
    #expect(game.commander == before && game.bodies == bodies)
    #expect(game.bodies.contains { $0.id == original.id })
    #expect(game.commander.salvageLedger.pendingLots.contains { $0.identity == referenced })
  }
}
