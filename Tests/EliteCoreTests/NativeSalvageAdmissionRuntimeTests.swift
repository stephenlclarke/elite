import Foundation
import Testing

@testable import EliteCore

enum NativeSalvageAdmissionTestFixture {
  /// Original generated source, real Tab target and the actor's actual saved writer.
  /// The first release remains inside the original finite cutting-frame budget.
  static func released() async throws -> Game {
    var (game, site) = try NativePagedSalvageFixture.game()
    let body = try #require(game.bodies.first { $0.physical?.salvage?.wreck == site.identity })
    let metadata = try #require(body.physical?.salvage)
    let section = try #require(game.workSurface(for: body, metadata: metadata)?.section)
    game.selectFlightTool(.salvageCutter)
    try NativePagedSalvageFixture.engageSalvageTarget(&game, body: body, section: section)
    let folder = try NativePagedSalvageFixture.folder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let runtime = GameRuntime(game: game)
    let file = folder.appendingPathComponent("commander.json")
    try await runtime.save(to: file)
    await runtime.setControls(NativePagedSalvageFixture.firingControls)
    var released = await runtime.snapshot()
    for _ in 0..<2000 {
      released = await runtime.advance(delta: 0.02)
      if released.commander.alienStorageState?.current.salvage.native.works.values.contains(
        where: { $0.releases == 1 }) == true
      {
        break
      }
    }
    let native = try #require(released.commander.alienStorageState?.current.salvage)
    try #require(native.native.works.values.contains { $0.releases == 1 })
    try #require(native.pending.values.contains { $0.binding != nil })
    let published = try NativeSaveTestFixture.readVersionedCommander(from: file)
    #expect(published.savedAlienStorageReference == released.commander.savedAlienStorageReference)
    let disk = try #require(published.alienStorageState?.current.salvage)
    #expect(Set(disk.pending.keys) == Set(native.pending.keys))
    for pending in native.pending.values {
      #expect(disk.pending[pending.lot.identity]?.lot.loot == pending.lot.loot)
      #expect(disk.pending[pending.lot.identity]?.lot.content == pending.lot.content)
    }
    return released
  }

