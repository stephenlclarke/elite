import Foundation
import Testing

@testable import EliteCore

private func fractureRock(units: Int = 50, system: Int = 7) throws -> MiningRock {
  for field in UInt16(4)..<8 {
    for index in UInt16(0)..<12 {
      let identity = RockIdentity(
        system: .init(galaxy: 0, system: system), field: field, rock: index)
      if let chunk = AsteroidBeltDefinition.chunk(for: identity), chunk.units == units {
        return .init(
          identity: identity, position: .init(5000, 6000, 7000),
          radius: chunk.radius, energy: chunk.energy)
      }
    }
  }
  throw SaveError.invalidCommander
}

private func fractureIncident(_ id: UInt64, rock: MiningRock, mining: Bool = false)
  -> CombatIncident
{
  .init(
    id: id, physicalTime: Double(id),
    origin: .init(
      emissionID: id, owner: .init(system: rock.identity.system, visit: 1, entity: 1),
      emittedAt: Double(id), ownerLegalAtEmission: .init()),
    victim: nil, kind: .laser, outcome: .hit, position: rock.position,
    victimLegalBeforeAttack: nil, firstAggressor: nil, victimRole: nil, victimIsStation: false,
    laser: mining ? .mining : .pulse, mount: .front)
}

private let fractureMotion = AsteroidMotion(
  position: .init(8000, 9000, 10000), velocity: .init(7, -3, 11), physicalTime: 1)

struct AsteroidFragmentationTests {
  @Test(arguments: AsteroidBeltDefinition.chunkUnits)
  func massMomentumAndStrictYieldUseOriginalBirthMass(units: Int) throws {
    let rock = try fractureRock(units: units)
    let chunk = try #require(AsteroidBeltDefinition.chunk(for: rock.identity))
    var ledger = MiningLedger()
    let hit = ledger.hit(
      rock: rock, incident: fractureIncident(1, rock: rock),
      damage: rock.energy, motion: fractureMotion)
    #expect(hit == .damaged(rock.energy))
    let born = try #require(ledger.breakups[rock.identity])
    let kg = chunk.content.commodity.unit == "t" ? 1000.0 : 1.0
    #expect(born.birthMassKg == Double(units) * kg)
    #expect(born.aggregateMassKg == born.birthMassKg && born.motion == fractureMotion)
    #expect(born.maximumCollectibleUnits == (units - 1) / 20)
    // Partial work survives an intervening ordinary re-shatter, without a fresh allowance.
    _ = ledger.hit(
      rock: rock, incident: fractureIncident(2, rock: rock, mining: true),
      damage: rock.energy / 2, motion: fractureMotion)
    _ = ledger.hit(
      rock: rock, incident: fractureIncident(3, rock: rock),
      damage: rock.energy * 10, motion: fractureMotion)
    ledger = try JSONDecoder().decode(MiningLedger.self, from: JSONEncoder().encode(ledger))
    _ = ledger.hit(
      rock: rock, incident: fractureIncident(4, rock: rock, mining: true),
      damage: rock.energy / 2 + 1, motion: fractureMotion)
    let worked = try #require(ledger.breakups[rock.identity])
    let pods = ledger.pendingPayloads
    let podMass = pods.reduce(0.0) { $0 + Double($1.amount.quantity) * kg }
    #expect(podMass < born.birthMassKg * 0.05)
    #expect(worked.aggregateMassKg + podMass == born.birthMassKg)
    let momentum =
      worked.motion.velocity * worked.aggregateMassKg
      + pods.reduce(Vector3(0, 0, 0)) { $0 + $1.velocity * (Double($1.amount.quantity) * kg) }
    #expect((momentum - fractureMotion.velocity * born.birthMassKg).length < 1e-7)
    _ = ledger.hit(
      rock: rock, incident: fractureIncident(5, rock: rock, mining: true),
      damage: 100000, motion: fractureMotion)
    #expect(ledger.pendingPayloads == pods && ledger.valid)
    ledger.depart(system: rock.identity.system)
    #expect(ledger.pendingPayloads == pods && ledger.valid)
  }

  @Test func destroyedRecoverableBecomesNonCollectiblePhysicalCustody() throws {
    let rock = try fractureRock()
    var ledger = MiningLedger()
    _ = ledger.hit(
      rock: rock, incident: fractureIncident(1, rock: rock),
      damage: rock.energy, motion: fractureMotion)
    _ = ledger.hit(
      rock: rock, incident: fractureIncident(2, rock: rock, mining: true),
      damage: rock.energy, motion: fractureMotion)
    let pod = try #require(ledger.pendingPayloads.first)
    let before = ledger.pendingPayloads
    let destroyed = ledger.destroy(payload: pod.identity)
    let duplicate = ledger.destroy(payload: pod.identity)
    #expect(destroyed && !duplicate && ledger.isRubble(pod.identity))
    #expect(ledger.pendingPayloads == before)
    var cargo = Array(repeating: 0, count: 17)
    let refused = ledger.collect(
      payload: pod.identity, into: &cargo, freeTonnes: 100,
      hasScoops: true, approachAllowed: true, protection: .init())
    #expect(refused == .refused(.unavailable) && cargo.allSatisfy { $0 == 0 })
    ledger.depart(system: rock.identity.system)
    let restored = try JSONDecoder().decode(MiningLedger.self, from: JSONEncoder().encode(ledger))
    #expect(restored == ledger && restored.valid && restored.pendingPayloads == before)
  }

  @Test func capacityAndInvalidMotionRetainParentWithoutAllocatingOrDepleting() throws {
    var ledger = MiningLedger()
    var event: UInt64 = 1
    for system in 0..<MiningLedger.maximumPartial {
      let rock = try fractureRock(system: system)
      _ = ledger.hit(
        rock: rock, incident: fractureIncident(event, rock: rock),
        damage: rock.energy, motion: fractureMotion)
      event += 1
    }
    let next = try fractureRock(system: 256)
    let before = ledger
    let refused = ledger.hit(
      rock: next, incident: fractureIncident(event, rock: next),
      damage: next.energy, motion: fractureMotion)
    #expect(refused == .capacityRefused && ledger == before && !ledger.isDepleted(next.identity))
    var empty = MiningLedger()
    var invalid = fractureMotion
    invalid.velocity = .init(.infinity, 0, 0)
    let invalidResult = empty.hit(
      rock: next, incident: fractureIncident(1, rock: next),
      damage: next.energy, motion: invalid)
    #expect(invalidResult == .capacityRefused && empty == MiningLedger())
    // A context-free ordinary hit cannot silently invent a stationary replacement.
    let missing = empty.hit(
      rock: next, incident: fractureIncident(1, rock: next), damage: next.energy)
    #expect(missing == .capacityRefused && empty == MiningLedger())
  }
}

private func moveFractureObserver(_ game: inout Game, to position: Vector3) {
  let shift = game.commander.flightSimulation.pose.shipVector(
    position - game.commander.flightSimulation.pose.position)
  game.commander.flightSimulation.pose.position = position
  for index in game.bodies.indices {
    game.bodies[index].position = game.bodies[index].position - shift
  }
  for index in game.celestials.indices {
    game.celestials[index].position = game.celestials[index].position - shift
  }
}

private func nativeFractureGame() throws -> (Game, MiningRock, Int) {
  var game = Game(executive: false)
  game.commander.shipID = "SH023"
  game.commander.fuel = game.commander.fuelCapacity
  game.energy = game.commander.performance.energy
  game.frontShield = game.commander.shieldCapacity
  game.rearShield = game.commander.rearShieldCapacity
  try #require(
    game.commander.valid && game.commander.performance.workTools?.contains(.miningLaser) == true)
  try game.commander.prepareEquipment(legacy: false)
  try game.commander.grantEquipment(
    LaserKind.mining.equipmentName, at: .utility(.miningLaser),
    provenance: .grant("native breakup fixture"))
  game.launch()
  game.speed = 0
  let rock = try #require(
    game.miningFields.flatMap(\.rocks).first {
      (AsteroidBeltDefinition.chunk(for: $0.identity)?.units ?? 0) > 20
    })
  game.bodies = []
  game.commander.npcPersistence = .init()
  game.commander.resetWantedCareerBindings(system: game.systemIdentity)
  game.miningFields = [.init(position: rock.position, rocks: [rock])]
  let position = rock.position - Vector3(0, 0, 500)
  let shift = game.commander.flightSimulation.pose.shipVector(
    position - game.commander.flightSimulation.pose.position)
  game.commander.flightSimulation.pose.position = position
  for index in game.celestials.indices {
    game.celestials[index].position = game.celestials[index].position - shift
  }
  game.activateNearbyMiningFields()
  let body = try #require(game.bodies.first { $0.physical?.rock == rock.identity })
  return (game, rock, body.id)
}

