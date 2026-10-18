import Foundation
import Testing

@testable import EliteCore

/// Shares genuine setup only; every scenario receives its own Game value.
private actor NativeSalvageReleaseSnapshot {
  static let shared = NativeSalvageReleaseSnapshot()
  private var setup: Task<Game, Error>?

  func game() async throws -> Game {
    let task: Task<Game, Error>
    if let setup {
      task = setup
    } else {
      // Inherit the first caller's Testing context. Install before suspension so
      // concurrent callers share the same success or failure, with no retry/reset.
      let created = Task { try await NativeSalvageAdmissionTestFixture.makeReleased() }
      setup = created
      task = created
    }
    return try await task.value
  }
}

enum NativeSalvageAdmissionTestFixture {
  /// Original generated source, real Tab target and the actor's actual saved writer.
  /// The first release remains inside the original finite cutting-frame budget.
  static func released() async throws -> Game {
    try await NativeSalvageReleaseSnapshot.shared.game()
  }

  fileprivate static func makeReleased() async throws -> Game {
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
    // Existing nonthrowing assertions remain visible in the first caller's context.
    // Refuse a successful shared result if any publication comparison failed.
    guard published.savedAlienStorageReference == released.commander.savedAlienStorageReference,
      Set(disk.pending.keys) == Set(native.pending.keys),
      native.pending.values.allSatisfy({ pending in
        disk.pending[pending.lot.identity]?.lot.loot == pending.lot.loot
          && disk.pending[pending.lot.identity]?.lot.content == pending.lot.content
      }),
      released.pendingNewSaveDestination == nil, released.newCommanderSaveReceipt == nil
    else { throw SaveError.invalidCommander }
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

/// Authored original-format custody, not a historical archive or a fresh human bootstrap.
/// Its original producer and sealed import retain all eight emissions and old evidence.
private enum NativeSalvageOldParentFixture {
  struct Loaded {
    let runtime: GameRuntime
    let game: Game
    let site: SalvageSite
    let parent: SpaceBody
    let lots: [SalvageLot]
    let snapshot: AlienStorageSnapshot
    let immutable: [AlienStorageWorldRecord]
    let folder: URL
    let file: URL
    let generation: String
    let files: [String: Data]
  }

  static func loaded(format: String) async throws -> Loaded {
    var (game, site) = try NativePagedSalvageFixture.game(humanCargo: true)
    try #require(game.commander.alienStorageState == nil)
    let parent = try #require(game.bodies.first { $0.physical?.salvage?.wreck == site.identity })
    let physical = try #require(parent.physical)
    let profile = try #require(SalvageCatalogue.profile(catalogueShipID: site.catalogueShipID))
    let section = try #require(profile.sections.first { $0.index == 1 })
    let owner = try #require(game.commander.equipmentOwnerID)
    let identity = WreckSectionIdentity(wreck: site.identity, section: section.index)
    let source = SalvageLootSource(
      roles: profile.sourceRoles, legalValue: 0, economy: game.currentSystem.economy,
      technology: game.currentSystem.technology, ownership: .abandoned,
      manifest: [.init(commodity: .food, quantity: 120)])
    var producer = game.commander.salvageLedger
    var remaining = section.workSeconds
    var lots: [SalvageLot] = []
    while remaining > 0 {
      let elapsed = min(1, remaining)
      let allocated = game.commander.flightSimulation.allocateIncident()
      let operation = try #require(allocated)
      let result = producer.advance(
        wreck: site.identity, section: section, pose: game.modelPose(of: parent),
        velocity: physical.velocity, angularVelocity: physical.angularVelocity, tool: .cutter,
        elapsed: elapsed, operation: operation, conditions: NativePagedSalvageFixture.permitted,
        source: source)
      remaining -= elapsed
      if remaining == 0 {
        guard case .released(let emitted) = result else { throw SaveError.invalidCommander }
        lots = emitted
      } else {
        guard case .progress = result else { throw SaveError.invalidCommander }
      }
    }
    try #require(lots.count == 8)
    let original = try producer.exportNativeSection(identity)
    if format == "legacy-current" {
      game.commander.salvageLedger = producer
      let imported = try NativeSalvageImport(
        ledger: producer, section: identity, owner: owner,
        at: game.commander.flightSimulation.physicalTime, previous: nil)
      try imported.apply(to: &game.commander)
    } else {
      let id = UUID()
      var world: [AlienStorageWorldRecord] = [
        .plan(
          .init(
            id: id, owner: owner, seed: original.seed, plan: original.plan, inspectedAt: 0,
            requiredWorkSeconds: section.workSeconds, workSeconds: section.workSeconds,
            damagedTechnology: original.damagedTechnology, depleted: original.depleted,
            destroyed: false, lastOperation: original.lastOperation, progress: original.progress))
      ]
      let emissions = try SalvageSectionEmissionView(
        seed: original.seed, plan: original.plan, progress: original.progress
      ).emissions()
      for lot in lots {
        let origin = try #require(emissions.first { $0.value.identity == lot.identity }?.key)
        world.append(
          .companion(
            .init(
              id: UUID(), owner: owner, plan: id, origin: origin, issuedAt: 0,
              state: .pending(lot: lot, physicalTime: 0, offer: nil, binding: nil))))
      }
      try game.commander.replaceAlienStorage(
        with: .init(
          owner: owner, revision: 0, worldRevision: 1, world: world, sources: [], attachments: [],
          upgrades: [], receipts: [], commands: []))
    }
    let old = try #require(game.commander.alienStorageState?.current.snapshot)
    let (oldRoot, oldPages) = try NativeSalvageReleasedOldFormat.encode(old)
    let folder = try NativePagedSalvageFixture.folder()
    var completed = false
    defer { if !completed { try? FileManager.default.removeItem(at: folder) } }
    let file = folder.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: file)
    let saved = await runtime.snapshot()
    let bytes = try Data(contentsOf: file)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == 27)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let oldPointer = try encoder.encode(
      FrozenV27SavePointer(generation: pointer.generation, hashes: pointer.hashes))
    #expect(oldPointer == bytes)
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: file)
    let store = try AlienStoragePageStore(directory: directory)
    let root = try store.readGenerationRoot()
    #expect(root == oldRoot && pointer.hashes["alien-root.json"] == ScriptPackLibrary.hash(oldRoot))
    for (hash, expected) in oldPages {
      let actual = try store.readPage(hash: hash)
      #expect(actual == expected)
    }
    let before = try files(in: folder)
    try await runtime.load(from: file, persistMigrations: false)
    let loaded = await runtime.snapshot()
    #expect(loaded.commander == saved.commander && loaded.bodies == saved.bodies)
    #expect(loaded.commander.alienStorageState?.current.snapshot == old)
    #expect(loaded.commander.alienStorageState?.current.salvage.native.wrecks.isEmpty == true)
    #expect(loaded.nativeSalvageWork == nil)
    let after = try files(in: folder)
    #expect(after == before)
    let immutable = old.world.filter {
      switch $0 {
      case .plan, .legacySection, .legacyLot: true
      default: false
      }
    }
    completed = true
    return .init(
      runtime: runtime, game: loaded, site: site, parent: parent, lots: lots, snapshot: old,
      immutable: immutable, folder: folder, file: file, generation: pointer.generation,
      files: before)
  }

  static func files(in folder: URL) throws -> [String: Data] {
    var result: [String: Data] = [:]
    let enumerator = try #require(
      FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey]))
    for case let url as URL in enumerator {
      if try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
        result[String(url.path.dropFirst(folder.path.count + 1))] = try Data(contentsOf: url)
      }
    }
    return result
  }
}