  /// A controlled cold parking boundary retains the original physically observed lot.
  /// No pending record or successful admission is fabricated for the negative checks.
  static func parked(_ input: Game, insideParent: Bool = false)
    throws -> (Game, AlienNativeSalvageIndex.Pending)
  {
    var game = input
    let native = try #require(game.commander.alienStorageState?.current.salvage)
    let original = try #require(
      native.pending.values.filter { $0.binding != nil }.sorted {
        $0.lot.identity.lot < $1.lot.identity.lot
      }.first)
    let binding = try #require(original.binding)
    let index = try #require(game.bodies.firstIndex { $0.physical?.identity == binding })
    if insideParent {
      let parent = try #require(
        game.bodies.first {
          $0.physical?.salvage?.wreck == original.lot.identity.section.wreck
            && $0.physical?.payload == nil
        })
      // Deliberately invalid physical placement is a negative geometry input.
      game.bodies[index].position = parent.position
    }
    let observed = game.observeNativeSalvageMotion(game.bodies[index])
    try #require(observed)
    let parked = game.flushNativeSalvageMotion(parking: [binding])
    try #require(parked)
    game.bodies.removeAll { $0.physical?.identity == binding }
    let pending = try #require(
      game.commander.alienStorageState?.current.salvage.pending[original.lot.identity])
    try #require(pending.offer == nil && pending.binding == nil)
    return (game, pending)
  }

  static func offered(_ input: Game, insideParent: Bool = false)
    throws -> (Game, AlienNativeSalvageIndex.Pending, SpawnRequest)
  {
    var (game, pending) = try parked(input, insideParent: insideParent)
    let context = try #require(game.gameplayContext())
    let allocated = game.commander.salvageLedger.reserveNativeSpawnIdentity(
      system: context.system, visit: context.visit)
    let spawn = try #require(allocated)
    let before = game.commander.salvageLedger
    let beforeWorld = try #require(game.commander.alienStorageState?.current.snapshot)
    let staged = game.stageNativeSalvageOffer(pending, spawn: spawn, context: context)
    try #require(staged)
    #expect(game.commander.salvageLedger == before)
    let afterWorld = try #require(game.commander.alienStorageState?.current.snapshot)
    #expect(
      afterWorld.sources == beforeWorld.sources && afterWorld.receipts == beforeWorld.receipts)
    #expect(
      afterWorld.attachments == beforeWorld.attachments
        && afterWorld.upgrades == beforeWorld.upgrades)
    #expect(
      afterWorld.commands == beforeWorld.commands && afterWorld.revision == beforeWorld.revision)
    #expect(
      afterWorld.world.filter { $0.id != pending.record }
        == beforeWorld.world.filter { $0.id != pending.record })
    return (game, pending, NativeSalvageOffer.request(lot: pending.lot, spawn: spawn))
  }

  static func changedRequest(
    _ original: SpawnRequest, identity: SpawnIdentity? = nil, position: Vector3? = nil,
    velocity: Vector3? = nil, orientation: Basis3? = nil, metadata: SalvageTargetMetadata? = nil,
    payload: PayloadIdentity? = nil
  ) -> SpawnRequest {
    var changed = SpawnRequest(
      identity: identity ?? original.identity, population: original.population, hull: original.hull,
      position: position ?? original.position, orientation: orientation ?? original.orientation,
      velocity: velocity ?? original.velocity, npc: original.npc, rock: original.rock,
      payload: payload ?? original.payload, priority: original.priority,
      salvage: metadata ?? original.salvage)
    changed.catalogueShipID = original.catalogueShipID
    changed.energy = original.energy
    changed.angularVelocity = original.angularVelocity
    return changed
  }

  static func changedContext(_ original: EncounterContext, mismatch: String) -> EncounterContext {
    var player = original.player
    if mismatch == "context player" {
      let identity = ActorIdentity(
        system: player.identity.system, visit: player.identity.visit,
        entity: player.identity.entity + 1)
      player = .init(
        identity: identity, hull: player.hull, position: player.position,
        orientation: player.orientation, velocity: player.velocity, energy: player.energy,
        maximumEnergy: player.maximumEnergy,
        maximumSpeedUnitsPerSecond: player.maximumSpeedUnitsPerSecond,
        legal: player.legal, npc: player.npc, rock: player.rock, payload: player.payload)
    }
    return .init(
      system: mismatch == "context system" ? .init(galaxy: 7, system: 255) : original.system,
      seed: original.seed, government: original.government,
      visit: original.visit + (mismatch == "context visit" ? 1 : 0),
      revision: original.revision + (mismatch == "context revision" ? 1 : 0),
      physicalTime: original.physicalTime + (mismatch == "context time" ? 0.01 : 0),
      anchors: original.anchors, player: player, actors: original.actors,
      protection: original.protection, budget: original.budget,
      perceptionRadius: original.perceptionRadius,
      depletedRocks: original.depletedRocks, miningPresence: original.miningPresence)
  }
}