private func nativeFractureHit(
  _ game: inout Game, bodyID: Int, damage: Double,
  mining: Bool = false
) throws {
  let body = try #require(game.bodies.first { $0.id == bodyID })
  let player = try #require(game.commander.flightSimulation.player)
  let allocatedOrigin = game.makeAttackOrigin(owner: player)
  let origin = try #require(allocatedOrigin)
  let hit = try #require(
    GameplayRaycast.nearest(
      origin: .init(0, 0, 0), direction: body.position.unit, maxDistance: 2000,
      bodies: game.bodies,
      meshOverrides: Dictionary(
        uniqueKeysWithValues: game.bodies.map {
          ($0.id, game.gameplayMesh(for: $0))
        })))
  try #require(hit.target == .body(bodyID))
  let incident = game.applyCombatHit(
    hit, origin: origin, kind: .laser, damage: damage,
    laser: mining ? .mining : .pulse)
  #expect(incident != nil)
  game.commander.crimeLedger.finishEmission(origin.emissionID)
}

extension AsteroidFragmentationTests {
  @Test func actualNativeHitKeepsMassMovingSolidAndRebindsAfterAdmissionRefusal() throws {
    var (game, rock, bodyID) = try nativeFractureGame()
    let index = try #require(game.bodies.firstIndex { $0.id == bodyID })
    let actor = try #require(game.bodies[index].physical?.identity)
    let velocity = Vector3(4, -2, 7)
    game.bodies[index].physical?.velocity = velocity
    let nextActor = game.commander.flightSimulation.nextActor
    try nativeFractureHit(&game, bodyID: bodyID, damage: rock.energy + 1)
    #expect(game.commander.flightSimulation.nextActor == nextActor)
    game.resolveDestroyed()
    let aggregate = try #require(game.bodies.first { $0.id == bodyID })
    #expect(aggregate.energy > 0 && aggregate.physical?.identity == actor)
    #expect(aggregate.physical?.velocity == velocity)
    let original = try #require(game.commander.miningLedger.breakups[rock.identity])
    #expect(original.birthMassKg == rock.birthMassKg && original.binding == actor)
    let mesh = game.gameplayMesh(for: aggregate)
    #expect(!mesh.vertices.isEmpty && !mesh.faces.isEmpty)
    game.bodies[index].position = game.bodies[index].position + .init(1, 2, 3)
    game.persistOrePoses()
    let motion = try #require(game.commander.miningLedger.breakups[rock.identity]?.motion)
    #expect(
      motion.position
        == game.commander.flightSimulation.pose.systemPoint(
          game.bodies[index].position))
    #expect(motion.velocity == velocity)
    game.commander.miningLedger.cull(actor: actor)
    game.bodies.removeAll { $0.id == bodyID }
    // Real native player-clearance refusal retains the entire saved aggregate.
    let observer = game.commander.flightSimulation.pose.position
    let beforeRefusal = game.commander.miningLedger
    moveFractureObserver(&game, to: motion.position)
    game.activateNearbyMiningFields()
    // Native admission also restores absent RRS bodies before testing this rock's clearance.
    #expect(!game.bodies.contains { $0.physical?.rock == rock.identity })
    #expect(game.bodies.allSatisfy { $0.nativeStationIdentity != nil })
    #expect(game.commander.miningLedger == beforeRefusal)
    moveFractureObserver(&game, to: observer)
    game.activateNearbyMiningFields()
    let restored = try #require(game.bodies.first { $0.physical?.rock == rock.identity })
    #expect(restored.physical?.identity != actor && restored.energy > 0)
    #expect(restored.physical?.velocity == velocity)
    #expect(game.commander.flightSimulation.pose.systemPoint(restored.position) == motion.position)
    let current = game.commander.miningLedger
    let decoded = try JSONDecoder().decode(MiningLedger.self, from: JSONEncoder().encode(current))
    #expect(decoded == current && decoded.valid)
    let commander = game.commander
    let currentCommander = try JSONDecoder().decode(
      Commander.self, from: JSONEncoder().encode(commander))
    #expect(currentCommander == commander)
    #expect(currentCommander.miningLedger == current)
    try nativeFractureHit(&game, bodyID: restored.id, damage: 100000, mining: true)
    let count = game.commander.miningLedger.pendingPayloads.count
    #expect(count == original.maximumCollectibleUnits)
    for _ in 0..<3 {
      try nativeFractureHit(&game, bodyID: restored.id, damage: 100000)
      try nativeFractureHit(&game, bodyID: restored.id, damage: 100000, mining: true)
    }
    #expect(game.commander.miningLedger.pendingPayloads.count == count)
    let reservedBody = try #require(game.bodies.first { $0.id == restored.id })
    #expect(game.asteroidDebrisMassKg(reservedBody) == original.birthMassKg)
    game.admitPendingOre()
    let admittedRoot = try #require(game.bodies.first { $0.id == restored.id })
    let residualKg = try #require(game.asteroidDebrisMassKg(admittedRoot))
    let admittedMass = game.bodies.compactMap { body -> Double? in
      guard let payload = body.physical?.payload,
        let lot = game.commander.miningLedger.pendingPayloads.first(where: {
          $0.identity == payload
        })
      else { return nil }
      return Double(lot.amount.quantity) * AsteroidBreakup.kilogramsPerUnit(lot.amount.commodity)
    }.reduce(0, +)
    #expect(residualKg + admittedMass == original.birthMassKg)
    let ore = try #require(game.bodies.first { $0.physical?.payload != nil })
    let oreActor = try #require(ore.physical?.identity)
    let payload = try #require(ore.physical?.payload)
    let oreWorld = game.commander.flightSimulation.pose.systemPoint(ore.position)
    moveFractureObserver(&game, to: oreWorld - Vector3(0, 500, 0))
    try nativeFractureHit(&game, bodyID: ore.id, damage: 100000)
    game.resolveDestroyed()
    let rubble = try #require(game.bodies.first { $0.id == ore.id })
    #expect(rubble.energy > 0 && rubble.hull == .asteroid)
    #expect(rubble.physical?.identity == oreActor && rubble.physical?.velocity == velocity)
    #expect(game.commander.miningLedger.isRubble(payload))
    #expect(game.asteroidDebrisMassKg(rubble) != nil)
    #expect(game.commander.miningLedger.pendingPayloads.count == count)
  }
}

extension AsteroidFragmentationTests {
  @Test func finitePoolRefusesAtomicallyWhenPendingCapacityCannotHoldItsUnits() throws {
    var ledger = MiningLedger()
    for system in 0..<5 {
      let rock = try fractureRock(system: system)
      _ = ledger.hit(
        rock: rock,
        incident: fractureIncident(UInt64(system + 1), rock: rock, mining: true), damage: 10000)
    }
    let five = try fractureRock(units: 5, system: 6)
    _ = ledger.hit(
      rock: five, incident: fractureIncident(6, rock: five, mining: true), damage: 10000)
    try #require(ledger.pendingPayloads.count == 255)
    let root = try fractureRock()
    _ = ledger.hit(
      rock: root, incident: fractureIncident(7, rock: root),
      damage: root.energy, motion: fractureMotion)
    let before = ledger
    let refused = ledger.hit(
      rock: root, incident: fractureIncident(8, rock: root, mining: true),
      damage: root.energy, motion: fractureMotion)
    #expect(refused == .capacityRefused && ledger == before)
    let discardedOrdinaryOre = try #require(ledger.pendingPayloads.first)
    let freed = ledger.destroy(payload: discardedOrdinaryOre.identity)
    try #require(freed)
    let retried = ledger.hit(
      rock: root, incident: fractureIncident(9, rock: root, mining: true),
      damage: root.energy, motion: fractureMotion)
    #expect(retried == .damaged(root.energy) && ledger.pendingPayloads.count == 256)
    #expect(ledger.breakups[root.identity]?.issuedUnits == 2 && ledger.valid)
  }

  @Test func commodityMassUnitsAndCollectedPoolSurviveFurtherBreakup() throws {
    #expect(AsteroidBreakup.kilogramsPerUnit(.minerals) == 1000)
    #expect(AsteroidBreakup.kilogramsPerUnit(.alloys) == 1000)
    #expect(AsteroidBreakup.kilogramsPerUnit(.gold) == 1)
    #expect(AsteroidBreakup.kilogramsPerUnit(.platinum) == 1)
    let root = try fractureRock()
    var ledger = MiningLedger()
    _ = ledger.hit(
      rock: root, incident: fractureIncident(1, rock: root),
      damage: root.energy, motion: fractureMotion)
    _ = ledger.hit(
      rock: root, incident: fractureIncident(2, rock: root, mining: true),
      damage: root.energy, motion: fractureMotion)
    let pod = try #require(ledger.pendingPayloads.first)
    var cargo = Array(repeating: 0, count: 17)
    let receipt = ledger.collect(
      payload: pod.identity, into: &cargo, freeTonnes: 100,
      hasScoops: true, approachAllowed: true, protection: .init())
    #expect(receipt == .collected(pod.amount))
    ledger = try JSONDecoder().decode(MiningLedger.self, from: JSONEncoder().encode(ledger))
    _ = ledger.hit(
      rock: root, incident: fractureIncident(3, rock: root),
      damage: 10000, motion: fractureMotion)
    _ = ledger.hit(
      rock: root, incident: fractureIncident(4, rock: root, mining: true),
      damage: 10000, motion: fractureMotion)
    #expect(ledger.pendingPayloads.count == 1)
    #expect(cargo[pod.amount.commodity.rawValue] == 1)
    #expect(ledger.breakups[root.identity]?.collectedUnits == 1 && ledger.valid)
    var invalid = ledger
    invalid.breakups[root.identity]?.aggregateMassKg += 1
    let encoded = try JSONEncoder().encode(invalid)
    #expect(throws: (any Error).self) { try JSONDecoder().decode(MiningLedger.self, from: encoded) }
  }
}

