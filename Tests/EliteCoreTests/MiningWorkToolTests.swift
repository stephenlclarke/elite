import Foundation
import Testing

@testable import EliteCore

private func workToolGame() throws -> Game {
  var game = Game(executive: false)
  game.commander.equipment = Equipment.maximumHardware
  game.commander.laserMounts = .init(front: .naval, left: .naval, right: .naval, rear: .naval)
  game.commander.xyzzyActive = true
  try game.commander.initializeEquipment(
    owner: UUID(), hull: UUID(), legacy: false,
    xyzzyGrant: true
  ) { UUID() }
  game.launch()
  game.speed = 0
  game.bodies = []
  game.celestials = []
  try verifyWorkToolFixtureHardware(&game)
  return game
}

private func verifyWorkToolFixtureHardware(_ game: inout Game) throws {
  let inventory = try #require(game.commander.equipmentInventory)
  try #require(game.commander.fittedMiningWorkTool != nil)
  try #require(game.commander.fittedEquipment(at: .utility(.salvageCutter)) != nil)
  try #require(LaserMount.allCases.allSatisfy { game.commander.laser(on: $0) == .naval })
  try #require(game.commander.nativeStations?.ledger.world == inventory.owner)
}

@discardableResult private func workToolRock(_ game: inout Game) throws -> Int {
  let rock = try #require(game.miningFields.first?.rocks.first)
  let allocated = game.commander.flightSimulation.allocateActor()
  let actor = try #require(allocated)
  var body = SpaceBody(id: 80, hull: .asteroid, position: .init(0, 0, 500))
  body.energy = rock.energy
  body.physical = .init(identity: actor, population: .asteroid, rock: rock.identity)
  game.bodies.append(body)
  return body.id
}

struct MiningWorkToolTests {
  @Test func flightToolSelectionDoesNotFireAndReturnUsesMiningInsteadOfTheNavalLaser() throws {
    var game = try workToolGame()
    let id = try workToolRock(&game)
    let inventory = game.commander.equipmentInventory
    let before = try #require(game.bodies.first { $0.id == id }?.energy)
    game.key("w")
    #expect(game.selectedFlightTool == .miningLaser)
    #expect(game.bodies.first { $0.id == id }?.energy == before)
    #expect(game.commander.equipmentInventory == inventory)
    var controls = Controls()
    controls.fire = true
    var audio = DischargeAudioFeed()
    #expect(audio.update(game.dischargeAudio).isEmpty)
    game.tick(delta: 0.02, controls: controls)
    #expect(game.bodies.first { $0.id == id }?.energy == before - LaserKind.mining.damage)
    #expect(audio.update(game.dischargeAudio) == [.miningLaser])
    #expect(audio.update(game.dischargeAudio).isEmpty)
    #expect(game.commander.laser(on: .front) == .naval)
    #expect(game.commander.equipmentInventory == inventory)
    game.key("w")
    #expect(game.selectedFlightTool == .salvageCutter)
    game.key("w")
    #expect(game.selectedFlightTool == .empPirateBlaster)
    #expect(game.commander.laser(on: .front) == .naval)
    game.key("w")
    #expect(game.selectedFlightTool == .combatLaser)
  }

  @Test func selectedMissingCutterDoesNotFallThroughToACombatLaser() throws {
    var game = try workToolGame()
    let cutter = try #require(game.commander.fittedEquipment(at: .utility(.salvageCutter)))
    try game.commander.storeEquipment(
      cutter, expectedRevision: game.commander.equipmentInventory!.revision)
    game.bodies = [.init(id: 20, hull: .sidewinder, position: .init(0, 0, 200))]
    game.ensurePhysicalActors()
    game.selectFlightTool(.salvageCutter)
    #expect(game.message == "FIT SALVAGE CUTTER")
    let before = game.commander
    let bodies = game.bodies
    let resources = [game.energy, game.laserHeat, game.fireCooldown, game.laserFlash]
    let audioBefore = game.dischargeAudio.events
    game.fireSelectedFlightTool(delta: 0.05)
    #expect(game.dischargeAudio.events == audioBefore)
    #expect(game.commander == before && game.bodies == bodies)
    #expect([game.energy, game.laserHeat, game.fireCooldown, game.laserFlash] == resources)
  }

