import Foundation

struct NativeSalvageWreckObservation: Sendable {
  let actor: ActorIdentity
  let time: Double
  let motion: SalvageWreckMotion
}

extension Game {
  /// Admission and cutting call this only for a genuine generated site or an actual
  /// retained EMP hull. The ordinary ledger's lifetime wreck pool is not consulted.
  mutating func retainNativeSalvageWreck(_ body: SpaceBody) -> Bool {
    guard let physical = body.physical, let identity = physical.salvage?.wreck,
      let catalogue = physical.catalogueShipID, let owner = commander.equipmentOwnerID,
      physical.identity.system == systemIdentity,
      physical.identity.visit == commander.flightSimulation.visit,
      identity.system == systemIdentity, physical.npc == nil,
      body.energy.isFinite, body.energy > 0,
      commander.alienStorageStateValid
    else { return false }
    if let existing = commander.alienStorageState?.current.salvage.native.wrecks[identity] {
      guard existing.owner == owner, existing.catalogueShipID == catalogue,
        existing.destroyedAt == nil
      else { return false }
      if existing.binding == physical.identity { return true }
      guard existing.binding == nil, let previous = commander.alienStorageState?.current.snapshot
      else { return false }
      let bound = NativeSalvageWreck(
        id: existing.id, owner: existing.owner, identity: existing.identity,
        catalogueShipID: existing.catalogueShipID,
        seed: existing.seed, source: existing.source, bornAt: existing.bornAt,
        observedAt: commander.flightSimulation.physicalTime, binding: physical.identity,
        motion: .init(
          pose: modelPose(of: body), velocity: physical.velocity,
          angularVelocity: physical.angularVelocity, energy: body.energy), destroyedAt: nil)
      guard (bound.motion.pose.position - existing.motion.pose.position).length < 1e-8,
        (bound.motion.pose.orientation.x - existing.motion.pose.orientation.x).length < 1e-8,
        (bound.motion.pose.orientation.y - existing.motion.pose.orientation.y).length < 1e-8,
        (bound.motion.pose.orientation.z - existing.motion.pose.orientation.z).length < 1e-8,
        bound.motion.velocity == existing.motion.velocity,
        bound.motion.angularVelocity == existing.motion.angularVelocity,
        bound.motion.energy == existing.motion.energy
      else { return false }
      do {
        let world = previous.world.map {
          $0.id == existing.id ? AlienStorageWorldRecord.nativeWreck(bound) : $0
        }
        try commander.replaceAlienStorage(with: previous.replacingNativeWorld(world))
        return true
      } catch { return false }
    }
    let source: NativeSalvageWreck.Source
    if let logical = physical.empSource, let record = commander.savedEMPState?.records[logical],
      record.wreck == identity, record.crewAboard == 0,
      record.pods.count + record.capturedCrewCount == record.crewTotal
    {
      source = .emp(actor: logical, sequence: record.sequence)
    } else if let site = salvageSites.first(where: {
      $0.identity == identity && $0.catalogueShipID == catalogue
    }),
      site.metadata == physical.salvage
    {
      source = .generated(site)
    } else {
      return false
    }
    let time = commander.flightSimulation.physicalTime
    let wreck = NativeSalvageWreck(
      id: UUID(), owner: owner, identity: identity, catalogueShipID: catalogue,
      seed: commander.salvageLedger.nativeInspectionSeed, source: source, bornAt: time,
      observedAt: time, binding: physical.identity,
      motion: .init(
        pose: modelPose(of: body), velocity: physical.velocity,
        angularVelocity: physical.angularVelocity, energy: body.energy), destroyedAt: nil)
    guard wreck.valid else { return false }
    let previous =
      commander.alienStorageState?.current.snapshot
      ?? .init(
        owner: owner, revision: 0, worldRevision: 0, world: [], sources: [],
        attachments: [], upgrades: [], receipts: [], commands: [])
    do {
      try commander.replaceAlienStorage(
        with: previous.replacingNativeWorld(previous.world + [.nativeWreck(wreck)]))
      return true
    } catch { return false }
  }