private func twoReservedFractureUnits() throws -> (MiningLedger, MiningRock, EncounterContext) {
  let root = try fractureRock()
  var ledger = MiningLedger()
  _ = ledger.hit(
    rock: root, incident: fractureIncident(1, rock: root),
    damage: root.energy, motion: fractureMotion)
  _ = ledger.hit(
    rock: root, incident: fractureIncident(2, rock: root, mining: true),
    damage: root.energy, motion: fractureMotion)
  let (game, _, _) = try nativeFractureGame()
  let context = try #require(game.gameplayContext())
  return (ledger, root, context)
}

private func fractureBudgetContext(_ source: EncounterContext, budget: AdmissionBudget)
  -> EncounterContext
{
  .init(
    system: source.system, seed: source.seed, government: source.government,
    visit: source.visit, revision: source.revision, physicalTime: source.physicalTime,
    anchors: source.anchors, player: source.player, actors: source.actors,
    protection: source.protection, budget: budget, perceptionRadius: source.perceptionRadius)
}

extension AsteroidFragmentationTests {
  @Test func boundAndCollectedUnitsRequireTheirOwnMaterializationMarkers() throws {
    var (ledger, root, context) = try twoReservedFractureUnits()
    let requests = ledger.pendingSpawnRequests(
      context: context,
      fields: [.init(position: root.position, rocks: [root])])
    try #require(requests.count == 2)
    let actors = requests.enumerated().map { index, request in
      ActorIdentity(
        system: request.identity.system, visit: request.identity.visit,
        entity: UInt64(index + 100))
    }
    ledger.acknowledge(
      receipts: zip(requests, actors).map {
        .init(request: $0.0.identity, actor: $0.1, refusal: nil)
      })
    let first = try #require(requests.first?.payload)
    guard case .ore(_, let fragment) = first else { throw SaveError.invalidCommander }
    try #require(ledger.valid)
    var malformedBound = ledger
    malformedBound.breakups[root.identity]?.materialized.remove(fragment)
    let boundData = try JSONEncoder().encode(malformedBound)
    #expect(!malformedBound.valid)
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(MiningLedger.self, from: boundData)
    }
    // A genuinely materialized child remains so after culling its current native actor.
    ledger.cull(actor: actors[0])
    let culled = try JSONDecoder().decode(MiningLedger.self, from: JSONEncoder().encode(ledger))
    #expect(culled == ledger && culled.valid)
    var cargo = Array(repeating: 0, count: 17)
    let expectedAmount = try #require(ledger.pendingPayloads.first { $0.identity == first }).amount
    let receipt = ledger.collect(
      payload: first, into: &cargo, freeTonnes: 100,
      hasScoops: true, approachAllowed: true, protection: .init())
    try #require(receipt == .collected(expectedAmount))
    try #require(ledger.valid)
    // The sibling marker cannot stand in for the collected child's marker.
    ledger.breakups[root.identity]?.materialized.remove(fragment)
    let collectedData = try JSONEncoder().encode(ledger)
    #expect(!ledger.valid)
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(MiningLedger.self, from: collectedData)
    }
  }

  @Test func rubbleAndCargoUseSeparatePopulationQuotasAndOutstandingOffers() throws {
    let (source, root, context) = try twoReservedFractureUnits()
    let first = try #require(source.pendingPayloads.first?.identity)
    var ledger = source
    let converted = ledger.destroy(payload: first)
    try #require(converted)
    var fullCargo = AdmissionBudget()
    fullCargo.active[.cargo] = PopulationClass.cargo.maximum
    fullCargo.total = PopulationClass.cargo.maximum
    let fields = [MiningField(position: root.position, rocks: [root])]
    let cargoBlocked = ledger.pendingSpawnRequests(
      context: fractureBudgetContext(context, budget: fullCargo), fields: fields)
    #expect(cargoBlocked.count == 1 && cargoBlocked.first?.population == .asteroid)
    #expect(cargoBlocked.first?.payload == first)
    let duplicate = ledger.pendingSpawnRequests(
      context: fractureBudgetContext(context, budget: fullCargo), fields: fields)
    #expect(duplicate.isEmpty)
    ledger.acknowledge(
      receipts: cargoBlocked.map {
        .init(request: $0.identity, actor: nil, refusal: .populationLimit)
      })
    var fullAsteroids = AdmissionBudget()
    fullAsteroids.active[.asteroid] = PopulationClass.asteroid.maximum
    fullAsteroids.total = PopulationClass.asteroid.maximum
    let asteroidBlocked = ledger.pendingSpawnRequests(
      context: fractureBudgetContext(context, budget: fullAsteroids), fields: fields)
    #expect(asteroidBlocked.count == 1 && asteroidBlocked.first?.population == .cargo)
    #expect(asteroidBlocked.first?.payload != first)
    // One reserved offer consumes its own population slot, not the other population's slot.
    var oneEach = AdmissionBudget()
    oneEach.active[.cargo] = PopulationClass.cargo.maximum - 1
    oneEach.active[.asteroid] = PopulationClass.asteroid.maximum - 1
    oneEach.total = oneEach.active.values.reduce(0, +)
    let onlyRubble = ledger.pendingSpawnRequests(
      context: fractureBudgetContext(context, budget: oneEach), fields: fields)
    #expect(onlyRubble.count == 1 && onlyRubble.first?.population == .asteroid)
    #expect(ledger.valid)
  }
}

private func nativeContactOutcome(_ result: AsteroidContactStepResult) -> String {
  switch result {
  case .refused(let reason): ".refused(\(reason))"
  case .advanced(nil): ".advanced(nil)"
  case .advanced(let receipt?):
    ".advanced(source=\(receipt.source.entity), target=\(receipt.target.entity), incident=\(receipt.incident))"
  }
}

private func moveNativeContactEndpoints(_ game: inout Game, delta: Double) {
  let pose = game.commander.flightSimulation.pose
  for index in game.bodies.indices {
    guard let physical = game.bodies[index].physical, physical.spawnIdentity != nil,
      physical.ordnance == nil, game.bodies[index].scriptNPC == nil
    else { continue }
    game.bodies[index].position =
      game.bodies[index].position + pose.shipVector(physical.velocity) * delta
  }
}

extension AsteroidFragmentationTests {
  @Test func nativeMovingDebrisDamagesPlayerAndRetainsEqualOppositeMomentum() throws {
    var (game, rock, bodyID) = try nativeFractureGame()
    try nativeFractureHit(&game, bodyID: bodyID, damage: rock.energy + 1)
    let index = try #require(game.bodies.firstIndex { $0.id == bodyID })
    game.bodies[index].rotation = 0
    game.bodies[index].orientation = .init()
    game.bodies[index].position = .init(0, 0, 500)
    let incoming = Vector3(0, 0, -6000)
    game.bodies[index].physical?.velocity = incoming
    game.persistOrePoses()
    let sourceKg = try #require(game.asteroidDebrisMassKg(game.bodies[index]))
    let playerKg = AsteroidImpactPolicy.massKg(hull: .cobra)
    let oldVelocity = game.flightWorldVelocity
    let oldResources = game.energy + game.frontShield + game.rearShield
    let cash = game.commander.credits
    let kills = game.commander.kills
    game.commander.flightSimulation.advancePhysicalTime(0.1)
    let capturedFrame = game.beginAsteroidContactStep()
    let frame = try #require(capturedFrame)
    moveNativeContactEndpoints(&game, delta: 0.1)
    let result = game.completeAsteroidContactStep(frame, delta: 0.1)
    guard case .advanced(let actualReceipt) = result, let receipt = actualReceipt else {
      Issue.record(
        "Actual native moving debris did not admit the player impact: \(nativeContactOutcome(result))"
      )
      return
    }
    #expect(receipt.damage > 0 && receipt.target == game.commander.flightSimulation.player)
    #expect(game.energy + game.frontShield + game.rearShield < oldResources)
    let source = try #require(game.bodies.first { $0.id == bodyID })
    let velocity = try #require(source.physical?.velocity)
    let before = incoming * sourceKg + oldVelocity * playerKg
    let after = velocity * sourceKg + game.flightWorldVelocity * playerKg
    #expect((after - before).length < 1e-6)
    #expect(source.energy > 0 && game.asteroidDebrisMassKg(source) == sourceKg)
    #expect(game.commander.credits == cash && game.commander.kills == kills)
    let stored = try #require(game.commander.miningLedger.breakups[rock.identity])
    #expect(stored.motion.velocity == velocity)
    let encoded = try JSONEncoder().encode(game.commander.miningLedger)
    let restored = try JSONDecoder().decode(MiningLedger.self, from: encoded)
    #expect(restored == game.commander.miningLedger && restored.valid)
    let committed = game.commander
    let pose = game.commander.flightSimulation.pose
    let replay = game.completeAsteroidContactStep(frame, delta: 0.1)
    guard case .refused = replay else {
      Issue.record("Consumed contact frame replayed")
      return
    }
    #expect(game.commander == committed && game.commander.flightSimulation.pose == pose)
  }

