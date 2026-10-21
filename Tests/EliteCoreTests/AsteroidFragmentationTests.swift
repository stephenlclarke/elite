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
    #expect(game.bodies.isEmpty && game.commander.miningLedger == beforeRefusal)
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
    let frame = try #require(game.beginAsteroidContactStep())
    moveNativeContactEndpoints(&game, delta: 0.1)
    let result = game.completeAsteroidContactStep(frame, delta: 0.1)
    guard case .advanced(let actualReceipt) = result, let receipt = actualReceipt else {
      Issue.record("Actual native moving debris did not admit the player impact")
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

  @Test func nativeMovingDebrisUsesNPCShieldsAndNativeDeathWithoutPlayerReward() throws {
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
      velocity: .init(0, 0, 0), npc: npc, rock: nil, payload: nil, priority: .ordinary)
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
    let incomingMomentum = Vector3(0, 0, 16000) * sourceKg
    let cash = game.commander.credits
    let kills = game.commander.kills
    game.commander.flightSimulation.advancePhysicalTime(0.1)
    let frame = try #require(game.beginAsteroidContactStep())
    moveNativeContactEndpoints(&game, delta: 0.1)
    let result = game.completeAsteroidContactStep(frame, delta: 0.1)
    guard case .advanced(let receipt) = result, receipt?.target == targetActor else {
      Issue.record("Actual native moving debris did not admit the NPC impact")
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
    if target.energy <= 0 { #expect(target.physical?.deathIncidentID != nil) }
    #expect(game.commander.credits == cash && game.commander.kills == kills)
    #expect(source.energy > 0)
  }

  @Test func staleNativeContactFrameCannotRewindAnotherVisitOrForgeAnEffect() throws {
    var (game, rock, bodyID) = try nativeFractureGame()
    try nativeFractureHit(&game, bodyID: bodyID, damage: rock.energy + 1)
    let frame = try #require(game.beginAsteroidContactStep())
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