/// Failure-only scalar facts; eight rows and an ASCII UTF-8 ceiling prevent corpus dumps.
private func oldParentClearanceFacts(
  format: String, body: SpaceBody, pose: ShipPose, metadata: SalvageTargetMetadata,
  lots: [SalvageLot], results: [SalvageLotIdentity: HullSweepResult]
) -> String {
  func vector(_ value: Vector3) -> String { "(\(value.x),\(value.y),\(value.z))" }
  func asciiField(_ value: String) -> String {
    String(decoding: value.utf8.prefix(16).filter { $0 < 128 }, as: UTF8.self)
  }
  let catalogue = asciiField(body.physical?.catalogueShipID ?? "nil")
  let velocity = body.physical.map { vector($0.velocity) } ?? "nil"
  let angular = body.physical.map { vector($0.angularVelocity) } ?? "nil"
  var rows = [
    "No original released lot proves mesh clearance and broad-parent overlap",
    "format=\(asciiField(format)) catalogue=\(catalogue) pose=\(vector(pose.position))"
      + " basisX=\(vector(pose.orientation.x)) basisY=\(vector(pose.orientation.y))"
      + " basisZ=\(vector(pose.orientation.z)) v=\(velocity) omega=\(angular)"
      + " broadRadius=\(metadata.bounds.radius) broadCenter=\(vector(metadata.bounds.center))"
      + " broadReach=\(metadata.bounds.radius + metadata.bounds.center.length)",
  ]
  for lot in lots.prefix(8) {
    let id = lot.identity
    let wreck = id.section.wreck
    let identity =
      "\(wreck.system.galaxy)/\(wreck.system.system)/\(wreck.site)/\(wreck.lineage)"
      + "/\(id.section.section)/\(id.lot)"
    let result = results[id]
    let reason = result?.failure.map { String(describing: $0) } ?? "none"
    let minimum = result?.minimumSampledClearance.map { String($0) } ?? "nil"
    let overlap =
      (lot.position - pose.position).length < metadata.bounds.radius
      + metadata.bounds.center.length + lot.halfExtents.length + 8
    rows.append(
      "lot=\(identity) p=\(vector(lot.position)) half=\(vector(lot.halfExtents))"
        + " broad=\(overlap) safe=\(result?.safe ?? false) reason=\(reason) min=\(minimum)")
  }
  // All emitted fields are ASCII scalars/identities; reserve one byte for the newline.
  return String(decoding: rows.joined(separator: "\n").utf8.prefix(4095), as: UTF8.self) + "\n"
}

