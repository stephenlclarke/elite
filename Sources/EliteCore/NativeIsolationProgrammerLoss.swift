import Foundation

struct NativeIsolationProgrammerLossFacts: Codable, Equatable, Sendable {
  enum Kind: String, Codable, Sendable { case escape, hull }
  let kind: Kind
  let parent: UUID
  let issueOperation: UUID
  let source: EquipmentIssueSource
  let original: OwnedEquipmentItem
  let carrier: UUID
  let inventoryRevision: UInt64
  let player: ActorIdentity
  let energy: Double
  let pod: OwnedEquipmentItem?
  let sequence: UInt64
  let physicalTime: Double
  let context: ScriptEventContext
}

/// Historical facts of the native physical-loss application, never an equipment issue receipt.
struct NativeIsolationProgrammerLoss: Codable, Equatable, Sendable {
  let operation: UUID
  let facts: NativeIsolationProgrammerLossFacts
  static func identity(_ facts: NativeIsolationProgrammerLossFacts) throws -> UUID {
    ScriptIdentity.uuid("g11-original-programmer-loss-v1:\(try NativeFlightReception.hash(facts))")
  }
  func valid(
    parent: ScriptInstance, proof: NativeIsolationWorkParentState,
    commander: borrowing Commander
  ) -> Bool {
    let f = facts
    guard operation == (try? Self.identity(f)), f.parent == parent.id,
      f.issueOperation == proof.issue.operation, f.source == proof.issue.source,
      f.original.id == proof.issue.original,
      f.original.node == NativeIsolationProgrammerDefinition.node,
      f.original.location == nil, f.original.component == nil,
      f.original.boundHull == nil, f.original.preferredSlot == nil,
      f.original.retainedLegacyState == nil, f.original.nativeRepairLoopCondition == nil,
      f.original.provenance
        == .missionIssue(
          mission: parent.id, resource: NativeIsolationProgrammerDefinition.resource,
          index: 0, packDigest: parent.digest),
      f.inventoryRevision >= proof.inventoryRevision, f.inventoryRevision < UInt64(Int64.max),
      commander.equipmentInventory.map({ $0.revision > f.inventoryRevision }) == true,
      f.sequence > proof.sequence,
      f.sequence <= commander.scriptState.nextEvent, parent.hasAcknowledged(f.sequence),
      f.physicalTime.isFinite, f.physicalTime >= proof.physicalTime,
      f.physicalTime <= commander.flightSimulation.physicalTime,
      f.context.valid, !f.context.docked, !f.context.mainStation,
      f.context.nativeMainDock == nil, f.context.nativeStation == nil,
      f.context.revision <= parent.revision,
      f.context.calendarSeconds >= proof.acceptance.calendarSeconds,
      f.context.calendarSeconds <= commander.scriptState.calendarSeconds,
      f.context.flightSeconds <= commander.scriptState.flightSeconds,
      f.player.system == SystemIdentity(galaxy: f.context.galaxy, system: f.context.system),
      f.player.entity == 0, f.player.visit >= proof.acceptance.actor.visit,
      f.player.visit <= commander.flightSimulation.visit,
      f.energy.isFinite, (0...1e12).contains(f.energy),
      commander.equipmentInventory?.items.contains(where: { $0.id == f.original.id }) == false
    else { return false }
    switch f.kind {
    case .hull:
      return f.energy == 0 && f.pod == nil
    case .escape:
      guard f.energy > 0, let pod = f.pod,
        pod.node == EquipmentRuntimeCatalog.node(for: "Escape Pod"),
        pod.location
          == ComponentFittingLocation(hullInstanceID: f.carrier, slot: .utility(.escapePod)),
        commander.equipmentInventory?.items.contains(where: { $0.id == pod.id }) == false
      else { return false }
      return true
    }
  }
}

/// A fresh pre-consumption witness; decoded historical loss facts cannot mint it.
struct NativeIsolationProgrammerEscapePod: Sendable {
  let item: OwnedEquipmentItem
  let owner: UUID
  let carrier: UUID
  let inventoryRevision: UInt64
  let physicalTime: Double
  let epoch: UUID
  fileprivate init(
    item: OwnedEquipmentItem, inventory: OwnedEquipmentInventory, physicalTime: Double, epoch: UUID
  ) {
    self.item = item
    owner = inventory.owner
    carrier = inventory.activeHull
    inventoryRevision = inventory.revision
    self.physicalTime = physicalTime
    self.epoch = epoch
  }
}