  @Test(arguments: [0.0, -3000.0])
  func nativeMovingDebrisUsesNPCShieldsAndNativeDeathWithoutPlayerReward(targetVelocity: Double)
    throws
  {
    var (game, rock, bodyID) = try nativeFractureGame()
    try nativeFractureHit(&game, bodyID: bodyID, damage: rock.energy + 1)
    let sourceIndex = try #require(game.bodies.firstIndex { $0.id == bodyID })
    let context = try #require(game.gameplayContext())
    let spawnSequence = game.commander.flightSimulation.allocateSpawn()
    let sequence = try #require(spawnSequence)
    var npc = NPCState(role: .trader, origin: context.system, destination: context.system)
    npc.resources = NPCResources.stock(game.commander.performance)
    npc.cargoProvenance = .recorded
    npc.ordinaryCargo = []
    let request = SpawnRequest(
      identity: .init(
        system: context.system, visit: context.visit,
        sequence: sequence, member: 0, producer: .ambient), population: .civilian, hull: .cobra,
      position: context.player.position + Vector3(0, 0, 1500), orientation: .init(),
      velocity: .init(0, 0, targetVelocity), npc: npc, rock: nil, payload: nil, priority: .ordinary)
    let receipts = game.admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit,
        revision: context.revision, batches: [.init(requests: [request], atomic: true)], intents: []
      ))
    let targetActor = try #require(receipts.first?.actor)
    let targetBefore = try #require(game.bodies.first { $0.physical?.identity == targetActor })
    game.bodies[sourceIndex].rotation = 0
    game.bodies[sourceIndex].physical?.velocity = .init(0, 0, 16000)
    game.persistOrePoses()
    let sourceKg = try #require(game.asteroidDebrisMassKg(game.bodies[sourceIndex]))
    let targetMass = AsteroidImpactPolicy.massKg(hull: targetBefore.hull)
    let incomingMomentum =
      Vector3(0, 0, 16000) * sourceKg
      + Vector3(0, 0, targetVelocity) * targetMass
    let targetEndPoint = game.commander.flightSimulation.pose.systemPoint(
      targetBefore.position + Vector3(0, 0, targetVelocity * 0.1))
    let cash = game.commander.credits
    let kills = game.commander.kills
    game.commander.flightSimulation.advancePhysicalTime(0.1)
    let capturedFrame = game.beginAsteroidContactStep()
    let frame = try #require(capturedFrame)
    moveNativeContactEndpoints(&game, delta: 0.1)
    let result = game.completeAsteroidContactStep(frame, delta: 0.1)
    guard case .advanced(let packet) = result, let receipt = packet, receipt.target == targetActor
    else {
      Issue.record(
        "Actual native moving debris did not admit the NPC impact: \(nativeContactOutcome(result))")
      return
    }
    let target = try #require(game.bodies.first { $0.physical?.identity == targetActor })
    let source = try #require(game.bodies.first { $0.id == bodyID })
    let a = try #require(source.physical?.velocity)
    let b = try #require(target.physical?.velocity)
    let targetKg = AsteroidImpactPolicy.massKg(hull: target.hull)
    #expect((a * sourceKg + b * targetKg - incomingMomentum).length < 1e-6)
    let before =
      targetBefore.energy + (targetBefore.physical?.npc?.resources?.frontShield ?? 0)
      + (targetBefore.physical?.npc?.resources?.rearShield ?? 0)
    let after =
      target.energy + (target.physical?.npc?.resources?.frontShield ?? 0)
      + (target.physical?.npc?.resources?.rearShield ?? 0)
    #expect(after < before)
    if targetVelocity < 0 {
      #expect(receipt.point.z > targetEndPoint.z)
      #expect(
        target.physical?.npc?.resources?.frontShield
          == targetBefore.physical?.npc?.resources?.frontShield)
      let rear = try #require(target.physical?.npc?.resources?.rearShield)
      let originalRear = try #require(targetBefore.physical?.npc?.resources?.rearShield)
      #expect(rear < originalRear)
    }
    if target.energy <= 0 { #expect(target.physical?.deathIncidentID != nil) }
    #expect(game.commander.credits == cash && game.commander.kills == kills)
    #expect(source.energy > 0)
  }

  @Test func staleNativeContactFrameCannotRewindAnotherVisitOrForgeAnEffect() throws {
    var (game, rock, bodyID) = try nativeFractureGame()
    try nativeFractureHit(&game, bodyID: bodyID, damage: rock.energy + 1)
    let capturedFrame = game.beginAsteroidContactStep()
    let frame = try #require(capturedFrame)
    game.commander.flightSimulation.advancePhysicalTime(0.1)
    let before = game.commander
    let bodies = game.bodies
    let result = game.completeAsteroidContactStep(frame, delta: 0.1)
    guard case .refused = result else {
      Issue.record("Stale native frame was admitted")
      return
    }
    #expect(game.commander == before && game.bodies == bodies)
  }
}