struct NativeSalvageOldParentAdmissionTests {
  @Test(arguments: ["old-native", "legacy-current"])
  func originalReleasedOldCustodyReadmitsAfterRealNoWriteLoadWithoutAnotherCut(format: String)
    async throws
  {
    let fixture = try await NativeSalvageOldParentFixture.loaded(format: format)
    defer { try? FileManager.default.removeItem(at: fixture.folder) }
    let body = try #require(fixture.game.bodies.first { $0.id == fixture.parent.id })
    let metadata = try #require(body.physical?.salvage)
    let profile = try #require(
      SalvageCatalogue.profile(catalogueShipID: fixture.site.catalogueShipID))
    let hull = try PreparedHull(mesh: profile.mesh)
    let pose = fixture.game.modelPose(of: body)
    // Original emission order is fixed; its first row need not clear every hull component.
    var clearanceResults: [SalvageLotIdentity: HullSweepResult] = [:]
    let selected = fixture.lots.first { lot in
      let overlapsParent =
        (lot.position - pose.position).length < metadata.bounds.radius
        + metadata.bounds.center.length + lot.halfExtents.length + 8
      guard overlapsParent else { return false }
      let clearance = HullSweepSafety.validatePlacement(
        center: lot.position, radius: lot.halfExtents.length, hull: hull, pose: pose,
        requiredClearance: 8)
      clearanceResults[lot.identity] = clearance
      return clearance.safe && (clearance.minimumSampledClearance ?? -.infinity) > 8
    }
    let failureMessage: String
    if selected == nil {
      // Reuse every selector result; only unqueried originals complete the eight-row inventory.
      for lot in fixture.lots.prefix(8) where clearanceResults[lot.identity] == nil {
        clearanceResults[lot.identity] = HullSweepSafety.validatePlacement(
          center: lot.position, radius: lot.halfExtents.length, hull: hull, pose: pose,
          requiredClearance: 8)
      }
      failureMessage = oldParentClearanceFacts(
        format: format, body: body, pose: pose, metadata: metadata, lots: fixture.lots,
        results: clearanceResults)
    } else {
      failureMessage = "No original released lot proves mesh clearance and broad-parent overlap"
    }
    let originalPhysical = try #require(body.physical)
    let originalPlayer = try #require(fixture.game.commander.flightSimulation.player)
    let originalOwner = try #require(fixture.game.commander.equipmentOwnerID)
    let originalSeed = fixture.game.commander.salvageLedger.nativeInspectionSeed
    let identities = Set(fixture.lots.map(\.identity))
    func invariantFailure(_ game: Game, allowingBindings: Bool) -> String? {
      guard !game.docked, !game.paused, game.screen.isFlight, game.energy > 0,
        game.systemIdentity == fixture.game.systemIdentity, game.jumpCountdown == nil,
        game.commander.flightSimulation.player == originalPlayer,
        game.commander.equipmentOwnerID == originalOwner,
        game.commander.salvageLedger.nativeInspectionSeed == originalSeed
      else { return "flight/player/owner changed" }
      let parents = game.bodies.filter { $0.physical?.identity == originalPhysical.identity }
      guard parents.count == 1, let current = parents.first, let physical = current.physical,
        current.id == body.id, current.hull == body.hull, current.energy > 0,
        current.rotationRate == body.rotationRate, physical.salvage == metadata,
        physical.catalogueShipID == originalPhysical.catalogueShipID,
        physical.spawnIdentity == originalPhysical.spawnIdentity, physical.spawnIdentity != nil,
        physical.canonicalSpin == true, physical.npc == nil, physical.payload == nil,
        physical.velocity == originalPhysical.velocity,
        physical.angularVelocity == originalPhysical.angularVelocity
      else { return "parent identity/source/motion/liveness changed" }
      guard let context = game.gameplayContext(), context.player.identity == originalPlayer,
        !context.protection.protectedActors.contains(originalPhysical.identity),
        fixture.lots.allSatisfy({
          !context.protection.protectedPayloads.contains(.salvage($0.identity))
            && ($0.position - context.player.position).length <= context.perceptionRadius
        })
      else { return "parent/lot protection or perception changed" }
      guard let state = game.commander.alienStorageState?.current,
        Set(state.salvage.pending.keys) == identities, state.snapshot.owner == originalOwner,
        game.nativeSalvageWork == nil, game.workGuidance == nil, game.workBraking == nil,
        state.salvage.native.works.isEmpty, state.salvage.native.inspections.isEmpty,
        fixture.immutable.allSatisfy(state.snapshot.world.contains)
      else { return "custody/history/work changed" }
      if let retained = state.salvage.native.wrecks[fixture.site.identity] {
        guard retained.binding == originalPhysical.identity,
          retained.source == .generated(fixture.site), retained.seed == originalSeed,
          retained.destroyedAt == nil
        else { return "retained parent source/binding changed" }
      }
      for lot in fixture.lots {
        guard let pending = state.salvage.pending[lot.identity], pending.offer == nil,
          pending.lot.content == lot.content, pending.lot.loot == lot.loot,
          pending.lot.massKg == lot.massKg, pending.lot.halfExtents == lot.halfExtents
        else { return "original lot custody changed" }
        if pending.binding == nil {
          guard pending.lot == lot else { return "unbound original lot moved/changed" }
        } else if !allowingBindings {
          return "binding preceded observed first transition"
        }
      }
      return nil
    }
    func boundedWaitFailure(_ reason: String, frame: Int) -> Comment {
      let text = "old-readmission frame=\(frame)/1400 reason=\(reason)\n" + failureMessage
      return Comment(rawValue: String(decoding: text.utf8.prefix(4095), as: UTF8.self) + "\n")
    }
    // Actual388 showed no original was initially eligible. The analytic moving-parent
    // window supports this finite cap only; real pre-frame geometry controls acceptance.
    var preFrame = fixture.game
    var admitted = fixture.game
    var newlyBound: [SalvageLot] = []
    var frames = 0
    for frame in 1...1400 {
      preFrame = admitted
      if let reason = invariantFailure(preFrame, allowingBindings: false) {
        let valid = false
        try #require(valid, boundedWaitFailure(reason, frame: frame))
      }
      let before = try #require(preFrame.commander.alienStorageState?.current.salvage)
      // No control, cutter, target acquisition, copied actor or synthetic motion is supplied.
      admitted = await fixture.runtime.advance(delta: 0.02)
      frames = frame
      if let reason = invariantFailure(admitted, allowingBindings: true) {
        let valid = false
        try #require(valid, boundedWaitFailure(reason, frame: frame))
      }
      let after = try #require(admitted.commander.alienStorageState?.current.salvage)
      let previousParent = try #require(
        preFrame.bodies.first { $0.physical?.identity == originalPhysical.identity })
      let currentParent = try #require(
        admitted.bodies.first { $0.physical?.identity == originalPhysical.identity })
      let parentStep =
        admitted.modelPose(of: currentParent).position
        - preFrame.modelPose(of: previousParent).position - originalPhysical.velocity * 0.02
      let timeStep =
        admitted.commander.flightSimulation.physicalTime
        - preFrame.commander.flightSimulation.physicalTime
      let genuineStep = parentStep.length < 1e-7 && abs(timeStep - 0.02) < 1e-7
      try #require(genuineStep, boundedWaitFailure("parent/time step changed", frame: frame))
      newlyBound = fixture.lots.filter {
        before.pending[$0.identity]?.binding == nil && after.pending[$0.identity]?.binding != nil
      }
      if !newlyBound.isEmpty { break }
    }
    let observedTransition = !newlyBound.isEmpty
    try #require(
      observedTransition, boundedWaitFailure("no binding within finite cap", frame: frames))
    let admissionParent = try #require(
      preFrame.bodies.first { $0.physical?.identity == originalPhysical.identity })
    let admissionPose = preFrame.modelPose(of: admissionParent)
    let originalCustody = try #require(preFrame.commander.alienStorageState?.current.salvage)
    var eligibleOriginal: SalvageLot?
    // At most eight additional queries: only originals actually bound in the FIRST transition.
    // Their saved unbound poses and this authentic pre-frame parent pose are the oracle.
    for lot in newlyBound.prefix(8) {
      let pending = try #require(originalCustody.pending[lot.identity])
      try #require(pending.binding == nil && pending.offer == nil && pending.lot == lot)
      let broad =
        (lot.position - admissionPose.position).length < metadata.bounds.radius
        + metadata.bounds.center.length + lot.halfExtents.length + 8
      let clearance = HullSweepSafety.validatePlacement(
        center: lot.position, radius: lot.halfExtents.length, hull: hull, pose: admissionPose,
        requiredClearance: 8)
      if broad && clearance.safe && (clearance.minimumSampledClearance ?? -.infinity) > 8 {
        eligibleOriginal = lot
        break
      }
    }
    let strictTransition = eligibleOriginal != nil
    try #require(
      strictTransition,
      boundedWaitFailure("first binding lacks strict pre-frame proof", frame: frames))
    let first = try #require(eligibleOriginal)
    #expect(
      (first.position - admissionPose.position).length < metadata.bounds.radius
        + metadata.bounds.center.length + first.halfExtents.length + 8)
    let native = try #require(admitted.commander.alienStorageState?.current.salvage)
    let parent = try #require(native.native.wrecks[fixture.site.identity])
    #expect(parent.binding == body.physical?.identity && parent.source == .generated(fixture.site))
    #expect(
      admitted.nativeSalvageWork == nil && native.native.works.isEmpty
        && native.native.inspections.isEmpty)
    #expect(Set(native.pending.keys) == Set(fixture.lots.map(\.identity)))
    for lot in fixture.lots {
      let pending = try #require(native.pending[lot.identity])
      #expect(pending.lot.content == lot.content && pending.lot.loot == lot.loot)
      #expect(pending.lot.massKg == lot.massKg && pending.lot.halfExtents == lot.halfExtents)
      #expect(pending.offer == nil)
    }
    let binding = try #require(native.pending[first.identity]?.binding)
    let fragment = try #require(admitted.bodies.first { $0.physical?.identity == binding })
    let position = admitted.commander.flightSimulation.pose.systemPoint(fragment.position)
    let actualOwnership = admitted.commander.nativeSalvageBodyOwnershipMatches(fragment, lot: first)
    try #require(actualOwnership)
    #expect(fragment.physical?.payload == .salvage(first.identity))
    #expect(fragment.physical?.velocity == first.velocity && fragment.energy > 0)
    #expect((position - first.position - first.velocity * 0.02).length < 1e-7)
    let currentWorld = try #require(admitted.commander.alienStorageState?.current.snapshot.world)
    #expect(fixture.immutable.allSatisfy(currentWorld.contains))
    let unchanged = try NativeSalvageOldParentFixture.files(in: fixture.folder)
    #expect(unchanged == fixture.files)
    try await fixture.runtime.save(to: fixture.file)
    let saved = await fixture.runtime.snapshot()
    let beforeLoad = try NativeSalvageOldParentFixture.files(in: fixture.folder)
    try await fixture.runtime.load(from: fixture.file, persistMigrations: false)
    let loaded = await fixture.runtime.snapshot()
    #expect(loaded.commander == saved.commander && loaded.bodies == saved.bodies)
    let afterLoad = try NativeSalvageOldParentFixture.files(in: fixture.folder)
    #expect(afterLoad == beforeLoad)
    for (relative, bytes) in fixture.files
    where relative.hasPrefix("commander.json.missions/" + fixture.generation + "/") {
      #expect(afterLoad[relative] == bytes)
    }
  }

  @Test(arguments: ["wrong source", "protected parent", "player blocked", "retained mismatch"])
  func oldParentFactoryAndGeometryRefusalsPreserveAllOriginalCustody(mismatch: String)
    async throws
  {
    let fixture = try await NativeSalvageOldParentFixture.loaded(format: "legacy-current")
    defer { try? FileManager.default.removeItem(at: fixture.folder) }
    var game = fixture.game
    let index = try #require(game.bodies.firstIndex { $0.id == fixture.parent.id })
    switch mismatch {
    case "wrong source": game.bodies[index].physical?.catalogueShipID = "SH001"
    case "protected parent": game.bodies[index].navalTarget = true
    case "player blocked":
      var pose = game.commander.flightSimulation.pose
      pose.position = try #require(fixture.lots.first).position
      NativePagedSalvageFixture.moveObserver(&game, to: pose)
    default:
      let retained = game.retainNativeSalvageWreck(game.bodies[index])
      try #require(retained)
      let old = try #require(game.bodies[index].physical)
      let allocated = game.commander.flightSimulation.allocateActor()
      let actor = try #require(allocated)
      game.bodies[index].physical = .init(
        identity: actor, population: old.population, npc: old.npc, velocity: old.velocity,
        laserCooldown: old.laserCooldown, rock: old.rock, payload: old.payload,
        attackOrigin: old.attackOrigin, emissionPosition: old.emissionPosition,
        deathOrigin: old.deathOrigin, deathIncidentID: old.deathIncidentID, ordnance: old.ordnance,
        spawnIdentity: old.spawnIdentity, blocksNavalEncounter: old.blocksNavalEncounter,
        catalogueShipID: old.catalogueShipID, angularVelocity: old.angularVelocity,
        canonicalSpin: old.canonicalSpin, salvage: old.salvage, empSource: old.empSource,
        empCrewPod: old.empCrewPod, suspendedNPCIntention: old.suspendedNPCIntention)
    }
    let before = game.commander
    let bodies = game.bodies
    let original = try #require(before.alienStorageState?.current.salvage)
    let first = try #require(fixture.lots.first)
    if mismatch == "protected parent" {
      let body = game.bodies[index]
      let bounds = try #require(body.physical?.salvage?.bounds)
      let distance = (first.position - game.modelPose(of: body).position).length
      try #require(distance < bounds.radius + bounds.center.length + first.halfExtents.length + 8)
    } else if mismatch == "player blocked" {
      let radius = try #require(game.commander.playerMesh.vertices.map(\.length).max())
      try #require(
        (first.position - game.commander.flightSimulation.pose.position).length <= radius
          + first.halfExtents.length + 8)
    }
    game.admitPendingNativeSalvage()
    if mismatch == "wrong source" || mismatch == "retained mismatch" {
      // This source/binding mismatch rejects every lot before namespace allocation.
      #expect(game.commander == before && game.bodies == bodies)
    } else {
      let current = try #require(game.commander.alienStorageState?.current.salvage)
      #expect(Set(current.pending.keys) == Set(original.pending.keys))
      let refused = try #require(current.pending[first.identity])
      #expect(refused.binding == nil && refused.offer == nil && refused.lot == first)
      #expect(!game.bodies.contains { $0.physical?.payload == .salvage(first.identity) })
      for old in original.pending.values {
        let retained = try #require(current.pending[old.lot.identity])
        #expect(retained.lot == old.lot && retained.physicalTime == old.physicalTime)
        #expect(retained.offer == nil)
        if let binding = retained.binding {
          let body = try #require(game.bodies.first { $0.physical?.identity == binding })
          #expect(game.currentSalvageLot(for: body)?.identity == old.lot.identity)
        }
      }
      let world = try #require(game.commander.alienStorageState?.current.snapshot.world)
      #expect(fixture.immutable.allSatisfy(world.contains))
      #expect(game.commander.credits == before.credits && game.commander.cargo == before.cargo)
      #expect(game.commander.equipmentInventory == before.equipmentInventory)
      #expect(game.commander.flightSimulation.physicalTime == before.flightSimulation.physicalTime)
      #expect(game.commander.nativeSalvageSceneIsConsistent(game.bodies, docked: false))
    }
    let observed = try NativeSalvageOldParentFixture.files(in: fixture.folder)
    #expect(observed == fixture.files)
  }

  @Test func actualParentDeathDoesNotRequireALiveParentToReadmitReleasedOldLots() async throws {
    let fixture = try await NativeSalvageOldParentFixture.loaded(format: "old-native")
    defer { try? FileManager.default.removeItem(at: fixture.folder) }
    var game = fixture.game
    let parent = try #require(game.bodies.first { $0.id == fixture.parent.id })
    let player = try #require(game.commander.flightSimulation.player)
    let allocated = game.makeAttackOrigin(owner: player)
    let origin = try #require(allocated)
    let contact = try game.nearestMissionCollision(
      from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 300, radius: 0,
      includePlayer: false)
    let hit = try #require(contact?.hit)
    try #require(hit.target == .body(parent.id))
    // Controlled lethal native hit/death settlement, not a stock pulse firing or
    // damage/cadence/energy-cost acceptance test.
    let applied = game.applyCombatHit(
      hit, origin: origin, kind: .laser, damage: parent.energy + 1, laser: .pulse)
    try #require(applied != nil)
    game.commander.crimeLedger.finishEmission(origin.emissionID)
    game.resolveDestroyed()
    try #require(!game.bodies.contains { $0.id == parent.id })
    try #require(game.commander.salvageLedger.isWreckDestroyed(fixture.site.identity))
    #expect(game.commander.alienStorageState?.current.snapshot == fixture.snapshot)
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: fixture.file)
    let admitted = await runtime.advance(delta: 0.02)
    let native = try #require(admitted.commander.alienStorageState?.current.salvage)
    #expect(native.native.wrecks.isEmpty && admitted.nativeSalvageWork == nil)
    #expect(native.pending.values.contains { $0.binding != nil })
    #expect(Set(native.pending.keys) == Set(fixture.lots.map(\.identity)))
    for lot in fixture.lots { #expect(native.pending[lot.identity]?.lot.loot == lot.loot) }
  }
}