extension Game {
  func isolationProgrammerEscapePod() -> NativeIsolationProgrammerEscapePod? {
    guard let parent = isolationWorkParentMission,
      parent.savedIsolationWorkParent?.cutoff == nil,
      let inventory = commander.equipmentInventory,
      let node = EquipmentRuntimeCatalog.node(for: "Escape Pod"),
      let item = inventory.items.first(where: {
        $0.node == node
          && $0.location == .init(hullInstanceID: inventory.activeHull, slot: .utility(.escapePod))
      })
    else { return nil }
    return .init(
      item: item, inventory: inventory,
      physicalTime: commander.flightSimulation.physicalTime, epoch: nativeStationRuntimeEpoch)
  }
  mutating func loseIsolationProgrammerOnEscape(pod: NativeIsolationProgrammerEscapePod?) throws {
    guard let parent = isolationWorkParentMission, parent.savedIsolationWorkParent?.cutoff == nil
    else { return }
    guard let pod, !docked, screen.isFlight, energy.isFinite, energy > 0,
      pod.owner == commander.equipmentOwnerID, pod.carrier == commander.hullInstanceID,
      pod.inventoryRevision < UInt64(Int64.max) - 1,
      commander.equipmentInventory?.revision == pod.inventoryRevision + 1,
      commander.equipmentInventory?.items.contains(where: { $0.id == pod.item.id }) == false,
      pod.physicalTime == commander.flightSimulation.physicalTime,
      pod.epoch == nativeStationRuntimeEpoch
    else { throw SaveError.invalidCommander }
    try stageIsolationProgrammerLoss(kind: .escape, pod: pod.item)
  }
  mutating func loseIsolationProgrammerOnFatalHull() throws {
    guard let parent = isolationWorkParentMission, parent.savedIsolationWorkParent?.cutoff == nil
    else { return }
    guard !docked, screen == .gameOver, energy.isFinite, energy <= 0 else {
      throw SaveError.invalidCommander
    }
    try stageIsolationProgrammerLoss(kind: .hull, pod: nil)
  }
  private mutating func stageIsolationProgrammerLoss(
    kind: NativeIsolationProgrammerLossFacts.Kind, pod: OwnedEquipmentItem?
  ) throws {
    guard var parent = isolationWorkParentMission,
      var proof = parent.savedIsolationWorkParent
    else { return }
    // A committed cutoff retains the original loss/return; retries cannot create another event.
    if proof.cutoff != nil { return }
    _ = try NativeIsolationWorkParent.primitive(parent: parent, commander: commander)
    let binding = try NativeIsolationProgrammerCustody.resolve(parent: parent, commander: commander)
    guard let inventory = commander.equipmentInventory,
      let original = inventory.items.first(where: { $0.id == binding.serial }),
      let player = commander.flightSimulation.player,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1,
      parent.revision < UInt64(Int64.max) - 1,
      let delta = try commander.scriptState.gearConsumptionDelta(for: original)
    else { throw SaveError.invalidCommander }
    let sequence = commander.scriptState.nextEvent + 1
    let facts = NativeIsolationProgrammerLossFacts(
      kind: kind, parent: parent.id, issueOperation: proof.issue.operation,
      source: delta.source, original: original, carrier: inventory.activeHull,
      inventoryRevision: inventory.revision, player: player, energy: max(0, energy), pod: pod,
      sequence: sequence, physicalTime: commander.flightSimulation.physicalTime,
      context: scriptEventContext(parent))
    let loss = NativeIsolationProgrammerLoss(
      operation: try NativeIsolationProgrammerLoss.identity(facts), facts: facts)
    var staged = commander
    staged.scriptState = try staged.scriptState.applying(delta)
    staged.savedEquipmentInventory = try inventory.applyingBatch(
      items: inventory.items.filter { $0.id != original.id }, expectedRevision: inventory.revision,
      context: EquipmentRuntimeCatalog.context(
        owner: inventory.owner, hull: inventory.activeHull, performance: staged.nativePerformance))
    parent = staged.scriptState.instances[parent.id]!
    proof.cutoff = .lost(loss)
    parent.savedIsolationWorkParent = proof
    parent.revision += 1
    parent.acknowledge(sequence)
    staged.scriptState.nextEvent = sequence
    staged.scriptState.instances[parent.id] = parent
    guard loss.valid(parent: parent, proof: proof, commander: staged) else {
      throw SaveError.invalidCommander
    }
    _ = try NativeIsolationWorkParent.primitive(parent: parent, commander: staged)
    commander = staged
  }
}

extension GameRuntime {
  func commitIsolationProgrammerFatalLoss() {
    guard game.screen == .gameOver, !game.docked, game.energy.isFinite, game.energy <= 0,
      game.isolationWorkParentMission?.savedIsolationWorkParent?.cutoff == nil,
      game.isolationWorkParentMission != nil
    else { return }
    do { try scriptCommand { try $0.loseIsolationProgrammerOnFatalHull() } } catch {
      game.notify("PROGRAMMER LOSS NOT SAVED - ORIGINAL CUSTODY RETAINED FOR RETRY")
    }
  }
}