extension AsteroidFragmentationTests {
  @Test func refusedActualAcceleratingRotatingWorkMoveRestoresAllMotionForResume() throws {
    var (game, rock, bodyID) = try nativeFractureGame()
    try nativeFractureHit(&game, bodyID: bodyID, damage: rock.energy + 1)
    let velocity = Vector3(3, 4, 5)
    let acceleration = Vector3(20, 0, 0)
    let omega = Vector3(0, 0, 0.25)
    game.workBraking = .init(velocity: velocity, angularVelocity: omega)
    game.autoPilot.setApproachVelocity(.init(7, 8, 9))
    game.manualResidualFlight = true
    game.speed = 7
    let start = game.commander.flightSimulation.pose
    var end = start
    end.position = start.position + velocity * 0.1 + acceleration * 0.005
    end.orientation.rotate(pitch: 0, roll: 0.025, yaw: 0)
    let motion = HullSceneMotion(
      start: start, end: end, initialVelocity: velocity,
      acceleration: acceleration, worldAngularVelocity: omega, duration: 0.1,
      playerRadius: game.commander.playerMesh.vertices.map(\.length).max() ?? 80)
    game.approvedWorkMotion = motion
    game.commander.flightSimulation.advancePhysicalTime(0.1)
    let commander = game.commander
    let bodies = game.bodies
    let pilotVelocity = game.autoPilot.velocity
    let capturedFrame = game.beginAsteroidContactStep()
    let frame = try #require(capturedFrame)
    let moved = game.moveWorkFrame(delta: 0.1)
    try #require(moved)
    #expect(game.workBraking?.velocity == velocity + acceleration * 0.1)
    #expect(game.autoPilot.velocity == .init(0, 0, 0) && game.approvedWorkMotion == nil)
    let index = try #require(game.bodies.firstIndex { $0.id == bodyID })
    // Force the actual post-movement snapshot refusal, before any impact/resource write.
    game.bodies[index].position.x = .nan
    let result = game.completeAsteroidContactStep(frame, delta: 0.1)
    guard case .refused = result else {
      Issue.record("Invalid moved snapshot was admitted")
      return
    }
    #expect(game.commander == commander && game.bodies == bodies)
    #expect(game.workBraking?.velocity == velocity && game.workBraking?.angularVelocity == omega)
    #expect(
      game.autoPilot.velocity == pilotVelocity && game.speed == 7 && game.manualResidualFlight)
    #expect(game.approvedWorkMotion == motion && game.lastAppliedWorkMotion == nil)
    #expect(game.flightWorldVelocity == velocity)
    game.paused = false
    let resumed = game.moveWorkFrame(delta: 0.1)
    #expect(resumed && game.commander.flightSimulation.pose == end)
    #expect(game.workBraking?.velocity == velocity + acceleration * 0.1)
  }

  @Test func actualManualRotationRefusalPreservesWorldMomentum() throws {
    var (game, rock, bodyID) = try nativeFractureGame()
    try nativeFractureHit(&game, bodyID: bodyID, damage: rock.energy + 1)
    game.manualResidualFlight = true
    game.speed = 0
    game.autoPilot.setApproachVelocity(.init(12, 3, 7))
    let velocity = game.flightWorldVelocity
    let pose = game.commander.flightSimulation.pose
    let index = try #require(game.bodies.firstIndex { $0.id == bodyID })
    game.bodies[index].physical?.velocity = .init(.infinity, 0, 0)
    var controls = Controls()
    controls.pitch = 0.4
    controls.roll = 0.2
    controls.yaw = 0.3
    game.tick(delta: 0.1, controls: controls)
    #expect(game.paused && game.commander.flightSimulation.pose == pose)
    #expect((game.flightWorldVelocity - velocity).length < 1e-10)
    #expect(game.bodies.first { $0.id == bodyID }?.position.finite == true)
  }

  @Test func collisionDefersOreHullGrowthUntilActualSafeReadmission() throws {
    var (game, rock, bodyID) = try nativeFractureGame()
    try nativeFractureHit(&game, bodyID: bodyID, damage: rock.energy + 1)
    try nativeFractureHit(&game, bodyID: bodyID, damage: 100000, mining: true)
    game.admitPendingOre()
    let oreIndex = try #require(game.bodies.firstIndex { $0.physical?.payload != nil })
    let payload = try #require(game.bodies[oreIndex].physical?.payload)
    let oreID = game.bodies[oreIndex].id
    let oreActor = try #require(game.bodies[oreIndex].physical?.identity)
    let source = try #require(game.bodies.firstIndex { $0.id == bodyID })
    game.bodies[source].rotation = 0
    game.bodies[source].physical?.velocity = .init(0, 0, 16000)
    game.bodies[oreIndex].position = .init(0, 0, 1500)
    game.bodies[oreIndex].physical?.velocity = .init(0, 0, 0)
    game.persistOrePoses()
    let oldMesh = game.gameplayMesh(for: game.bodies[oreIndex])
    game.commander.flightSimulation.advancePhysicalTime(0.1)
    let capturedFrame = game.beginAsteroidContactStep()
    let frame = try #require(capturedFrame)
    moveNativeContactEndpoints(&game, delta: 0.1)
    let result = game.completeAsteroidContactStep(frame, delta: 0.1)
    guard case .advanced(let receipt) = result, receipt?.target == oreActor else {
      Issue.record("Native ore collision did not commit: \(nativeContactOutcome(result))")
      return
    }
    let rubble = try #require(game.bodies.first { $0.id == oreID })
    let mesh = game.gameplayMesh(for: rubble)
    #expect(game.commander.miningLedger.isRubble(payload))
    #expect(rubble.hull == .cargo && rubble.physical?.population == .cargo)
    #expect(mesh.vertices == oldMesh.vertices && mesh.faces == oldMesh.faces)
    game.commander.miningLedger.cull(actor: oreActor)
    game.bodies.removeAll { $0.id == oreID }
    game.admitPendingOre()
    let admitted = try #require(game.bodies.first { $0.physical?.payload == payload })
    #expect(admitted.physical?.identity != oreActor && admitted.hull == .asteroid)
    #expect(admitted.physical?.population == .asteroid)
  }

  @Test func fastCrossingPlayerUsesProvedContactFrontBankRatherThanEndPoseRearBank() throws {
    var (game, rock, bodyID) = try nativeFractureGame()
    try nativeFractureHit(&game, bodyID: bodyID, damage: rock.energy + 1)
    let index = try #require(game.bodies.firstIndex { $0.id == bodyID })
    game.bodies[index].position = .init(0, 0, 1500)
    game.bodies[index].rotation = 0
    game.bodies[index].physical?.velocity = .init(0, 0, -10000)
    let start = game.commander.flightSimulation.pose
    var end = start
    end.position = start.position + .init(0, 0, 1000)
    game.workBraking = .init(velocity: .init(0, 0, 10000), angularVelocity: .init(0, 0, 0))
    game.approvedWorkMotion = .init(
      start: start, end: end, initialVelocity: .init(0, 0, 10000),
      acceleration: .init(0, 0, 0), worldAngularVelocity: .init(0, 0, 0), duration: 0.1,
      playerRadius: game.commander.playerMesh.vertices.map(\.length).max() ?? 80)
    game.persistOrePoses()
    let front = game.frontShield
    let rear = game.rearShield
    game.commander.flightSimulation.advancePhysicalTime(0.1)
    let capturedFrame = game.beginAsteroidContactStep()
    let frame = try #require(capturedFrame)
    let moved = game.moveWorkFrame(delta: 0.1)
    try #require(moved)
    let result = game.completeAsteroidContactStep(frame, delta: 0.1)
    guard case .advanced(let receipt) = result, let receipt else {
      Issue.record("Native fast crossing did not commit: \(nativeContactOutcome(result))")
      return
    }
    #expect(receipt.point.z < end.position.z)
    #expect(game.frontShield < front && game.rearShield == rear)
  }
}

private func stationFractureGame(main: Bool) throws -> (Game, MiningRock, Int, Int) {
  // Select from genuine authored station/belt presence before constructing a game.
  let binding = try #require(
    NativeStationSource.bindings.first { binding in
      guard binding.kind == .waystation,
        let system = Universe.galaxy(number: binding.system.galaxy)
          .first(where: { $0.id == binding.system.system }),
        AsteroidBeltDefinition.isPresent(system: system, galaxy: binding.system.galaxy)
      else { return false }
      for field in UInt16(4)..<7 {
        for index in UInt16(0)..<4 {
          let id = RockIdentity(system: binding.system, field: field, rock: index)
          if let chunk = AsteroidBeltDefinition.chunk(for: id), chunk.units > 20,
            chunk.content == .gold || chunk.content == .platinum
          {
            return true
          }
        }
      }
      return false
    })
  var game = Game(executive: false)
  game.commander.galaxy = binding.system.galaxy
  game.commander.system = binding.system.system
  game.systems = Universe.systemsIncludingPlugh(number: binding.system.galaxy)
  game.screen = .status
  try game.commander.prepareEquipment(legacy: false)
  game.launch()
  try #require(!game.docked && game.commander.nativeStationStateValid)
  let station = try #require(
    game.bodies.first {
      main ? $0.id == 0 : $0.nativeStationIdentity?.definition == binding.kind.sourceDefinition
    })
  let rock = try #require(
    game.miningFields.flatMap(\.rocks).first {
      guard let chunk = AsteroidBeltDefinition.chunk(for: $0.identity) else { return false }
      return chunk.units > 20 && (chunk.content == .gold || chunk.content == .platinum)
    })
  game.bodies.removeAll { $0.hull != .station }
  game.commander.npcPersistence = .init()
  game.commander.resetWantedCareerBindings(system: game.systemIdentity)
  game.miningFields = [.init(position: rock.position, rocks: [rock])]
  game.speed = 0
  moveFractureObserver(&game, to: rock.position - .init(0, 0, 500))
  game.activateNearbyMiningFields()
  let source = try #require(game.bodies.first { $0.physical?.rock == rock.identity })
  try nativeFractureHit(&game, bodyID: source.id, damage: rock.energy + 1)
  return (game, rock, source.id, station.id)
}

private func armStationFractureImpact(_ game: inout Game, sourceID: Int, stationID: Int) throws {
  let station = try #require(game.bodies.first { $0.id == stationID })
  let center = game.commander.flightSimulation.pose.systemPoint(station.position)
  moveFractureObserver(&game, to: center + .init(0, 10000, 0))
  let pose = game.commander.flightSimulation.pose
  let target = try #require(game.bodies.first { $0.id == stationID })
  let mesh = game.gameplayMesh(for: target)
  let reach = (mesh.vertices.map(\.length).max() ?? 0) + 500
  let wall = try #require(
    GameplayRaycast.nearest(
      origin: pose.shipPoint(center + .init(reach, 0, 0)),
      direction: pose.shipVector(.init(-1, 0, 0)), maxDistance: reach * 2,
      bodies: [target], meshOverrides: [target.id: mesh]))
  try #require(wall.target == .body(stationID))
  let index = try #require(game.bodies.firstIndex { $0.id == sourceID })
  game.bodies[index].orientation = Basis3().relative(to: pose.orientation)
  game.bodies[index].rotation = 0
  game.bodies[index].rotationRate = 0
  game.bodies[index].physical?.canonicalSpin = false
  game.bodies[index].physical?.angularVelocity = .init(0, 0, 0)
  let extent = try #require(game.gameplayMesh(for: game.bodies[index]).vertices.map { -$0.x }.max())
  game.bodies[index].position = wall.point + pose.shipVector(.init(extent + 10, 0, 0))
  game.bodies[index].physical?.velocity = .init(-200, 0, 0)
  game.persistOrePoses()
}

