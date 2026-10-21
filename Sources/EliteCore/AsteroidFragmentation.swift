import Foundation

/// Positions and velocity use native system coordinates; mass always uses kilograms.
struct AsteroidMotion: Equatable, Codable, Sendable {
  var position: Vector3
  var velocity: Vector3
  var physicalTime: Double

  var valid: Bool {
    position.finite && position.length.isFinite && velocity.finite && velocity.length.isFinite
      && physicalTime.isFinite && physicalTime >= 0
  }
}

/// A physical aggregate retains all unresolved fragments and dust. Breaking it again
/// never creates a new birth mass or collectible allowance.
struct AsteroidBreakup: Equatable, Codable, Sendable {
  let rock: RockIdentity
  let commodity: CommodityIdentity
  let birthMassKg: Double
  let maximumCollectibleUnits: Int
  var aggregateMassKg: Double
  var workEnergy: Double
  var issuedUnits = 0
  var collectedUnits = 0
  var rubble: Set<UInt16> = []
  /// An offered unit remains physically in the aggregate until its first actual admission.
  var materialized: Set<UInt16> = []
  var payloadTimes: [UInt16: Double] = [:]
  var motion: AsteroidMotion
  var binding: ActorIdentity?

  static func kilogramsPerUnit(_ commodity: CommodityIdentity) -> Double {
    commodity.unit == "t" ? 1000 : commodity.unit == "kg" ? 1 : 0.001
  }

  init?(rock: MiningRock, motion: AsteroidMotion) {
    guard let chunk = AsteroidBeltDefinition.chunk(for: rock.identity),
      rock.radius == chunk.radius, rock.energy == chunk.energy, motion.valid,
      let mass = rock.birthMassKg, mass.isFinite, mass > 0
    else { return nil }
    self.rock = rock.identity
    commodity = chunk.content.commodity
    birthMassKg = mass
    aggregateMassKg = mass
    workEnergy = rock.energy
    // Integer division guarantees STRICTLY less than 5%, including 1/20/40 units.
    maximumCollectibleUnits = (chunk.units - 1) / 20
    self.motion = motion
  }

  var valid: Bool {
    guard let chunk = AsteroidBeltDefinition.chunk(for: rock), motion.valid,
      commodity == chunk.content.commodity,
      birthMassKg == Double(chunk.units) * Self.kilogramsPerUnit(commodity),
      maximumCollectibleUnits == (chunk.units - 1) / 20,
      workEnergy.isFinite, (0...chunk.energy).contains(workEnergy),
      (0...maximumCollectibleUnits).contains(issuedUnits),
      (0...issuedUnits).contains(collectedUnits),
      rubble.allSatisfy({ Int($0) < issuedUnits }),
      materialized.allSatisfy({ Int($0) < issuedUnits }), materialized.count >= collectedUnits,
      payloadTimes.count <= issuedUnits,
      payloadTimes.allSatisfy({ Int($0.key) < issuedUnits && $0.value.isFinite && $0.value >= 0 }),
      aggregateMassKg == birthMassKg - Double(issuedUnits) * Self.kilogramsPerUnit(commodity),
      aggregateMassKg > 0,
      binding.map({
        $0.system == rock.system && $0.visit > 0 && $0.visit < UInt64.max
          && $0.entity >= 2 && $0.entity < UInt64.max
      }) ?? true
    else { return false }
    return Double(maximumCollectibleUnits) * Self.kilogramsPerUnit(commodity) < birthMassKg * 0.05
  }

  func position(at time: Double) -> Vector3 {
    motion.position + motion.velocity * max(0, time - motion.physicalTime)
  }
}

extension Game {
  /// The next swept-contact producer must join the current actor, never a map marker.
  func asteroidDebrisMassKg(_ body: SpaceBody) -> Double? {
    guard let physical = body.physical else { return nil }
    if let root = physical.rock, let breakup = commander.miningLedger.breakups[root],
      breakup.binding == physical.identity
    {
      let reserved = breakup.issuedUnits - breakup.materialized.count
      return breakup.aggregateMassKg
        + Double(reserved) * AsteroidBreakup.kilogramsPerUnit(breakup.commodity)
    }
    if let payload = physical.payload, case .ore(let root, _) = payload,
      commander.miningLedger.breakups[root] != nil,
      commander.miningLedger.boundActor(for: payload) == physical.identity,
      let item = commander.miningLedger.pendingPayloads.first(where: { $0.identity == payload })
    {
      return Double(item.amount.quantity) * AsteroidBreakup.kilogramsPerUnit(item.amount.commodity)
    }
    return nil
  }