  @Test func actualMiningFrontFitRemainsUsableWithoutTheSeparateUtility() throws {
    var game = try workToolGame()
    let tool = try #require(game.commander.fittedMiningWorkTool)
    try game.commander.storeEquipment(
      tool, expectedRevision: game.commander.equipmentInventory!.revision)
    let held = try #require(game.commander.equipmentInventory?.items.first { $0.id == tool.id })
    try game.commander.fitEquipment(
      held, at: .laser(.front), expectedRevision: game.commander.equipmentInventory!.revision)
    #expect(!game.commander.hasMiningWorkTool && game.commander.laser(on: .front) == .mining)
    let id = try workToolRock(&game)
    let before = try #require(game.bodies.first { $0.id == id }?.energy)
    game.selectFlightTool(.miningLaser)
    game.fireSelectedFlightTool(delta: 0.05)
    #expect(game.bodies.first { $0.id == id }?.energy == before - LaserKind.mining.damage)
  }

  private func expectRefusalWithoutMutation(_ game: inout Game) {
    let bodies = game.bodies
    let fields = game.miningFields
    let ledger = game.commander.miningLedger
    let crime = game.commander.crimeLedger
    let flight = game.commander.flightSimulation
    let resources = [game.energy, game.laserHeat, game.fireCooldown, game.laserFlash].map(
      \.bitPattern)
    let didFire1 = game.fireMiningWorkTool()
    #expect(!didFire1)
    #expect(game.bodies == bodies && game.miningFields == fields)
    #expect(game.commander.miningLedger == ledger && game.commander.crimeLedger == crime)
    #expect(game.commander.flightSimulation == flight)
    #expect(
      [game.energy, game.laserHeat, game.fireCooldown, game.laserFlash].map(\.bitPattern)
        == resources)
  }

  @Test func nonfiniteResourcesRefuseBeforeRockLedgerEmissionOrResourceMutation() throws {
    for resource in 0..<3 {
      for invalid in [Double.nan, .infinity, -.infinity] {
        var game = try workToolGame()
        try workToolRock(&game)
        switch resource {
        case 0: game.energy = invalid
        case 1: game.laserHeat = invalid
        default: game.fireCooldown = invalid
        }
        expectRefusalWithoutMutation(&game)
      }
    }
  }

  @Test func staleOrMissingAuthoritativeRockRefusesBeforeAllocatingAnAttack() throws {
    for mismatch in 0..<5 {
      var game = try workToolGame()
      try workToolRock(&game)
      let physical = try #require(game.bodies[0].physical)
      let rock = try #require(physical.rock)
      switch mismatch {
      case 0:
        game.miningFields = []
      case 1:
        game.miningFields = game.miningFields.map { field in
          .init(position: field.position, rocks: field.rocks.filter { $0.identity != rock })
        }
      case 2:
        game.bodies[0].physical?.rock = .init(
          system: rock.system, field: UInt16.max, rock: rock.rock)
      case 3:
        game.bodies[0].physical?.rock = .init(
          system: .init(galaxy: (rock.system.galaxy + 1) % 8, system: rock.system.system),
          field: rock.field, rock: rock.rock)
      default:
        game.bodies[0].physical = .init(
          identity: .init(
            system: physical.identity.system, visit: physical.identity.visit + 1,
            entity: physical.identity.entity),
          population: .asteroid, rock: rock)
      }
      expectRefusalWithoutMutation(&game)
    }
  }

  @Test func depletedLedgerCannotBeBypassedByAStalePositiveEnergyRockBody() throws {
    var game = try workToolGame()
    try workToolRock(&game)
    let rock = try #require(game.miningFields.first?.rocks.first)
    let tool = try #require(game.commander.fittedMiningWorkTool)
    for _ in 0..<5 where game.bodies[0].energy > 0 {
      game.fireCooldown = 0
      let didFire2 = game.fireMiningWorkTool()
      #expect(didFire2)
    }
    #expect(game.commander.miningLedger.isDepleted(rock.identity))
    let payloads = game.commander.miningLedger.pendingPayloads
    #expect(!payloads.isEmpty && payloads.count <= MiningLedger.maximumPending)
    #expect(
      payloads.allSatisfy {
        if case .ore(let source, _) = $0.identity { return source == rock.identity }
        return false
      })
    #expect(game.commander.fittedMiningWorkTool?.id == tool.id)
    game.bodies[0].energy = rock.energy
    game.fireCooldown = 0
    expectRefusalWithoutMutation(&game)
    #expect(game.commander.miningLedger.pendingPayloads == payloads)
  }

  @Test func explicitWorkToolCoexistsWithFourNavalFacingsAndAnIndependentCutter() throws {
    var game = try workToolGame()
    let inventory = try #require(game.commander.equipmentInventory)
    #expect(game.commander.hasMiningWorkTool)
    #expect(LaserMount.allCases.allSatisfy { game.commander.laser(on: $0) == .naval })
    #expect(
      inventory.items.filter {
        if case .laser = $0.location?.slot { return true }
        return false
      }.count == 4)
    #expect(inventory.items.contains { $0.location?.slot == .utility(.salvageCutter) })
    try workToolRock(&game)
    let energy = game.energy
    let rockEnergy = game.bodies[0].energy
    let didFire3 = game.fireMiningWorkTool()
    #expect(didFire3)
    #expect(game.bodies[0].energy == rockEnergy - LaserKind.mining.damage)
    #expect(game.energy == energy - 1 && game.laserHeat == 10)
    #expect(game.fireCooldown == LaserKind.mining.firingInterval)
    #expect(LaserMount.allCases.allSatisfy { game.commander.laser(on: $0) == .naval })
    let didFire4 = game.fireMiningWorkTool()
    #expect(!didFire4)
    for _ in 0..<4 where game.bodies[0].energy > 0 {
      game.fireCooldown = 0
      let didFire5 = game.fireMiningWorkTool()
      #expect(didFire5)
    }
    let rock = try #require(game.miningFields.first?.rocks.first)
    #expect(game.commander.miningLedger.isDepleted(rock.identity))
    let payloads = game.commander.miningLedger.pendingPayloads
    let didFire6 = game.fireMiningWorkTool()
    #expect(!payloads.isEmpty && !didFire6)
    #expect(game.commander.miningLedger.pendingPayloads == payloads)
  }

  @Test func workToolCannotFireThroughShipsStationsOrCelestials() throws {
    for obstacle in 0..<3 {
      var game = try workToolGame()
      try workToolRock(&game)
      if obstacle == 2 {
        game.celestials = [.init(kind: .planet, position: .init(0, 0, 250), radius: 100)]
      } else {
        game.bodies.append(
          .init(
            id: 90, hull: obstacle == 0 ? .cobra : .station,
            position: .init(0, 0, 250)))
      }
      let energy = game.energy
      let rockEnergy = game.bodies[0].energy
      let didFire7 = game.fireMiningWorkTool()
      #expect(!didFire7)
      #expect(game.bodies[0].energy == rockEnergy && game.energy == energy)
      #expect(game.bodies.last?.energy == (obstacle == 2 ? rockEnergy : 100))
      #expect(game.commander.legal == 0 && game.commander.kills == 0 && game.laserHeat == 0)
    }
  }

  @Test func installedWorkToolRequiresDeclaredHullSupportAndMiningType() throws {
    var game = try workToolGame()
    let inventory = try #require(game.commander.equipmentInventory)
    let context = EquipmentRuntimeCatalog.context(
      owner: inventory.owner, hull: inventory.activeHull,
      performance: game.commander.performance)
    let naval = try #require(inventory.items.first { $0.location?.slot == .laser(.front) })
    var attempted = inventory
    #expect(throws: OwnedEquipmentError.unsupportedSlot) {
      try attempted.fit(
        expected: naval,
        at: .init(
          hullInstanceID: inventory.activeHull,
          slot: .utility(.miningLaser)), replacing: game.commander.fittedMiningWorkTool,
        expectedRevision: inventory.revision, context: context)
    }
    #expect(attempted == inventory)
    game.commander.shipID = "SH087"
    let didFire8 = game.fireMiningWorkTool()
    #expect(!game.commander.hasMiningWorkTool && !didFire8)
    #expect(throws: OwnedEquipmentError.unsupportedSlot) {
      try inventory.validate(
        context: EquipmentRuntimeCatalog.context(
          owner: inventory.owner, hull: inventory.activeHull,
          performance: game.commander.performance))
    }
  }

  @Test func storingMiningToolRemovesCapabilityWithoutChangingAnyCombatFacing() throws {
    var game = try workToolGame()
    var inventory = try #require(game.commander.equipmentInventory)
    let tool = try #require(game.commander.fittedMiningWorkTool)
    try inventory.store(
      expected: tool, expectedRevision: inventory.revision,
      context: EquipmentRuntimeCatalog.context(
        owner: inventory.owner, hull: inventory.activeHull,
        performance: game.commander.performance))
    game.commander.savedEquipmentInventory = inventory
    let didFire9 = game.fireMiningWorkTool()
    #expect(!game.commander.hasMiningWorkTool && !didFire9)
    #expect(LaserMount.allCases.allSatisfy { game.commander.laser(on: $0) == .naval })
    #expect(inventory.items.first { $0.id == tool.id }?.location == nil)
  }
}