private func moveStationContactEndpoints(_ game: inout Game, delta: Double) {
  let pose = game.commander.flightSimulation.pose
  for index in game.bodies.indices {
    game.advanceBodyModelRotation(at: index, delta: delta)
    game.advanceCanonicalModelSpin(at: index, delta: delta)
    guard let physical = game.bodies[index].physical, physical.spawnIdentity != nil,
      physical.ordnance == nil, game.bodies[index].scriptNPC == nil
    else { continue }
    game.bodies[index].position =
      game.bodies[index].position + pose.shipVector(physical.velocity) * delta
  }
}

extension AsteroidFragmentationTests {
  @Test(arguments: [false, true])
  func actualStationImpactRetainsResourcesMomentumAndDerivedCoast(main: Bool) throws {
    var (game, rock, sourceID, stationID) = try stationFractureGame(main: main)
    try armStationFractureImpact(&game, sourceID: sourceID, stationID: stationID)
    let before = try #require(game.bodies.first { $0.id == stationID })
    let identity = try #require(game.stationInertialIdentity(for: before))
    let source = try #require(game.bodies.first { $0.id == sourceID })
    let mass = try #require(game.asteroidDebrisMassKg(source))
    let sourceAnchor = game.commander.flightSimulation.anchors?.station
    let authoredPose = before.nativeStationIdentity.flatMap {
      game.commander.nativeStations?.pose(for: $0)
    }
    let credits = game.commander.credits
    let kills = game.commander.kills
    game.commander.flightSimulation.advancePhysicalTime(0.1)
    let captured = game.beginAsteroidContactStep(delta: 0.1)
    let frame = try #require(captured)
    moveStationContactEndpoints(&game, delta: 0.1)
    let result = game.completeAsteroidContactStep(frame, delta: 0.1)
    guard case .advanced(let actual?) = result else {
      Issue.record("Native station contact did not commit: \(String(describing: result))")
      return
    }
    #expect(actual.target == before.physical?.identity && actual.damage > 0)
    let station = try #require(game.bodies.first { $0.id == stationID })
    let debris = try #require(game.bodies.first { $0.id == sourceID })
    let velocity = try #require(debris.physical?.velocity)
    let stationVelocity = try #require(station.physical?.velocity)
    #expect(stationVelocity.length > 0 && station.energy < before.energy && station.energy > 0)
    let momentum = velocity * mass + stationVelocity * AsteroidImpactPolicy.massKg(hull: .station)
    #expect((momentum - Vector3(-200, 0, 0) * mass).length < 1e-6)
    #expect(game.commander.credits == credits && game.commander.kills == kills)
    #expect(game.commander.flightSimulation.anchors?.station == sourceAnchor)
    #expect(game.commander.nativeStations?.ledger.currentDock == nil)
    #expect(game.commander.nativeStations?.currentMainDock == nil)
    let world = try #require(game.commander.nativeStations)
    let motion = try #require(world.inertia(for: identity))
    #expect(motion.valid && motion.contacts == 1 && motion.velocity == stationVelocity)
    switch identity {
    case .main(let id):
      #expect(game.commander.scriptState.stationResources[id.key]?.energy == station.energy)
      #expect(sourceAnchor?.position == Vector3(0, 0, 0))
    case .rrs(let id):
      let saved = try #require(world.pose(for: id))
      #expect(
        saved.position == authoredPose?.position && saved.orientation == authoredPose?.orientation)
      #expect(saved.energy == station.energy)
      let observation = try #require(
        game.nativeStationFlightObservations(from: nil, delta: nil).first { $0.bodyID == stationID }
      )
      #expect(observation.rigidPoseConsistent)
      #expect(
        (observation.canonicalPose.position - observation.renderedPose.position).length < 1e-5)
    }
    let decoded = try JSONDecoder().decode(
      NativeStationWorld.self, from: JSONEncoder().encode(world))
    #expect(decoded == world && decoded.valid)
    let commander = try JSONDecoder().decode(
      Commander.self, from: JSONEncoder().encode(game.commander))
    #expect(commander.nativeStations == world && commander.nativeStationStateValid)
    var malformed = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(world)) as? [String: Any])
    var entries = try #require(malformed["stationInertia"] as? [[String: Any]])
    entries[0]["physicalTime"] = -1.0
    malformed["stationInertia"] = entries
    let invalid = try JSONSerialization.data(withJSONObject: malformed)
    #expect(throws: NativeStationRuntimeError.self) {
      try JSONDecoder().decode(NativeStationWorld.self, from: invalid)
    }
    // Relative entry speed includes the full current player velocity.
    game.manualResidualFlight = true
    game.autoPilot.setApproachVelocity(
      game.commander.flightSimulation.pose.shipVector(stationVelocity + .init(100, 0, 0)))
    #expect(abs(game.nativeStationRelativeEntrySpeed(station) - 100) < 1e-7)
    game.autoPilot.setApproachVelocity(.init(0, 0, 0))
    game.manualResidualFlight = false
    // Unload the actual aggregate into its already-recorded physical custody.
    let debrisActor = try #require(debris.physical?.identity)
    game.commander.miningLedger.cull(actor: debrisActor)
    game.bodies.removeAll { $0.id == sourceID }
    // A real coast consumes only the owned momentum and physical clock.
    let initial = game.commander.flightSimulation.pose.systemPoint(station.position)
    game.commander.flightSimulation.advancePhysicalTime(1000)
    let time = game.commander.flightSimulation.physicalTime
    for index in game.bodies.indices {
      game.advanceBodyModelRotation(at: index, delta: 1000)
    }
    let coast = game.synchronizeNativeStationInertia(at: time, advancingFrom: time - 1000)
    #expect(coast)
    let moving = try #require(game.bodies.first { $0.id == stationID })
    let position = game.commander.flightSimulation.pose.systemPoint(moving.position)
    #expect((position - initial - stationVelocity * 1000).length < 1e-5)
    #expect(game.commander.flightSimulation.anchors?.station == sourceAnchor)
    #expect(game.commander.miningLedger.breakups[rock.identity]?.birthMassKg == mass)
    if case .rrs(let id) = identity {
      game.bodies.removeAll { $0.id == stationID || $0.id == sourceID }
      try game.populateNativeStations()
      let admitted = try #require(game.bodies.first { $0.nativeStationIdentity == id })
      #expect(admitted.physical?.identity != before.physical?.identity)
      #expect(admitted.physical?.velocity == stationVelocity && admitted.energy == station.energy)
      #expect(
        (game.commander.flightSimulation.pose.systemPoint(admitted.position) - position).length
          < 1e-5)
      #expect(game.commander.nativeStations?.pose(for: id)?.position == authoredPose?.position)
    } else {
      // The real launch path restores the registered source at its derived current
      // position and offsets departure without rewriting the immutable anchor.
      game.dock()
      game.launch()
      try #require(!game.docked)
      let admitted = try #require(game.bodies.first { $0.id == 0 && $0.hull == .station })
      #expect(admitted.physical?.identity != before.physical?.identity)
      #expect(admitted.physical?.velocity == stationVelocity && admitted.energy == station.energy)
      #expect(
        (game.commander.flightSimulation.pose.systemPoint(admitted.position) - position).length
          < 1e-5)
      #expect(game.commander.flightSimulation.anchors?.station.position == Vector3(0, 0, 0))
      let departure = game.commander.flightSimulation.pose.orientation.apply(
        .init(0, 0, game.speed * 18))
      #expect((game.flightWorldVelocity - departure - stationVelocity).length < 1e-7)
    }
    // A mismatched velocity is not normalized into a legitimate moving station.
    let currentIndex = try #require(
      game.bodies.firstIndex { game.stationInertialIdentity(for: $0) == identity })
    let current = game.bodies[currentIndex].position
    let original = try #require(game.commander.nativeStations?.sourcePosition(for: identity))
    game.bodies[currentIndex].position = game.commander.flightSimulation.pose.shipPoint(original)
    let misplaced = game.bodies
    let positionRefused = game.synchronizeNativeStationInertia(at: time)
    #expect(!positionRefused && game.bodies == misplaced)
    game.bodies[currentIndex].position = current
    game.bodies[currentIndex].physical?.velocity = .init(1, 2, 3)
    let retained = game.bodies
    let refused = game.synchronizeNativeStationInertia(at: time)
    #expect(!refused && game.bodies == retained)
  }
}