/// Original schema-27 pending records only. New native tags are deliberately rejected.
/// Field tables are frozen separately from the current page encoder, like FrozenV27SalvageFormat.
/// Pending companion/legacy field tables match 55d57c4f5d1e3a61562cd13c55355d54051a48ad.
private enum NativeSalvageReleasedOldFormat {
  struct Companion: Encodable {
    enum State: Encodable {
      case pending(
        lot: SalvageLot, physicalTime: Double, offer: SpawnIdentity?, binding: ActorIdentity?)
    }
    let id: UUID
    let owner: UUID
    let plan: UUID
    let origin: AlienStorageEmissionOrigin
    let issuedAt: Double
    let state: State
  }
  struct LegacyLot: Encodable {
    enum State: Encodable {
      case pending(lot: SalvageLot, offer: SpawnIdentity?, binding: ActorIdentity?)
    }
    let id: UUID
    let owner: UUID
    let section: UUID
    let origin: AlienStorageEmissionOrigin
    let identity: SalvageLotIdentity
    let state: State
  }
  struct LegacyCurrent: Encodable {
    enum State: Encodable {
      case pending(lot: SalvageLot, at: Double, offer: SpawnIdentity?, binding: ActorIdentity?)
    }
    let id: UUID
    let owner: UUID
    let claim: UUID
    let state: State
  }
  enum World: Encodable {
    case plan(FrozenV27WorldPlan)
    case companion(Companion)
    case legacySection(FrozenV27LegacySection)
    case legacyLot(LegacyLot)
    case legacyCurrent(LegacyCurrent)