  mutating func observeNativeSalvageWreck(_ body: SpaceBody) -> Bool {
    guard let physical = body.physical, let identity = physical.salvage?.wreck,
      let original = commander.alienStorageState?.current.salvage.native.wrecks[identity],
      original.destroyedAt == nil, original.binding == physical.identity,
      physical.payload == nil, physical.npc == nil,
      physical.catalogueShipID == original.catalogueShipID,
      physical.identity.system == systemIdentity,
      physical.identity.visit == commander.flightSimulation.visit
    else { return false }
    let time = commander.flightSimulation.physicalTime
    let motion = SalvageWreckMotion(
      pose: modelPose(of: body), velocity: physical.velocity,
      angularVelocity: physical.angularVelocity, energy: body.energy)
    let check = NativeSalvageWreck(
      id: original.id, owner: original.owner, identity: original.identity,
      catalogueShipID: original.catalogueShipID, seed: original.seed, source: original.source,
      bornAt: original.bornAt, observedAt: time,
      binding: body.energy <= 0 ? nil : physical.identity, motion: motion,
      destroyedAt: body.energy <= 0 ? time : nil)
    guard check.valid, time >= original.observedAt else { return false }
    nativeSalvageWreckMotion[identity] = .init(actor: physical.identity, time: time, motion: motion)
    return true
  }

  @discardableResult
  mutating func flushNativeSalvageWrecks(
    parking actors: Set<ActorIdentity> = [], parkingSystem: SystemIdentity? = nil
  ) -> Bool {
    let parking =
      commander.alienStorageState?.current.salvage.native.wrecks.values.contains {
        $0.binding.map { actors.contains($0) || $0.system == parkingSystem } == true
      } == true
    guard !nativeSalvageWreckMotion.isEmpty || parking else { return true }
    guard let previous = commander.alienStorageState?.current.snapshot else { return false }
    do {
      var deaths: [UUID: Double] = [:]
      var retained = previous.world
      if let hot = nativeSalvageWork {
        if let index = retained.firstIndex(where: { $0.id == hot.cycle.id }) {
          retained[index] = .nativeWork(hot.cycle)
        } else {
          retained.append(.nativeWork(hot.cycle))
        }
      }
      var world = retained.map { record -> AlienStorageWorldRecord in
        guard case .nativeWreck(let old) = record else { return record }
        let park = old.binding.map { actors.contains($0) || $0.system == parkingSystem } == true
        let observation = nativeSalvageWreckMotion[old.identity]
        guard observation != nil || park else { return record }
        let motion = observation?.motion ?? old.motion
        let time = observation?.time ?? old.observedAt
        if motion.energy.map({ $0 <= 0 }) == true { deaths[old.id] = time }
        return .nativeWreck(
          .init(
            id: old.id, owner: old.owner, identity: old.identity,
            catalogueShipID: old.catalogueShipID,
            seed: old.seed, source: old.source, bornAt: old.bornAt,
            observedAt: time, binding: park || deaths[old.id] != nil ? nil : old.binding,
            motion: motion, destroyedAt: deaths[old.id]))
      }
      if !deaths.isEmpty {
        let native = try NativeSalvagePlanView(previous.world)
        let deadIdentities = Set(
          native.wrecks.values.filter { deaths[$0.id] != nil }.map(\.identity))
        let dying = Set(
          native.plans.values.filter { deadIdentities.contains($0.plan.section.wreck) }.map(\.id))
        world = world.map { record in
          switch record {
          case .nativeWork(let old):
            guard let plan = native.plans[old.inspection.id],
              let wreck = native.wrecks[plan.plan.section.wreck], let at = deaths[wreck.id]
            else { return record }
            return .nativeWork(
              .init(
                id: old.id, owner: old.owner, version: old.version, inspection: old.inspection,
                beganAt: old.beganAt, observedAt: at, progress: old.progress,
                currentWorkSeconds: old.currentWorkSeconds,
                damagedTechnology: old.damagedTechnology,
                releases: old.releases, lastRelease: old.lastRelease,
                lastOperation: old.lastOperation,
                depleted: true, destroyedAt: at))
          case .lot(let old):
            guard dying.contains(old.plan), case .unissued = old.state,
              let plan = native.plans[old.plan], let wreck = native.wrecks[plan.plan.section.wreck],
              let at = deaths[wreck.id]
            else { return record }
            return .lot(
              .init(
                id: old.id, owner: old.owner, plan: old.plan, itemIndex: old.itemIndex,
                issuedAt: nil, state: .discarded(at: at)))
          default: return record
          }
        }
      }
      if world != previous.world {
        try commander.replaceAlienStorage(with: previous.replacingNativeWorld(world))
      }
      nativeSalvageWork = nil
      nativeSalvageWreckMotion.removeAll(keepingCapacity: true)
      return true
    } catch { return false }
  }
}