extension AsteroidFragmentationTests {
  @Test func movingStationRefusalRetainsCurrentSceneSaveAndSafeResume() async throws {
    var (game, _, sourceID, stationID) = try stationFractureGame(main: false)
    try armStationFractureImpact(&game, sourceID: sourceID, stationID: stationID)
    game.commander.flightSimulation.advancePhysicalTime(0.1)
    let firstCapture = game.beginAsteroidContactStep(delta: 0.1)
    let firstFrame = try #require(firstCapture)
    moveStationContactEndpoints(&game, delta: 0.1)
    let impact = game.completeAsteroidContactStep(firstFrame, delta: 0.1)
    guard case .advanced(let receipt?) = impact else {
      Issue.record("Actual station impact prerequisite refused: \(String(describing: impact))")
      return
    }
    let station = try #require(game.bodies.first { $0.id == stationID })
    let identity = try #require(game.stationInertialIdentity(for: station))
    let original = try #require(game.commander.nativeStations?.inertia(for: identity))
    #expect(original.contacts == 1 && original.refusedSteps == 0 && receipt.damage > 0)
    let sourceActor = try #require(game.bodies.first { $0.id == sourceID }?.physical?.identity)
    game.commander.miningLedger.cull(actor: sourceActor)
    game.bodies.removeAll { $0.id == sourceID }
    let resources = game.commander.scriptState.stationResources
    let sourcePoses = game.commander.nativeStations?.poses
    let position = game.commander.flightSimulation.pose.systemPoint(station.position)
    game.commander.flightSimulation.advancePhysicalTime(0.1)
    let failedTime = game.commander.flightSimulation.physicalTime
    let captured = game.beginAsteroidContactStep(delta: 0.1)
    let frame = try #require(captured)
    moveStationContactEndpoints(&game, delta: 0.1)
    let index = try #require(game.bodies.firstIndex { $0.id == stationID })
    // An actual malformed endpoint rejects this once-consumed movement frame.
    game.bodies[index].position = .init(.infinity, 0, 0)
    let failed = game.completeAsteroidContactStep(frame, delta: 0.1)
    guard case .refused = failed else {
      Issue.record("Malformed station endpoint was admitted")
      return
    }
    #expect(game.paused && game.commander.flightSimulation.physicalTime == failedTime)
    let world = try #require(game.commander.nativeStations)
    let retained = try #require(world.inertia(for: identity))
    #expect(retained.valid && retained.contacts == original.contacts)
    #expect(retained.momentum == original.momentum && retained.impactTime == original.impactTime)
    #expect(retained.refusedSteps == 1 && abs(retained.refusedMotionTime - 0.1) < 1e-12)
    #expect(game.commander.scriptState.stationResources == resources && world.poses == sourcePoses)
    let restoredBody = try #require(game.bodies.first { $0.id == stationID })
    #expect(
      (game.commander.flightSimulation.pose.systemPoint(restoredBody.position) - position).length
        < 1e-5)
    #expect(
      world.currentPosition(for: identity, at: failedTime).map { ($0 - position).length < 1e-5 }
        == true)
    #expect(
      world.sceneIsConsistent(
        bodies: game.bodies, docked: game.docked, mainStation: game.dockedAtMainStation,
        system: game.systemIdentity, flight: game.commander.flightSimulation))
    let stationObservation = try #require(
      game.nativeStationFlightObservations(from: nil, delta: nil).first { $0.bodyID == stationID })
    #expect(stationObservation.rigidPoseConsistent)
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    try NativeSaveTestFixture.prepareCurrentPolicy(&game)
    let runtime = GameRuntime(game: game, saveURL: storage.url)
    try await runtime.save(to: storage.url)
    let (disk, _) = try ScriptSaveStore.read(Data(contentsOf: storage.url), from: storage.url)
    #expect(disk.nativeStations?.inertia(for: identity) == retained && disk.nativeStationStateValid)
    let reloaded = GameRuntime(game: Game(executive: false))
    try await reloaded.load(from: storage.url, persistMigrations: false)
    game = await reloaded.snapshot()
    #expect(game.commander.nativeStations?.inertia(for: identity) == retained)
    #expect(
      game.commander.nativeStations?.sceneIsConsistent(
        bodies: game.bodies, docked: game.docked, mainStation: game.dockedAtMainStation,
        system: game.systemIdentity, flight: game.commander.flightSimulation) == true)
    game.paused = false
    game.commander.flightSimulation.advancePhysicalTime(0.1)
    let resumedCapture = game.beginAsteroidContactStep(delta: 0.1)
    let resumedFrame = try #require(resumedCapture)
    moveStationContactEndpoints(&game, delta: 0.1)
    let resumed = game.completeAsteroidContactStep(resumedFrame, delta: 0.1)
    guard case .advanced(nil) = resumed else {
      Issue.record("Safe station resume refused: \(String(describing: resumed))")
      return
    }
    let current = try #require(
      game.bodies.first { game.stationInertialIdentity(for: $0) == identity })
    let now = game.commander.flightSimulation.pose.systemPoint(current.position)
    #expect((now - position - original.velocity * 0.1).length < 1e-5)
    #expect(game.commander.nativeStations?.inertia(for: identity)?.momentum == original.momentum)
    #expect(game.commander.nativeStations?.inertia(for: identity)?.contacts == 1)
    #expect(game.commander.nativeStations?.inertia(for: identity)?.refusedSteps == 1)
    #expect(
      game.commander.nativeStations?.sceneIsConsistent(
        bodies: game.bodies, docked: game.docked, mainStation: game.dockedAtMainStation,
        system: game.systemIdentity, flight: game.commander.flightSimulation) == true)
  }
}

extension AsteroidFragmentationTests {
  @Test func firstRefusedStationStepRecordsNoInventedImpulseOrContact() throws {
    var (game, _, sourceID, _) = try stationFractureGame(main: false)
    let original = try #require(game.commander.nativeStations)
    #expect(original.stationInertia.isEmpty)
    game.commander.flightSimulation.advancePhysicalTime(0.1)
    let captured = game.beginAsteroidContactStep(delta: 0.1)
    let frame = try #require(captured)
    moveStationContactEndpoints(&game, delta: 0.1)
    let index = try #require(game.bodies.firstIndex { $0.id == sourceID })
    game.bodies[index].position = .init(.infinity, 0, 0)
    let result = game.completeAsteroidContactStep(frame, delta: 0.1)
    guard case .refused = result else {
      Issue.record("Malformed debris endpoint was admitted")
      return
    }
    let world = try #require(game.commander.nativeStations)
    let stations = game.bodies.filter { $0.nativeStationIdentity != nil }
    try #require(!stations.isEmpty)
    for station in stations {
      let identity = try #require(station.nativeStationIdentity)
      let motion = try #require(world.inertia(for: .rrs(identity)))
      #expect(motion.valid && motion.contacts == 0 && motion.impactTime == 0)
      #expect(motion.momentum == Vector3(0, 0, 0) && motion.displacement == Vector3(0, 0, 0))
      #expect(motion.refusedSteps == 1 && motion.refusedMotionTime == 0.1)
    }
    #expect(world.poses == original.poses && world.ledger == original.ledger)
    #expect(
      world.sceneIsConsistent(
        bodies: game.bodies, docked: game.docked, mainStation: game.dockedAtMainStation,
        system: game.systemIdentity, flight: game.commander.flightSimulation))
  }
}

private func nativeContinuationPlayerGame() throws -> (Game, MiningRock, Int) {
  var (game, rock, bodyID) = try nativeFractureGame()
  try nativeFractureHit(&game, bodyID: bodyID, damage: rock.energy + 1)
  let index = try #require(game.bodies.firstIndex { $0.id == bodyID })
  game.bodies[index].rotation = 0
  game.bodies[index].orientation = .init()
  game.bodies[index].position = .init(0, 0, 500)
  game.bodies[index].physical?.velocity = .init(0, 0, -6000)
  game.persistOrePoses()
  return (game, rock, bodyID)
}