extension MiningWorkToolTests {
  @Test func actualRingExtractionCapacityRefusalKeepsPowerHeatAndAttackAllocation() throws {
    var game = try workToolGame()
    let owner = try #require(game.commander.flightSimulation.player)
    // Retained off-scene ore is a ledger fixture; the refusal below uses the
    // actual fitted work tool, mesh contact and current source, without a fake shot.
    for index in 0..<5 {
      let identity = RockIdentity(system: .init(galaxy: 0, system: 8 + index), field: 6, rock: 2)
      let chunk = try #require(AsteroidBeltDefinition.chunk(for: identity))
      let rock = MiningRock(
        identity: identity, position: .init(100, 200, 300),
        radius: chunk.radius, energy: chunk.energy)
      let allocated = game.commander.flightSimulation.allocateIncident()
      let id = try #require(allocated)
      let incident = CombatIncident(
        id: id, physicalTime: game.commander.flightSimulation.physicalTime,
        origin: .init(emissionID: id, owner: owner, emittedAt: 0, ownerLegalAtEmission: .init()),
        victim: nil, kind: .laser, outcome: .hit, position: rock.position,
        victimLegalBeforeAttack: nil, firstAggressor: nil, victimRole: nil,
        victimIsStation: false, laser: .mining, mount: .front)
      let result = game.commander.miningLedger.hit(
        rock: rock, incident: incident, damage: rock.energy)
      guard case .extracted(let lots) = result else {
        Issue.record("Ore fixture refused")
        return
      }
      try #require(lots.count == 50)
    }
    let rock = try #require(
      game.miningFields.flatMap(\.rocks).first {
        AsteroidBeltDefinition.chunk(for: $0.identity)?.units == 50
      })
    let allocated = game.commander.flightSimulation.allocateActor()
    let actor = try #require(allocated)
    var body = SpaceBody(id: 80, hull: .asteroid, position: .init(0, 0, 500))
    body.physical = .init(identity: actor, population: .asteroid, rock: rock.identity)
    let incidentAllocation = game.commander.flightSimulation.allocateIncident()
    let incidentID = try #require(incidentAllocation)
    let incident = CombatIncident(
      id: incidentID, physicalTime: game.commander.flightSimulation.physicalTime,
      origin: .init(
        emissionID: incidentID, owner: owner, emittedAt: 0, ownerLegalAtEmission: .init()),
      victim: actor, kind: .laser, outcome: .hit, position: rock.position,
      victimLegalBeforeAttack: nil, firstAggressor: nil, victimRole: nil,
      victimIsStation: false, laser: .mining, mount: .front)
    let partial = game.commander.miningLedger.hit(
      rock: rock, incident: incident, damage: rock.energy - 5)
    try #require(partial == .damaged(5))
    body.energy = 5
    game.bodies = [body]
    game.nextBodyID = max(game.nextBodyID, 80)
    game.ensurePhysicalActors()
    try #require(game.commander.miningLedger.pendingPayloads.count == 250)
    let before = game.commander
    let bodies = game.bodies
    let power = [game.energy, game.laserHeat, game.fireCooldown, game.laserFlash]
    let audio = game.dischargeAudio.events
    let fired = game.fireMiningWorkTool()
    #expect(!fired)
    #expect(game.commander == before && game.bodies == bodies)
    #expect([game.energy, game.laserHeat, game.fireCooldown, game.laserFlash] == power)
    #expect(game.dischargeAudio.events == audio)
    #expect(game.message.contains("ORE STORAGE FULL"))
  }
}