extension Commander {
  func nativeWreckSceneIsConsistent(
    _ bodies: [SpaceBody], docked: Bool, atColdBoundary: Bool
  ) -> Bool {
    guard let native = alienStorageState?.current.salvage.native else { return true }
    var seen: Set<WreckIdentity> = []
    for body in bodies {
      guard let physical = body.physical, physical.payload == nil,
        let metadata = physical.salvage, let identity = metadata.wreck,
        let wreck = native.wrecks[identity]
      else { continue }
      guard !docked, seen.insert(identity).inserted, wreck.owner == equipmentOwnerID,
        wreck.destroyedAt == nil, body.energy.isFinite, body.energy > 0,
        physical.npc == nil, physical.catalogueShipID == wreck.catalogueShipID,
        wreck.binding == physical.identity,
        metadata.category == .wreck || metadata.category == .section,
        metadata.claimant == nil, metadata.ownership == .abandoned,
        physical.identity.system == flightSimulation.player?.system,
        physical.identity.visit == flightSimulation.visit
      else { return false }
      switch wreck.source {
      case .generated(let site):
        guard physical.empSource == nil, site.metadata == metadata else { return false }
      case .emp(let source, let sequence):
        guard physical.empSource == source, let record = savedEMPState?.records[source],
          record.wreck == identity, record.sequence == sequence, record.crewAboard == 0,
          record.pods.count + record.capturedCrewCount == record.crewTotal
        else { return false }
      }
      if atColdBoundary {
        let player = flightSimulation.pose
        var basis = Basis3()
        basis.x = player.orientation.apply(body.modelVector(.init(1, 0, 0)))
        basis.y = player.orientation.apply(body.modelVector(.init(0, 1, 0)))
        basis.z = player.orientation.apply(body.modelVector(.init(0, 0, 1)))
        let actual = SalvageWreckMotion(
          pose: .init(position: player.systemPoint(body.position), orientation: basis),
          velocity: physical.velocity, angularVelocity: physical.angularVelocity,
          energy: body.energy)
        guard actual == wreck.motion, wreck.observedAt == flightSimulation.physicalTime else {
          return false
        }
      }
    }
    for wreck in native.wrecks.values where wreck.binding != nil {
      guard !docked, seen.contains(wreck.identity) else { return false }
    }
    return true
  }
}

extension Commander {
  /// Full source provenance is checked at Commander load/transaction boundaries.
  /// Frame consumers use the immutable index and never regenerate lifetime sites.
  var nativeSalvageOriginalSourcesValid: Bool {
    guard let native = alienStorageState?.current.salvage.native else { return true }
    guard
      native.works.values.allSatisfy({
        $0.beganAt <= flightSimulation.physicalTime
          && $0.observedAt <= flightSimulation.physicalTime
      }), native.inspections.values.allSatisfy({ $0.inspectedAt <= flightSimulation.physicalTime })
    else { return false }
    var galaxies: [Int: [StarSystem]] = [:]
    var sites: [SystemIdentity: [SalvageSite]] = [:]
    for wreck in native.wrecks.values {
      guard wreck.owner == equipmentOwnerID, wreck.seed == salvageLedger.nativeInspectionSeed,
        wreck.bornAt <= flightSimulation.physicalTime,
        wreck.observedAt <= flightSimulation.physicalTime
      else { return false }
      switch wreck.source {
      case .generated(let original):
        let identity = wreck.identity.system
        if sites[identity] == nil {
          if galaxies[identity.galaxy] == nil {
            galaxies[identity.galaxy] = Universe.systemsIncludingPlugh(number: identity.galaxy)
          }
          guard let system = galaxies[identity.galaxy]?.first(where: { $0.id == identity.system })
          else { return false }
          let seed =
            UInt64(system.seed.a) << 32 | UInt64(system.seed.b) << 16 | UInt64(system.seed.c)
          sites[identity] = SalvageSites.generate(
            anchors: NativeStationAdmission.canonicalAnchors(system: identity), seed: seed)
        }
        guard sites[identity]?.contains(original) == true else { return false }
      case .emp(let actor, let sequence):
        guard let record = savedEMPState?.records[actor], record.wreck == wreck.identity,
          record.sequence == sequence, record.crewAboard == 0,
          record.pods.count + record.capturedCrewCount == record.crewTotal,
          record.hull.body.physical?.catalogueShipID == wreck.catalogueShipID
        else { return false }
      }
    }
    return true
  }
}