extension AsteroidFragmentationTests {
  @Test func secondNativeFaceTransfersMomentumAfterDeathWithoutASecondSettlement() throws {
    var (game, _, bodyID) = try nativeContinuationPlayerGame()
    let body = try #require(game.bodies.first { $0.id == bodyID })
    let mass = try #require(game.asteroidDebrisMassKg(body))
    let playerMass = AsteroidImpactPolicy.massKg(hull: .cobra)
    let sourceHull = try PreparedHull(mesh: game.gameplayMesh(for: body))
    let targetHull = try PreparedHull(mesh: game.commander.playerMesh)
    let sourceStart = game.modelPose(of: body)
    let playerStart = game.commander.flightSimulation.pose
    var sourceEnd = sourceStart
    sourceEnd.position = sourceEnd.position + Vector3(0, 0, -600)
    let motion = HullSceneMotion(
      start: sourceStart, end: sourceEnd,
      initialVelocity: .init(0, 0, -6000), acceleration: .init(0, 0, 0),
      worldAngularVelocity: .init(0, 0, 0), duration: 0.1, playerRadius: sourceHull.radius)
    let stationary = HullSceneMotion(
      start: playerStart, end: playerStart,
      initialVelocity: .init(0, 0, 0), acceleration: .init(0, 0, 0),
      worldAngularVelocity: .init(0, 0, 0), duration: 0.1, playerRadius: targetHull.radius)
    guard
      case .contact(let first) = HullSweepSafety.firstNativeContact(
        source: motion,
        hull: sourceHull, target: stationary, targetHull: targetHull)
    else {
      Issue.record("Native hull did not supply the first certified face")
      return
    }
    let firstResponse = try #require(
      AsteroidImpactPolicy.impulse(
        sourceMass: mass,
        targetMass: playerMass, sourceVelocity: motion.initialVelocity,
        targetVelocity: stationary.initialVelocity, normal: first.normal))
    let emission = game.commander.flightSimulation.nextEmission
    let incident = game.commander.flightSimulation.nextIncident
    let cash = game.commander.credits
    let kills = game.commander.kills
    let rear = game.rearShield
    game.commander.flightSimulation.advancePhysicalTime(0.1)
    let captured = game.beginAsteroidContactStep()
    let frame = try #require(captured)
    moveNativeContactEndpoints(&game, delta: 0.1)
    let result = game.completeAsteroidContactStep(frame, delta: 0.1)
    guard case .advanced(let receipt) = result, let receipt else {
      Issue.record("Native second-face continuation refused: \(nativeContactOutcome(result))")
      return
    }
    let after = try #require(game.bodies.first { $0.id == bodyID }?.physical?.velocity)
    #expect((after - firstResponse.source).length > 1)
    #expect(
      (after * mass + game.flightWorldVelocity * playerMass
        - motion.initialVelocity * mass).length < 1e-6)
    #expect(game.energy <= 0 && game.rearShield == rear)
    #expect(game.commander.flightSimulation.nextEmission == emission + 1)
    #expect(game.commander.flightSimulation.nextIncident == incident + 2)
    #expect(receipt.incident == incident)
    #expect(game.commander.credits == cash && game.commander.kills == kills)
  }

  @Test func continuationIncidentCapacityRefusalRestoresMotionAndAllHealth() throws {
    var (game, _, _) = try nativeContinuationPlayerGame()
    let encoded = try JSONEncoder().encode(game.commander.flightSimulation)
    var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    object["nextIncident"] = NSNumber(value: UInt64.max - 1)
    game.commander.flightSimulation = try JSONDecoder().decode(
      FlightSimulationState.self,
      from: JSONSerialization.data(withJSONObject: object))
    try #require(game.commander.flightSimulation.valid)
    game.commander.flightSimulation.advancePhysicalTime(0.1)
    let commander = game.commander
    let bodies = game.bodies
    let health = [game.energy, game.frontShield, game.rearShield]
    let velocity = game.flightWorldVelocity
    let captured = game.beginAsteroidContactStep()
    let frame = try #require(captured)
    moveNativeContactEndpoints(&game, delta: 0.1)
    let result = game.completeAsteroidContactStep(frame, delta: 0.1)
    guard case .refused(let reason) = result else {
      Issue.record("Insufficient incident capacity committed a partial continuation")
      return
    }
    #expect(reason == "INCIDENT CAPACITY")
    #expect(game.commander == commander && game.bodies == bodies)
    #expect([game.energy, game.frontShield, game.rearShield] == health)
    #expect(game.flightWorldVelocity == velocity)
  }
}

extension AsteroidFragmentationTests {
  @Test func anotherNativePairOnTheResponsePathRefusesWithoutPartialDamageOrImpulse() throws {
    var (game, _, bodyID) = try nativeContinuationPlayerGame()
    let sourceBody = try #require(game.bodies.first { $0.id == bodyID })
    let mass = try #require(game.asteroidDebrisMassKg(sourceBody))
    let sourceHull = try PreparedHull(mesh: game.gameplayMesh(for: sourceBody))
    let playerHull = try PreparedHull(mesh: game.commander.playerMesh)
    let start = game.modelPose(of: sourceBody)
    var end = start
    end.position = end.position + Vector3(0, 0, -600)
    let incoming = HullSceneMotion(
      start: start, end: end,
      initialVelocity: .init(0, 0, -6000), acceleration: .init(0, 0, 0),
      worldAngularVelocity: .init(0, 0, 0), duration: 0.1, playerRadius: sourceHull.radius)
    let player = game.commander.flightSimulation.pose
    let stillPlayer = HullSceneMotion(
      start: player, end: player,
      initialVelocity: .init(0, 0, 0), acceleration: .init(0, 0, 0),
      worldAngularVelocity: .init(0, 0, 0), duration: 0.1, playerRadius: playerHull.radius)
    guard
      case .contact(let first) = HullSweepSafety.firstNativeContact(
        source: incoming,
        hull: sourceHull, target: stillPlayer, targetHull: playerHull)
    else {
      Issue.record("Missing original native player contact")
      return
    }
    let frontier = try #require(
      HullSweepSafety.nativeFrontierPoses(
        first,
        sourceHull: sourceHull, targetHull: playerHull))
    let response = try #require(
      AsteroidImpactPolicy.impulse(
        sourceMass: mass,
        targetMass: AsteroidImpactPolicy.massKg(hull: .cobra),
        sourceVelocity: incoming.initialVelocity, targetVelocity: .init(0, 0, 0),
        normal: first.normal))
    let remaining = 0.1 - first.lowerTime
    var responseEnd = frontier.source
    responseEnd.position = responseEnd.position + response.source * remaining
    let cargoHull = try PreparedHull(mesh: Mesh.hull(.cargo))
    let cargoPose = ShipPose(position: responseEnd.position)
    let stillCargo = HullSceneMotion(
      start: cargoPose, end: cargoPose,
      initialVelocity: .init(0, 0, 0), acceleration: .init(0, 0, 0),
      worldAngularVelocity: .init(0, 0, 0), duration: 0.1, playerRadius: cargoHull.radius)
    // This third body is placed at the response endpoint derived from the real
    // normal, with no search or replacement of the original collision fixture.
    guard
      case .clear = HullSweepSafety.firstNativeContact(
        source: incoming,
        hull: sourceHull, target: stillCargo, targetHull: cargoHull)
    else {
      Issue.record("Third-party fixture must leave the original incoming path continuously clear")
      return
    }
    let responseMotion = HullSceneMotion(
      start: frontier.source, end: responseEnd,
      initialVelocity: response.source, acceleration: .init(0, 0, 0),
      worldAngularVelocity: .init(0, 0, 0), duration: remaining, playerRadius: sourceHull.radius)
    let remainingCargo = HullSceneMotion(
      start: cargoPose, end: cargoPose,
      initialVelocity: .init(0, 0, 0), acceleration: .init(0, 0, 0),
      worldAngularVelocity: .init(0, 0, 0), duration: remaining, playerRadius: cargoHull.radius)
    guard
      case .contact = HullSweepSafety.firstNativeContact(
        source: responseMotion,
        hull: sourceHull, target: remainingCargo, targetHull: cargoHull)
    else {
      Issue.record("Third-party fixture must independently prove a real response-path contact")
      return
    }
    let context = try #require(game.gameplayContext())
    let allocated = game.commander.flightSimulation.allocateSpawn()
    let sequence = try #require(allocated)
    let request = SpawnRequest(
      identity: .init(
        system: context.system, visit: context.visit,
        sequence: sequence, member: 0, producer: .ambient), population: .cargo, hull: .cargo,
      position: context.player.position + Vector3(0, 0, 1500),
      orientation: .init(), velocity: .init(0, 0, 0),
      npc: nil, rock: nil, payload: nil, priority: .ordinary)
    let receipts = game.admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit,
        revision: context.revision, batches: [.init(requests: [request], atomic: true)], intents: []
      ))
    let actor = try #require(receipts.first?.actor)
    let cargo = try #require(game.bodies.firstIndex { $0.physical?.identity == actor })
    // Admission retains its ordinary stand-off. The live native contact frame
    // begins only after this already admitted body's independent relocation.
    game.bodies[cargo].position = game.commander.flightSimulation.pose.shipPoint(cargoPose.position)
    game.bodies[cargo].rotation = 0
    game.bodies[cargo].orientation = .init()
    game.commander.flightSimulation.advancePhysicalTime(0.1)
    let commander = game.commander
    let bodies = game.bodies
    let health = [game.energy, game.frontShield, game.rearShield]
    let captured = game.beginAsteroidContactStep()
    let frame = try #require(captured)
    moveNativeContactEndpoints(&game, delta: 0.1)
    let result = game.completeAsteroidContactStep(frame, delta: 0.1)
    guard case .refused(let reason) = result else {
      Issue.record("A third pair on the response path committed a partial step")
      return
    }
    #expect(reason == "REMAINING CONTACT")
    #expect(game.commander == commander && game.bodies == bodies)
    #expect([game.energy, game.frontShield, game.rearShield] == health)
  }
}