struct NativeSalvageAdmissionRuntimeTests {
  @Test func genuineNativeReleaseAdmitsOnlyActualSafeActorsAndMovesThemInItsReleaseFrame()
    async throws
  {
    let released = try await NativeSalvageAdmissionTestFixture.released()
    let native = try #require(released.commander.alienStorageState?.current.salvage)
    let bound = native.pending.values.filter { $0.binding != nil }
    #expect(!bound.isEmpty && bound.count <= native.pending.count)
    for pending in bound {
      let binding = try #require(pending.binding)
      let body = try #require(released.bodies.first { $0.physical?.identity == binding })
      let world = released.commander.flightSimulation.pose.systemPoint(body.position)
      #expect((world - pending.lot.position - pending.lot.velocity * 0.02).length < 1e-7)
      #expect(released.currentSalvageLot(for: body)?.identity == pending.lot.identity)
      #expect(pending.offer == nil)
    }
    #expect(released.commander.nativeSalvageSceneIsConsistent(released.bodies, docked: false))
    let (offered, pending, request) = try NativeSalvageAdmissionTestFixture.offered(released)
    var readmitted = offered
    let context = try #require(readmitted.gameplayContext())
    let parent = try #require(
      context.actors.first {
        $0.salvage?.wreck == pending.lot.identity.section.wreck && $0.payload == nil
      })
    let parentBounds = try #require(parent.salvage?.bounds)
    let parentRadius = parentBounds.radius + parentBounds.center.length
    #expect(
      (request.position - parent.position).length < parentRadius + pending.lot.halfExtents.length
        + 8)
    let clears = readmitted.releasedFragmentClearsParent(request, parent: parent, context: context)
    #expect(clears)
    let receipts = readmitted.admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit, revision: context.revision,
        batches: [.init(requests: [request], atomic: false)], intents: []))
    #expect(receipts.count == 1 && receipts[0].refusal == nil && receipts[0].actor != nil)
    // This is only a private admission proposal. Production alone commits offer->binding
    // and publishes the candidate through the writer; the test grants no custody.
  }

  @Test func nativeOfferCannotBypassExactParentProtectionMeshPlayerOrOtherActorChecks()
    async throws
  {
    let released = try await NativeSalvageAdmissionTestFixture.released()
    for mismatch in [
      "unoffered", "unoffered allocated", "changed position", "changed bounds", "protected parent",
      "wrong wreck",
      "stale parent", "foreign parent", "unbound parent", "unrelated obstacle", "cargo sibling",
      "inside mesh",
      "player",
    ] {
      var (game, pending, request) = try NativeSalvageAdmissionTestFixture.offered(
        released, insideParent: mismatch == "inside mesh")
      let index = try #require(
        game.bodies.firstIndex {
          $0.physical?.salvage?.wreck == pending.lot.identity.section.wreck
            && $0.physical?.payload == nil
        })
      switch mismatch {
      case "unoffered":
        request = NativeSalvageAdmissionTestFixture.changedRequest(
          request,
          identity: .init(
            system: request.identity.system, visit: request.identity.visit,
            sequence: UInt64.max - 1, member: 0, producer: .salvage))
      case "unoffered allocated":
        let allocated = game.commander.salvageLedger.reserveNativeSpawnIdentity(
          system: request.identity.system, visit: request.identity.visit)
        let identity = try #require(allocated)
        request = NativeSalvageAdmissionTestFixture.changedRequest(request, identity: identity)
      case "changed position":
        request = NativeSalvageAdmissionTestFixture.changedRequest(
          request, position: request.position + .init(0.01, 0, 0))
      case "changed bounds":
        let metadata = try #require(request.salvage)
        request = NativeSalvageAdmissionTestFixture.changedRequest(
          request,
          metadata: .init(
            category: metadata.category, ownership: metadata.ownership, claimant: nil,
            wreck: metadata.wreck, section: metadata.section, lot: metadata.lot,
            bounds: .init(center: .init(0, 0, 0), radius: 0.1), workSurfaces: []))
      case "protected parent": game.bodies[index].navalTarget = true
      case "wrong wreck":
        let metadata = try #require(game.bodies[index].physical?.salvage)
        game.bodies[index].physical?.salvage = .init(
          category: metadata.category, ownership: metadata.ownership, claimant: nil,
          wreck: .init(system: game.systemIdentity, site: 89, lineage: 99), section: nil,
          lot: nil, bounds: metadata.bounds, workSurfaces: metadata.workSurfaces)
      case "stale parent", "foreign parent", "unbound parent":
        let physical = try #require(game.bodies[index].physical)
        let system =
          mismatch == "foreign parent"
          ? SystemIdentity(galaxy: 7, system: 255) : physical.identity.system
        let identity: ActorIdentity
        if mismatch == "unbound parent" {
          let allocated = game.commander.flightSimulation.allocateActor()
          identity = try #require(allocated)
        } else {
          identity = .init(
            system: system, visit: physical.identity.visit + (mismatch == "stale parent" ? 1 : 0),
            entity: physical.identity.entity)
        }
        game.bodies[index].physical = .init(
          identity: identity, population: physical.population, npc: physical.npc,
          velocity: physical.velocity, laserCooldown: physical.laserCooldown,
          rock: physical.rock, payload: physical.payload, attackOrigin: physical.attackOrigin,
          emissionPosition: physical.emissionPosition, deathOrigin: physical.deathOrigin,
          deathIncidentID: physical.deathIncidentID, ordnance: physical.ordnance,
          spawnIdentity: physical.spawnIdentity,
          blocksNavalEncounter: physical.blocksNavalEncounter,
          catalogueShipID: physical.catalogueShipID, angularVelocity: physical.angularVelocity,
          canonicalSpin: physical.canonicalSpin, salvage: physical.salvage,
          empSource: physical.empSource, empCrewPod: physical.empCrewPod,
          suspendedNPCIntention: physical.suspendedNPCIntention)
      case "unrelated obstacle":
        try addBlocker(&game, at: request.position)
      case "cargo sibling":
        try addBlocker(&game, at: request.position, metadata: request.salvage)
      case "player":
        var pose = game.commander.flightSimulation.pose
        pose.position = request.position
        NativePagedSalvageFixture.moveObserver(&game, to: pose)
      default: break
      }
      let context = try #require(game.gameplayContext())
      let before = game.commander
      let bodies = game.bodies
      let receipts = game.admitEncounterPlan(
        .init(
          system: context.system, visit: context.visit, revision: context.revision,
          batches: [.init(requests: [request], atomic: false)], intents: []))
      #expect(
        receipts.count == 1 && receipts[0].refusal == .unsafePosition && receipts[0].actor == nil)
      #expect(game.commander == before && game.bodies == bodies)
      #expect(
        game.commander.alienStorageState?.current.salvage.pending[pending.lot.identity]?.lot
          == pending.lot)
    }
  }

  @Test func refusedNativePlacementDiscardsPrivateOfferAndPreservesEveryReleasedLot()
    async throws
  {
    let released = try await NativeSalvageAdmissionTestFixture.released()
    var (game, pending) = try NativeSalvageAdmissionTestFixture.parked(released)
    var pose = game.commander.flightSimulation.pose
    pose.position = pending.lot.position
    NativePagedSalvageFixture.moveObserver(&game, to: pose)
    let before = game.commander
    let bodies = game.bodies
    game.admitPendingNativeSalvage()
    #expect(game.commander == before && game.bodies == bodies)
    let retained = try #require(
      game.commander.alienStorageState?.current.salvage.pending[pending.lot.identity])
    #expect(retained.lot == pending.lot && retained.binding == nil && retained.offer == nil)
  }

  @Test func fullActualCargoPopulationLeavesOriginalNativeCustodyAndAllocatorUntouched()
    async throws
  {
    let released = try await NativeSalvageAdmissionTestFixture.released()
    var (game, pending) = try NativeSalvageAdmissionTestFixture.parked(released)
    let initial = try #require(game.gameplayContext())
    let planet = (initial.player.position - initial.anchors.planet.position).unit
    let sun = (initial.player.position - initial.anchors.sun.position).unit
    var outward = (planet + sun).unit
    if outward.length == 0 {
      let axis = abs(planet.y) < 0.8 ? Vector3(0, 1, 0) : Vector3(1, 0, 0)
      outward = planet.cross(axis).unit
    }
    for index in 0..<PopulationClass.cargo.maximum {
      let context = try #require(game.gameplayContext())
      if context.budget.active[.cargo, default: 0] == PopulationClass.cargo.maximum { break }
      let request = SpawnRequest(
        identity: .init(
          system: context.system, visit: context.visit, sequence: UInt64(91000 + index), member: 0,
          producer: .provider),
        population: .cargo, hull: .cargo,
        position: initial.player.position + outward * Double(8000 + index * 500),
        orientation: .init(), velocity: .init(0, 0, 0), npc: nil, rock: nil, payload: nil,
        priority: .ordinary)
      let receipts = game.admitEncounterPlan(
        .init(
          system: context.system, visit: context.visit, revision: context.revision,
          batches: [.init(requests: [request], atomic: false)], intents: []))
      try #require(receipts.count == 1 && receipts[0].refusal == nil && receipts[0].actor != nil)
    }
    let full = try #require(game.gameplayContext())
    try #require(full.budget.active[.cargo, default: 0] == PopulationClass.cargo.maximum)
    let before = game.commander
    let bodies = game.bodies
    game.admitPendingNativeSalvage()
    #expect(game.commander == before && game.bodies == bodies)
    let retained = try #require(
      game.commander.alienStorageState?.current.salvage.pending[pending.lot.identity])
    #expect(retained.lot == pending.lot && retained.offer == nil && retained.binding == nil)
    // A staged offer still cannot bypass the actual common population gate.
    let allocated = game.commander.salvageLedger.reserveNativeSpawnIdentity(
      system: full.system, visit: full.visit)
    let spawn = try #require(allocated)
    let staged = game.stageNativeSalvageOffer(retained, spawn: spawn, context: full)
    try #require(staged)
    let offered = game.commander
    let receipts = game.admitEncounterPlan(
      .init(
        system: full.system, visit: full.visit, revision: full.revision,
        batches: [
          .init(
            requests: [NativeSalvageOffer.request(lot: retained.lot, spawn: spawn)], atomic: false)
        ],
        intents: []))
    #expect(
      receipts.count == 1 && receipts[0].refusal == .populationLimit && receipts[0].actor == nil)
    #expect(game.commander == offered && game.bodies == bodies)
  }

  @Test func nativeSectionNeverFallsBackToAnOriginalOrdinaryOffer() async throws {
    let released = try await NativeSalvageAdmissionTestFixture.released()
    var game = released
    let current = try #require(game.commander.alienStorageState?.current.salvage)
    let pending = try #require(current.pending.values.first { $0.binding != nil })
    let inspection = try #require(
      current.native.plans.values.first {
        $0.plan.section == pending.lot.identity.section
      })
    let section = try #require(current.native.sectionProfiles[inspection.id])
    let parentBody = try #require(
      game.bodies.first {
        $0.physical?.salvage?.wreck == pending.lot.identity.section.wreck
          && $0.physical?.payload == nil
      })
    let physical = try #require(parentBody.physical)
    var old = SalvageLedger(seed: inspection.seed)
    var remaining = section.workSeconds
    var operation: UInt64 = 0
    while remaining > 0 {
      let elapsed = min(1, remaining)
      operation += 1
      let produced = old.advance(
        wreck: inspection.plan.section.wreck, section: section,
        pose: game.modelPose(of: parentBody),
        velocity: physical.velocity, angularVelocity: physical.angularVelocity, tool: .cutter,
        elapsed: elapsed, operation: operation, conditions: NativePagedSalvageFixture.permitted,
        source: inspection.plan.source)
      remaining -= elapsed
      if remaining == 0 {
        guard case .released = produced else { throw SaveError.invalidCommander }
      } else {
        guard case .progress = produced else { throw SaveError.invalidCommander }
      }
    }
    let context = try #require(game.gameplayContext())
    let requests = old.spawnRequests(context: context)
    let request = try #require(requests.first { $0.payload == .salvage(pending.lot.identity) })
    try #require(old.offeredLot(for: request.identity) != nil)
    // This deliberately stale composite is a negative input: an old original
    // producer cannot reclaim a section that current native custody already owns.
    game.commander.salvageLedger = old
    let parent = try #require(context.actors.first { $0.identity == physical.identity })
    let before = game.commander
    let bodies = game.bodies
    let clears = game.releasedFragmentClearsParent(request, parent: parent, context: context)
    #expect(!clears)
    #expect(game.commander == before && game.bodies == bodies)
  }

  private func addBlocker(
    _ game: inout Game, at position: Vector3, metadata: SalvageTargetMetadata? = nil
  ) throws {
    let context = try #require(game.gameplayContext())
    let request = SpawnRequest(
      identity: .init(
        system: context.system, visit: context.visit, sequence: 90001, member: 0,
        producer: .provider),
      population: .cargo, hull: .cargo, position: position + .init(2000, 2000, 2000),
      orientation: .init(), velocity: .init(0, 0, 0), npc: nil, rock: nil, payload: nil,
      priority: .ordinary, salvage: metadata)
    let receipts = game.admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit, revision: context.revision,
        batches: [.init(requests: [request], atomic: false)], intents: []))
    let actor = try #require(receipts.first?.actor)
    let index = try #require(game.bodies.firstIndex { $0.physical?.identity == actor })
    // A genuinely allocated unrelated actor is moved into the way only as a
    // negative collision input. It is never used to establish successful release.
    game.bodies[index].position = game.commander.flightSimulation.pose.shipPoint(position)
  }
}