  /// Narrow ordinary-hit adapter. The real combat caller supplies its accepted incident.
  /// Reuse the parent actor for the aggregate: capacity cannot erase unresolved mass.
  mutating func damagePhysicalAsteroid(index: Int, incident: CombatIncident, damage: Double) -> Bool
  {
    guard bodies.indices.contains(index), let physical = bodies[index].physical,
      damage.isFinite, damage > 0, incident.victim == physical.identity,
      incident.victimPart == nil, incident.outcome == .hit || incident.outcome == .destruction
    else { return false }
    if let payload = physical.payload, case .ore(let root, _) = payload,
      commander.miningLedger.breakups[root] != nil
    {
      _ = commander.miningLedger.updateOreMotion(
        payload: payload, actor: physical.identity,
        position: commander.flightSimulation.pose.systemPoint(bodies[index].position),
        velocity: physical.velocity, physicalTime: commander.flightSimulation.physicalTime)
      if commander.miningLedger.isRubble(payload) {
        bodies[index].energy = max(100, bodies[index].energy)
      } else if damage.isFinite, damage >= bodies[index].energy,
        commander.miningLedger.destroy(payload: payload, protection: gameplayContext()?.protection)
      {
        // A collision remainder was proved against this body's current mesh. Defer
        // the larger hull/population transition until a later real native admission.
        if incident.kind != .collision {
          bodies[index].hull = .asteroid
          bodies[index].physical?.population = .asteroid
        }
        bodies[index].energy = 100
        commander.miningLedger.bindRubble(payload: payload, actor: physical.identity)
      } else if damage.isFinite, damage > 0 {
        bodies[index].energy = max(1, bodies[index].energy - damage)
      }
      return true
    }
    guard let identity = physical.rock,
      let rock = miningFields.lazy.flatMap(\.rocks).first(where: { $0.identity == identity }),
      AsteroidBeltDefinition.chunk(for: identity) != nil
    else { return false }
    let motion = AsteroidMotion(
      position: commander.flightSimulation.pose.systemPoint(bodies[index].position),
      velocity: physical.velocity, physicalTime: commander.flightSimulation.physicalTime)
    switch commander.miningLedger.hit(
      rock: rock, incident: incident, damage: damage, motion: motion)
    {
    case .damaged(let remaining):
      bodies[index].energy = remaining
      if commander.miningLedger.breakups[identity] != nil {
        bodies[index].rotationRate = 0
        commander.miningLedger.bindBreakup(rock: identity, actor: physical.identity)
      }
    case .extracted: bodies[index].energy = 0
    case .destroyed:
      // The destroyed intact hull becomes the still-solid fragment/dust aggregate.
      bodies[index].energy = rock.energy
      bodies[index].rotationRate = 0
      commander.miningLedger.bindBreakup(rock: identity, actor: physical.identity)
    case .ignored, .capacityRefused: break
    }
    return true
  }

  mutating func persistAsteroidBreakupMotion() {
    let flight = commander.flightSimulation
    for body in bodies where body.energy > 0 {
      guard let physical = body.physical, let rock = physical.rock,
        var breakup = commander.miningLedger.breakups[rock],
        physical.identity.system == rock.system, physical.identity.visit == flight.visit,
        breakup.binding == nil || breakup.binding == physical.identity,
        bodies.filter({ $0.physical?.rock == rock && $0.energy > 0 }).count == 1
      else { continue }
      breakup.binding = physical.identity
      let motion = AsteroidMotion(
        position: flight.pose.systemPoint(body.position), velocity: physical.velocity,
        physicalTime: flight.physicalTime)
      guard motion.valid, motion.physicalTime >= breakup.motion.physicalTime else { continue }
      breakup.motion = motion
      commander.miningLedger.breakups[rock] = breakup
    }
  }
}
