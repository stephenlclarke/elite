import Foundation

extension Game {
  var hasUnsettledWreckDeaths: Bool {
    bodies.contains { body in
      guard body.energy <= 0, body.physical?.npc == nil,
        let metadata = body.physical?.salvage, metadata.wreck != nil
      else { return false }
      return [.wreck, .section].contains(metadata.category)
    }
  }

  /// Capacity is reserved in the existing ledger before a physical actor can exist.
  /// A refused candidate cannot publish a fresh wreck or reset a saved moving pose.
  mutating func activateNearbySalvageSites() {
    guard !docked else { return }
    for site in salvageSites where site.identity.system == systemIdentity {
      guard !commander.salvageLedger.isWreckDestroyed(site.identity),
        !bodies.contains(where: {
          $0.physical?.salvage?.wreck == site.identity && $0.physical?.payload == nil
        }),
        let profile = SalvageCatalogue.profile(catalogueShipID: site.catalogueShipID),
        let metadata = site.metadata
      else { continue }
      let motion =
        commander.salvageLedger.wreckMotion(for: site.identity)
        ?? .init(
          pose: .init(position: site.position, orientation: site.orientation),
          velocity: site.velocity, angularVelocity: site.angularVelocity)
      let radius = profile.bounds.radius + profile.bounds.center.length
      guard
        (motion.pose.position - commander.flightSimulation.pose.position).length < 6500 + radius,
        let context = gameplayContext()
      else { continue }
      var candidate = self
      guard candidate.commander.salvageLedger.updateWreck(identity: site.identity, motion: motion)
      else {
        let message = "SALVAGE RECORD CAPACITY FULL"
        if self.message != message || messageTime <= 0 { notify(message) }
        continue
      }
      let energy = motion.energy ?? ShipCatalogue.ship(site.catalogueShipID)?.game?.energy ?? 256
      let request = SpawnRequest(
        identity: .init(
          system: context.system, visit: context.visit,
          sequence: UInt64(site.identity.site) + 1, member: 0, producer: .derelicts),
        population: .wreck, hull: .cobra, position: motion.pose.position,
        orientation: motion.pose.orientation, velocity: motion.velocity, npc: nil, rock: nil,
        payload: nil, priority: .ordinary, catalogueShipID: site.catalogueShipID, energy: energy,
        angularVelocity: motion.angularVelocity, salvage: metadata)
      let receipts = candidate.admitEncounterPlan(
        .init(
          system: context.system, visit: context.visit, revision: context.revision,
          batches: [.init(requests: [request], atomic: false)], intents: []))
      guard receipts.count == 1, receipts[0].actor != nil, receipts[0].refusal == nil else {
        continue
      }
      self = candidate
    }
  }

  /// Tombstone and actor removal are one runtime publication. A failed terminal mark
  /// retains the dead source and prevents dock, jump or Save from resurrecting it.
  mutating func registerDestroyedWrecks() -> Set<Int> {
    var deferred = Set<Int>()
    for body in bodies where body.energy <= 0 {
      guard let physical = body.physical, physical.npc == nil,
        let metadata = physical.salvage, [.wreck, .section].contains(metadata.category),
        let wreck = metadata.wreck
      else { continue }
      guard physical.identity.system == systemIdentity,
        physical.identity.visit == commander.flightSimulation.visit,
        wreck.system == systemIdentity,
        commander.salvageLedger.markWreckDestroyed(wreck)
      else {
        deferred.insert(body.id)
        let text = "WRECK SETTLEMENT DEFERRED"
        if message != text || messageTime <= 0 { notify(text) }
        continue
      }
    }
    return deferred
  }

  /// Authored derelict angular velocity is canonical world motion, not an Euler
  /// preview animation. This is the same Rodrigues rotation used by work proofs.
  mutating func advanceCanonicalWreckSpin(at index: Int, delta: Double) {
    guard let physical = bodies[index].physical,
      physical.spawnIdentity?.producer == .derelicts, physical.angularVelocity.finite,
      physical.angularVelocity.length.isFinite, delta.isFinite, delta > 0, delta <= 0.1
    else { return }
    let camera = commander.flightSimulation.pose.orientation
    let world = bodies[index].orientation.transformed(by: camera)
    let next = RelativeWorkController.rotated(world, omega: physical.angularVelocity, delta: delta)
    bodies[index].orientation = next.relative(to: camera)
  }

  public var salvageHUDLines: [String] {
    guard !docked else { return [] }
    let candidates = salvageSites.compactMap { site -> (SalvageSite, Vector3)? in
      guard !commander.salvageLedger.isWreckDestroyed(site.identity) else { return nil }
      let world =
        commander.salvageLedger.wreckMotion(for: site.identity)?.pose.position ?? site.position
      return (site, commander.flightSimulation.pose.shipPoint(world))
    }
    guard let nearest = candidates.min(by: { $0.1.length < $1.1.length }) else { return [] }
    let p = viewPosition(nearest.1)
    let horizontal = abs(p.x) < max(1, abs(p.z)) * 0.12 ? "" : p.x < 0 ? " PORT" : " STARBOARD"
    let vertical = abs(p.y) < max(1, abs(p.z)) * 0.12 ? "" : p.y > 0 ? " UP" : " DOWN"
    return [
      "WRECK SIGNAL" + (p.z >= 0 ? " AHEAD" : " ASTERN") + horizontal + vertical
        + String(format: " %.1fK", p.length / 1000)
    ]
  }
}