    init(_ value: AlienStorageWorldRecord) throws {
      switch value {
      case .plan(let p):
        self = .plan(
          .init(
            id: p.id, owner: p.owner, seed: p.seed, plan: p.plan, inspectedAt: p.inspectedAt,
            requiredWorkSeconds: p.requiredWorkSeconds, workSeconds: p.workSeconds,
            damagedTechnology: p.damagedTechnology, depleted: p.depleted, destroyed: p.destroyed,
            lastOperation: p.lastOperation, progress: .init(p.progress)))
      case .companion(let p):
        guard case .pending(let lot, let time, let offer, let binding) = p.state else {
          throw AlienStorageError.invalidPage
        }
        self = .companion(
          .init(
            id: p.id, owner: p.owner, plan: p.plan, origin: p.origin,
            issuedAt: p.issuedAt,
            state: .pending(lot: lot, physicalTime: time, offer: offer, binding: binding)))
      case .legacySection(let p):
        self = .legacySection(
          .init(
            id: p.id, owner: p.owner, importOperation: p.importOperation, importedAt: p.importedAt,
            ledgerRevision: p.ledgerRevision, seed: p.seed, plan: p.plan,
            progress: .init(p.progress),
            savedPartialWorkSeconds: p.savedPartialWorkSeconds,
            savedDamagedTechnology: p.savedDamagedTechnology, sectionDepleted: p.sectionDepleted,
            sectionDestroyed: p.sectionDestroyed, wreckDestroyed: p.wreckDestroyed,
            savedLedgerLastOperation: p.savedLedgerLastOperation))
      case .legacyLot(let p):
        guard case .pending(let lot, let offer, let binding) = p.state else {
          throw AlienStorageError.invalidPage
        }
        self = .legacyLot(
          .init(
            id: p.id, owner: p.owner, section: p.section, origin: p.origin,
            identity: p.identity, state: .pending(lot: lot, offer: offer, binding: binding)))
      case .legacyCurrent(let p):
        guard case .pending(let lot, let time, let offer, let binding) = p.state else {
          throw AlienStorageError.invalidPage
        }
        self = .legacyCurrent(
          .init(
            id: p.id, owner: p.owner, claim: p.claim,
            state: .pending(lot: lot, at: time, offer: offer, binding: binding)))
      default: throw AlienStorageError.invalidPage
      }
    }
  }
  enum Payload: Encodable { case world(World) }
  struct Entry: Encodable {
    let key: String
    let payload: Payload
  }
  struct Tree: Encodable {
    let hash: String?
    let count: UInt64
    let height: UInt64
    let firstKey: String?
    let lastKey: String?
    static let empty = Self(hash: nil, count: 0, height: 0, firstKey: nil, lastKey: nil)
  }
  struct Index: Encodable {
    let index: String
    let tree: Tree
  }
  struct Root: Encodable {
    let version: Int
    let owner: UUID
    let revision: UInt64
    let worldRevision: UInt64
    let indices: [Index]
  }
  struct Page: Encodable {
    let version: Int
    let owner: UUID
    let index: String
    let height: UInt64
    let entries: [Entry]
    let children: [Tree]
  }
  static func encode(_ snapshot: AlienStorageSnapshot) throws -> (Data, [String: Data]) {
    guard snapshot.world.count <= 128, snapshot.sources.isEmpty, snapshot.attachments.isEmpty,
      snapshot.upgrades.isEmpty, snapshot.receipts.isEmpty, snapshot.commands.isEmpty
    else { throw AlienStorageError.invalidPage }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let entries = try snapshot.world.sorted { $0.id.uuidString < $1.id.uuidString }.map {
      Entry(key: $0.id.uuidString, payload: .world(try .init($0)))
    }
    var pages: [String: Data] = [:]
    var indices: [Index] = []
    for index in ["sources", "attachments", "upgrades", "receipts", "commands", "world"] {
      var tree = Tree.empty
      if index == "world", !entries.isEmpty {
        let bytes = try encoder.encode(
          Page(
            version: 1, owner: snapshot.owner, index: index,
            height: 0, entries: entries, children: []))
        guard bytes.count <= 262144 else { throw AlienStorageError.oversizedRecord }
        let hash = ScriptPackLibrary.hash(bytes)
        pages[hash] = bytes
        tree = .init(
          hash: hash, count: UInt64(entries.count), height: 0,
          firstKey: entries.first?.key, lastKey: entries.last?.key)
      }
      indices.append(.init(index: index, tree: tree))
    }
    let root = try encoder.encode(
      Root(
        version: 1, owner: snapshot.owner,
        revision: snapshot.revision, worldRevision: snapshot.worldRevision, indices: indices))
    return (root, pages)
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
        let system = game.systemIdentity
        game.bodies[index].physical?.salvage = .init(
          category: metadata.category, ownership: metadata.ownership, claimant: nil,
          wreck: .init(system: system, site: 89, lineage: 99), section: nil,
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
    let fresh = try await NativeSalvageAdmissionTestFixture.released()
    #expect(fresh.commander == released.commander && fresh.bodies == released.bodies)
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
