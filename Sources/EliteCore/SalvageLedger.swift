import Foundation

public struct SalvageWreckMotion: Equatable, Codable, Sendable {
  public let pose: ShipPose
  public let velocity: Vector3
  public let angularVelocity: Vector3
  public let energy: Double?
  public init(pose: ShipPose, velocity: Vector3, angularVelocity: Vector3, energy: Double? = nil) {
    self.pose = pose
    self.velocity = velocity
    self.angularVelocity = angularVelocity
    self.energy = energy
  }
}

public enum SalvageTool: String, Codable, Sendable { case cutter, miningLaser }

public struct SalvageWorkConditions: Equatable, Codable, Sendable {
  public let toolInstalled: Bool
  public let inRange: Bool
  public let aligned: Bool
  public let lineOfSight: Bool
  public let resourcesAvailable: Bool
  public let ownershipAuthorized: Bool
  public var permitsWork: Bool {
    toolInstalled && inRange && aligned && lineOfSight && resourcesAvailable && ownershipAuthorized
  }
}

public enum SalvageLotContent: Equatable, Codable, Sendable {
  case commodity(CommodityAmount)
  case technology(definitionID: String, quality: SalvageQuality, conditionPercent: Int)
}

public struct SalvageLot: Equatable, Codable, Sendable {
  public let identity: SalvageLotIdentity
  public let content: SalvageLotContent
  public var position: Vector3
  public var velocity: Vector3
  public let halfExtents: Vector3
  public let massKg: Double
  public let loot: SalvageLootItem?
  public init(
    identity: SalvageLotIdentity, content: SalvageLotContent, position: Vector3,
    velocity: Vector3, halfExtents: Vector3, massKg: Double, loot: SalvageLootItem? = nil
  ) {
    self.identity = identity
    self.content = content
    self.position = position
    self.velocity = velocity
    self.halfExtents = halfExtents
    self.massKg = massKg
    self.loot = loot
  }
  public var category: SalvageTargetCategory {
    switch content {
    case .commodity: return .cargo
    case .technology(let id, _, _):
      if id == "spare-escape-pod" { return .emptyPod }
      return .technology
    }
  }
}

public enum SalvageWorkResult: Equatable, Codable, Sendable {
  case blocked, capacityRefused, alreadyDepleted
  case progress(seconds: Double, required: Double)
  case released([SalvageLot])
  case destroyed
}

public enum SalvageCollectionRefusal: String, Codable, Sendable {
  case unavailable, protectedPayload, noScoops, unsafeApproach, oversized, fullHold, invalidCargo,
    sparePodLimit
}

public enum SalvageCollectionReceipt: Equatable, Codable, Sendable {
  case collected(SalvageLot)
  case refused(SalvageCollectionRefusal)
}

/// G1 verifies the pinned physical component (nil means the slot must be vacant).
public enum SalvageTransactionBinding: Equatable, Codable, Sendable {
  case equipment(
    target: SalvageUpgradeTarget, expectedComponentInstanceID: UUID?,
    templateVersion: UInt32, axis: SalvageUpgradeAxis?, feature: SalvageFeature?,
    location: ComponentFittingLocation? = nil)
  case research(
    recipeID: String, expectedComponentInstanceID: UUID?, templateVersion: UInt32,
    location: ComponentFittingLocation? = nil)
  case alien(
    recipe: SalvageAlienRecipeID, target: SalvageAlienFittingTarget,
    expectedComponentInstanceID: UUID?, templateVersion: UInt32,
    location: ComponentFittingLocation? = nil)

  public var location: ComponentFittingLocation? {
    switch self {
    case .equipment(_, _, _, _, _, let location), .research(_, _, _, let location),
      .alien(_, _, _, _, let location):
      location
    }
  }
}

public struct SalvageSettlementProposal: Equatable, Codable, Sendable {
  public let command: UUID
  public let revision: UInt64
  public let items: [SalvageLot]
  public let action: SalvageDefinitionAction
  public let saleValueTenths: Int
  public let binding: SalvageTransactionBinding?
  public init(
    command: UUID, revision: UInt64, items: [SalvageLot],
    action: SalvageDefinitionAction, saleValueTenths: Int, binding: SalvageTransactionBinding? = nil
  ) {
    self.command = command
    self.revision = revision
    self.items = items
    self.action = action
    self.saleValueTenths = saleValueTenths
    self.binding = binding
  }
}

public enum SalvageSettlementReceipt: Equatable, Codable, Sendable {
  case committed(SalvageSettlementProposal)
  case refused
}

private struct SalvagePlanProgress: Equatable, Codable, Sendable {
  let plan: SalvageLootPlan
  var issued: [Int]
  var discarded: [Bool]
  var nextLot: UInt32 = 0
  var destroyed = false
  let structuralUnits: Int
  var issuedStructural = 0
  var materialKind: CommodityIdentity?
}

/// G1 publishes this state with cargo, equipment and cash in one actor transaction.
public struct SalvageLedger: Equatable, Codable, Sendable {
  public static let maximumPlans = 256
  public static let maximumPending = 256
  public static let maximumInventory = 128
  public static let maximumPartial = 256
  public static let maximumWrecks = 4096
  public static let maximumSettlements = 1024
  public static let maximumSettledItems = 2048
  private let seed: UInt64
  private var plans: [WreckSectionIdentity: SalvagePlanProgress] = [:]
  private var motions: [WreckIdentity: SalvageWreckMotion] = [:]
  private var depleted: [WreckIdentity: UInt64] = [:]
  private var destroyedWrecks: Set<WreckIdentity> = []
  private var work: [WreckSectionIdentity: Double] = [:]
  private var damagedTechnology: Set<WreckSectionIdentity> = []
  private var pending: [SalvageLotIdentity: SalvageLot] = [:]
  private var stored: [SalvageLotIdentity: SalvageLot] = [:]
  private var offers: [SpawnIdentity: SalvageLotIdentity] = [:]
  private var bindings: [SalvageLotIdentity: ActorIdentity] = [:]
  private var settlements: [UUID: SalvageSettlementReceipt] = [:]
  private var lastOperation: UInt64?
  private var settledItemCount = 0
  private var sequence: UInt64 = 0
  public private(set) var revision: UInt64 = 0

  public init(seed: UInt64 = 0) { self.seed = seed }
  private enum CodingKeys: String, CodingKey {
    case seed, plans, motions, depleted, work, damagedTechnology, pending, stored, offers, bindings
    case settlements, lastOperation, settledItemCount, sequence, revision, destroyedWrecks
  }

  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    seed = try values.decode(UInt64.self, forKey: .seed)
    plans =
      try values.decodeIfPresent([WreckSectionIdentity: SalvagePlanProgress].self, forKey: .plans)
      ?? [:]
    motions =
      try values.decodeIfPresent([WreckIdentity: SalvageWreckMotion].self, forKey: .motions) ?? [:]
    depleted = try values.decode([WreckIdentity: UInt64].self, forKey: .depleted)
    if values.contains(.destroyedWrecks), try !values.decodeNil(forKey: .destroyedWrecks) {
      var records = try values.nestedUnkeyedContainer(forKey: .destroyedWrecks)
      var count = 0
      while !records.isAtEnd {
        guard count < Self.maximumWrecks else {
          throw DecodingError.dataCorrupted(
            .init(codingPath: records.codingPath, debugDescription: "Too many destroyed wrecks"))
        }
        let identity = try records.decode(WreckIdentity.self)
        guard destroyedWrecks.insert(identity).inserted else {
          throw DecodingError.dataCorrupted(
            .init(codingPath: records.codingPath, debugDescription: "Duplicate destroyed wreck"))
        }
        count += 1
      }
    }
    work = try values.decode([WreckSectionIdentity: Double].self, forKey: .work)
    damagedTechnology =
      try values.decodeIfPresent(
        Set<WreckSectionIdentity>.self,
        forKey: .damagedTechnology) ?? []
    pending = try values.decode([SalvageLotIdentity: SalvageLot].self, forKey: .pending)
    stored = try values.decode([SalvageLotIdentity: SalvageLot].self, forKey: .stored)
    offers = try values.decode([SpawnIdentity: SalvageLotIdentity].self, forKey: .offers)
    bindings = try values.decode([SalvageLotIdentity: ActorIdentity].self, forKey: .bindings)
    settlements = try values.decode([UUID: SalvageSettlementReceipt].self, forKey: .settlements)
    lastOperation = try values.decodeIfPresent(UInt64.self, forKey: .lastOperation)
    settledItemCount = try values.decode(Int.self, forKey: .settledItemCount)
    sequence = try values.decode(UInt64.self, forKey: .sequence)
    revision = try values.decode(UInt64.self, forKey: .revision)
    guard validState else {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: decoder.codingPath,
          debugDescription: "Invalid or oversized salvage ledger"))
    }
  }

  private var validState: Bool {
    guard plans.count <= Self.maximumPlans,
      plans.allSatisfy({ validProgress($0.value, section: $0.key) }),
      trackedWrecks.count <= Self.maximumWrecks,
      destroyedWrecks.count <= Self.maximumWrecks,
      destroyedWrecks.allSatisfy({ Self.validWreck($0) }),
      motions.allSatisfy({
        Self.validWreck($0.key) && !isWreckDestroyed($0.key) && Self.validMotion($0.value)
      }),
      depleted.count <= Self.maximumWrecks, work.count <= Self.maximumPartial,
      pending.count <= Self.maximumPending, stored.count <= Self.maximumInventory,
      storedPodCount <= SalvageDefinitions.maximumSparePods,
      offers.count <= pending.count, bindings.count <= pending.count,
      settlements.count <= Self.maximumSettlements,
      (0...Self.maximumSettledItems).contains(settledItemCount),
      damagedTechnology.isSubset(of: Set(work.keys)),
      depleted.keys.allSatisfy({ Self.validWreck($0) }),
      work.allSatisfy({
        Self.validWreck($0.key.wreck) && !isWreckDestroyed($0.key.wreck) && $0.key.section < 64
          && !isDepleted($0.key) && $0.value.isFinite && $0.value > 0
      }),
      pending.allSatisfy({
        $0.key == $0.value.identity && validLot($0.value)
          && issuedSection($0.key.section) && stored[$0.key] == nil
      }),
      stored.allSatisfy({
        $0.key == $0.value.identity && isTechnology($0.value) && validLot($0.value)
          && issuedSection($0.key.section)
      }),
      offers.allSatisfy({
        pending[$0.value] != nil && $0.key.producer == .salvage
          && $0.key.system == $0.value.section.wreck.system
      }),
      Set(offers.values).count == offers.count,
      bindings.allSatisfy({
        pending[$0.key] != nil
          && $0.value.system == $0.key.section.wreck.system
      })
    else { return false }
    var settled = Set<SalvageLotIdentity>()
    for (command, receipt) in settlements {
      guard case .committed(let proposal) = receipt,
        proposal.command == command, !proposal.items.isEmpty,
        proposal.items.count <= Self.maximumInventory,
        validBinding(proposal.binding, action: proposal.action, lots: proposal.items),
        proposal.items.allSatisfy({
          isTechnology($0) && validLot($0) && issuedSection($0.identity.section)
            && stored[$0.identity] == nil && pending[$0.identity] == nil
        })
      else { return false }
      var saleValue = 0
      for lot in proposal.items {
        guard settled.insert(lot.identity).inserted else { return false }
        if proposal.action == .sell,
          case .technology(let id, _, let condition) = lot.content,
          let definition = SalvageDefinitions.definition(id: id)
        {
          saleValue +=
            lot.loot?.saleValueTenths
            ?? SalvageDefinitions.saleValue(
              definition: definition, conditionPercent: condition)
        }
      }
      guard proposal.saleValueTenths == saleValue else { return false }
    }
    return settled.count == settledItemCount
  }

  private var storedPodCount: Int {
    stored.values.filter {
      if case .technology(let id, _, _) = $0.content { return id == "spare-escape-pod" }
      return false
    }.count
  }

  private func isTechnology(_ lot: SalvageLot) -> Bool {
    if case .technology = lot.content { return true }
    return false
  }

  private static func validWreck(_ wreck: WreckIdentity) -> Bool {
    (0..<8).contains(wreck.system.galaxy) && (0...256).contains(wreck.system.system)
  }

  private func validLot(_ lot: SalvageLot) -> Bool {
    guard Self.validWreck(lot.identity.section.wreck), lot.identity.section.section < 64,
      lot.massKg.isFinite, lot.massKg > 0, lot.massKg <= 1_000_000,
      lot.position.length.isFinite, lot.velocity.length.isFinite,
      lot.halfExtents.length.isFinite, lot.halfExtents.x > 0,
      lot.halfExtents.y > 0, lot.halfExtents.z > 0
    else { return false }
    if let loot = lot.loot {
      guard let record = plans[lot.identity.section],
        let expected = issuedItem(record, lot: lot.identity),
        loot == expected, lot.massKg == expected.massKg, lot.halfExtents == expected.halfExtents
      else { return false }
      switch (lot.content, expected.content) {
      case (.commodity(let amount), .commodity(let native)): return amount == native
      case (
        .technology(let id, let quality, let condition),
        .technology(let expectedID, let expectedQuality, let expectedCondition, _)
      ):
        return id == expectedID && quality == expectedQuality && condition == expectedCondition
      default: return false
      }
    }
    guard plans[lot.identity.section] == nil else { return false }
    switch lot.content {
    case .commodity(let amount):
      return amount.valid && amount.quantity == 1 && amount.tonnes == 1
        && [.alloys, .minerals].contains(amount.commodity)
        && lot.massKg == 1000 && lot.halfExtents == Vector3(8, 8, 8)
    case .technology(let id, _, let condition):
      guard let definition = SalvageDefinitions.definition(id: id), (0...100).contains(condition)
      else { return false }
      return lot.massKg == definition.massKg && lot.halfExtents == definition.halfExtents
    }
  }

  private var trackedWrecks: Set<WreckIdentity> {
    Set(motions.keys).union(depleted.keys).union(work.keys.map(\.wreck)).union(
      plans.keys.map(\.wreck)
    ).union(destroyedWrecks)
  }

  private func canTrack(_ wreck: WreckIdentity) -> Bool {
    let tracked = trackedWrecks
    return tracked.contains(wreck) || tracked.count < Self.maximumWrecks
  }

  private static func validMotion(_ motion: SalvageWreckMotion) -> Bool {
    let basis = motion.pose.orientation
    let epsilon = 0.00001
    return motion.pose.position.length.isFinite && motion.velocity.length.isFinite
      && motion.angularVelocity.length.isFinite
      && (motion.energy.map { $0.isFinite && $0 > 0 && $0 <= 100000 } ?? true)
      && abs(basis.x.length - 1) < epsilon && abs(basis.y.length - 1) < epsilon
      && abs(basis.z.length - 1) < epsilon && abs(basis.x.dot(basis.y)) < epsilon
      && abs(basis.x.dot(basis.z)) < epsilon && abs(basis.y.dot(basis.z)) < epsilon
      && basis.x.cross(basis.y).dot(basis.z) > 1 - epsilon
  }

  /// Whole-wreck death is separate from exhausted sections and survives visit/cull resets.
  public func isWreckDestroyed(_ identity: WreckIdentity) -> Bool {
    destroyedWrecks.contains(identity)
  }

  /// The runtime publishes this tombstone with actual death, never ordinary scene culling.
  /// Issued fragments and their custody remain valid after their parent disappears.
  @discardableResult public mutating func markWreckDestroyed(_ identity: WreckIdentity) -> Bool {
    guard Self.validWreck(identity) else { return false }
    if isWreckDestroyed(identity) { return true }
    guard canTrack(identity), revision < UInt64.max else { return false }
    destroyedWrecks.insert(identity)
    motions.removeValue(forKey: identity)
    work = work.filter { $0.key.wreck != identity }
    damagedTechnology = damagedTechnology.filter { $0.wreck != identity }
    revision += 1
    return true
  }

  public func wreckMotion(for identity: WreckIdentity) -> SalvageWreckMotion? { motions[identity] }

  /// Store live canonical motion on cull/save; this ledger never advances offscreen time.
  @discardableResult public mutating func updateWreck(
    identity: WreckIdentity,
    motion: SalvageWreckMotion
  ) -> Bool {
    guard Self.validWreck(identity), !isWreckDestroyed(identity),
      Self.validMotion(motion), canTrack(identity)
    else {
      return false
    }
    motions[identity] = motion
    return true
  }

  public var pendingLots: [SalvageLot] { sorted(pending.values) }
  /// The acknowledged live body is the only scene actor allowed to transfer this lot.
  public func boundActor(for lot: SalvageLotIdentity) -> ActorIdentity? { bindings[lot] }
  /// Admission may inspect only a still-pending lot offered under this exact spawn identity.
  public func offeredLot(for request: SpawnIdentity) -> SalvageLot? {
    offers[request].flatMap { pending[$0] }
  }
  public var inventory: [SalvageLot] { sorted(stored.values) }
  public var inventoryMassKg: Double { stored.values.reduce(0) { $0 + $1.massKg } }
  public var reservedTonnes: Int { Int(ceil(inventoryMassKg / 1000)) }
  public func isDepleted(_ section: WreckSectionIdentity) -> Bool {
    section.section < 64 && depleted[section.wreck, default: 0] & (1 << section.section) != 0
  }
  public func progress(_ section: WreckSectionIdentity) -> Double { work[section, default: 0] }

  /// Conditions are resolved against the actual moving surface by the G1 physics adapter.
  public mutating func advance(
    wreck: WreckIdentity, section: SalvageSectionProfile, pose: ShipPose,
    velocity: Vector3, angularVelocity: Vector3, tool: SalvageTool,
    elapsed: Double, operation: UInt64, conditions: SalvageWorkConditions,
    source: SalvageLootSource? = nil
  ) -> SalvageWorkResult {
    let identity = WreckSectionIdentity(wreck: wreck, section: section.index)
    guard Self.validWreck(wreck), !isWreckDestroyed(wreck),
      section.index < 64, elapsed.isFinite, elapsed > 0, elapsed <= 1,
      section.workSeconds.isFinite, section.workSeconds > 0,
      section.localPosition.length.isFinite, section.normal.length.isFinite,
      section.normal.length > 0, section.radius.isFinite, section.radius >= 0,
      section.technologyDefinitionIDs.count <= 12,
      section.technologyDefinitionIDs.allSatisfy({ SalvageDefinitions.definition(id: $0) != nil }),
      pose.position.length.isFinite, pose.orientation.x.length.isFinite,
      pose.orientation.apply(section.normal).length > 0,
      pose.orientation.y.length.isFinite, pose.orientation.z.length.isFinite,
      velocity.length.isFinite, angularVelocity.length.isFinite,
      Self.validMotion(.init(pose: pose, velocity: velocity, angularVelocity: angularVelocity)),
      conditions.permitsWork,
      lastOperation.map({ operation > $0 }) ?? true
    else { return .blocked }
    guard !isDepleted(identity) else { return .alreadyDepleted }
    guard canTrack(wreck),
      work[identity] != nil || work.count < Self.maximumPartial
    else { return .capacityRefused }
    if source != nil || plans[identity] != nil {
      return advancePlanned(
        wreck: wreck, section: section, pose: pose, velocity: velocity,
        angularVelocity: angularVelocity, tool: tool, elapsed: elapsed, operation: operation,
        source: source)
    }
    let next = min(section.workSeconds, progress(identity) + elapsed)
    if next < section.workSeconds {
      if tool == .miningLaser { damagedTechnology.insert(identity) }
      work[identity] = next
      lastOperation = operation
      return .progress(seconds: next, required: section.workSeconds)
    }
    let lots = makeLots(
      wreck: wreck, section: section, pose: pose, velocity: velocity,
      angularVelocity: angularVelocity,
      preserveTechnology: tool == .cutter && !damagedTechnology.contains(identity))
    guard lots.allSatisfy({ $0.position.length.isFinite && $0.velocity.length.isFinite }) else {
      return .blocked
    }
    guard pending.count + lots.count <= Self.maximumPending else { return .capacityRefused }
    lastOperation = operation
    depleted[wreck, default: 0] |= 1 << section.index
    work.removeValue(forKey: identity)
    damagedTechnology.remove(identity)
    for lot in lots { pending[lot.identity] = lot }
    revision &+= 1
    return lots.isEmpty ? .destroyed : .released(lots)
  }

  public mutating func destroy(section: WreckSectionIdentity, operation: UInt64)
    -> SalvageWorkResult
  {
    guard Self.validWreck(section.wreck), !isWreckDestroyed(section.wreck), section.section < 64,
      lastOperation.map({ operation > $0 }) ?? true
    else {
      return .blocked
    }
    guard !isDepleted(section) else { return .alreadyDepleted }
    guard canTrack(section.wreck) else {
      return .capacityRefused
    }
    plans[section]?.destroyed = true
    lastOperation = operation
    depleted[section.wreck, default: 0] |= 1 << section.section
    work.removeValue(forKey: section)
    damagedTechnology.remove(section)
    revision &+= 1
    return .destroyed
  }

  public mutating func spawnRequests(context: EncounterContext) -> [SpawnRequest] {
    let available = max(
      0,
      min(
        context.budget.ordinaryRemaining,
        PopulationClass.cargo.maximum - context.budget.active[.cargo, default: 0]) - offers.count)
    let reserved = Set(offers.values)
    var requests: [SpawnRequest] = []
    for lot in pendingLots where requests.count < available {
      let payload = PayloadIdentity.salvage(lot.identity)
      guard lot.identity.section.wreck.system == context.system,
        bindings[lot.identity] == nil, !reserved.contains(lot.identity),
        !context.protection.protectedPayloads.contains(payload)
      else { continue }
      sequence &+= 1
      let id = SpawnIdentity(
        system: context.system, visit: context.visit,
        sequence: sequence, member: 0, producer: .salvage)
      offers[id] = lot.identity
      requests.append(
        .init(
          identity: id, population: .cargo, hull: .cargo,
          position: lot.position, orientation: .init(), velocity: lot.velocity, npc: nil,
          rock: nil, payload: payload, priority: .ordinary,
          salvage: .init(
            category: lot.category, ownership: lot.loot?.legality.ownership ?? .abandoned,
            claimant: nil,
            wreck: lot.identity.section.wreck, section: lot.identity.section, lot: lot.identity,
            bounds: .init(center: .init(0, 0, 0), radius: lot.halfExtents.length), workSurfaces: [])
        ))
    }
    return requests
  }

  public mutating func acknowledge(receipts: [SpawnReceipt]) {
    for receipt in receipts {
      guard let lot = offers.removeValue(forKey: receipt.request), pending[lot] != nil,
        receipt.refusal == nil, let actor = receipt.actor,
        actor.system == receipt.request.system, actor.visit == receipt.request.visit
      else { continue }
      bindings[lot] = actor
    }
  }
  public mutating func cull(actor: ActorIdentity) {
    bindings = bindings.filter { $0.value != actor }
  }
  public mutating func resetPhysicalBindings(system: SystemIdentity) {
    offers = offers.filter { $0.key.system != system }
    bindings = bindings.filter { $0.value.system != system }
  }
  public mutating func updateLot(
    _ identity: SalvageLotIdentity, position: Vector3, velocity: Vector3
  ) {
    guard position.x.isFinite, position.y.isFinite, position.z.isFinite,
      velocity.x.isFinite, velocity.y.isFinite, velocity.z.isFinite
    else { return }
    pending[identity]?.position = position
    pending[identity]?.velocity = velocity
  }

  public mutating func collect(
    lot identity: SalvageLotIdentity, cargo: inout [Int], freeTonnes: Int,
    apertureHalfExtents: Vector3, hasScoops: Bool, approachAllowed: Bool,
    protection: MissionProtection
  ) -> SalvageCollectionReceipt {
    guard let lot = pending[identity] else { return .refused(.unavailable) }
    guard lot.massKg.isFinite, lot.massKg > 0, lot.halfExtents.length.isFinite,
      lot.halfExtents.x >= 0, lot.halfExtents.y >= 0, lot.halfExtents.z >= 0,
      apertureHalfExtents.length.isFinite, apertureHalfExtents.x > 0,
      apertureHalfExtents.y > 0, apertureHalfExtents.z > 0
    else { return .refused(.oversized) }
    guard !protection.protectedPayloads.contains(.salvage(identity)) else {
      return .refused(.protectedPayload)
    }
    guard hasScoops else { return .refused(.noScoops) }
    guard approachAllowed else { return .refused(.unsafeApproach) }
    guard lot.halfExtents.x <= apertureHalfExtents.x,
      lot.halfExtents.y <= apertureHalfExtents.y, lot.halfExtents.z <= apertureHalfExtents.z
    else {
      return .refused(.oversized)
    }
    guard cargo.count == CommodityIdentity.allCases.count,
      cargo.allSatisfy({ $0 >= 0 && $0 <= Int.max / 17 })
    else { return .refused(.invalidCargo) }
    switch lot.content {
    case .commodity(let amount):
      let ordinary = TypedCargoPayload(
        identity: .wreck(
          .init(
            system: identity.section.wreck.system,
            visit: 0, entity: identity.section.wreck.lineage), lot: identity.lot), amount: amount,
        position: lot.position, velocity: lot.velocity)
      switch ordinary.collect(
        into: &cargo, freeTonnes: freeTonnes, hasScoops: hasScoops,
        approachAllowed: approachAllowed, protection: .init())
      {
      case .collected: break
      case .refused(.fullHold): return .refused(.fullHold)
      case .refused: return .refused(.invalidCargo)
      }
    case .technology(let definitionID, _, _):
      if definitionID == "spare-escape-pod" {
        guard SalvageDefinitions.canStoreSparePod(currentCount: storedPodCount) else {
          return .refused(.sparePodLimit)
        }
      }
      guard stored.count < Self.maximumInventory,
        Int(ceil((inventoryMassKg + lot.massKg) / 1000)) - reservedTonnes <= freeTonnes
      else {
        return .refused(.fullHold)
      }
      stored[identity] = lot
    }
    pending.removeValue(forKey: identity)
    bindings.removeValue(forKey: identity)
    offers = offers.filter { $0.value != identity }
    revision &+= 1
    return .collected(lot)
  }

  public func settlementReceipt(for command: UUID) -> SalvageSettlementReceipt? {
    settlements[command]
  }

  /// Prepare without consuming. G1 validates and publishes the entire commander copy.
  public func prepareSettlement(
    command: UUID, items: [SalvageLotIdentity],
    action: SalvageDefinitionAction, binding: SalvageTransactionBinding? = nil
  ) -> SalvageSettlementProposal? {
    if case .committed(let proposal) = settlements[command] {
      return proposal.items.map(\.identity) == items && proposal.action == action
        && proposal.binding == binding ? proposal : nil
    }
    guard !items.isEmpty, Set(items).count == items.count,
      settlements.count < Self.maximumSettlements,
      items.count <= Self.maximumSettledItems - settledItemCount
    else { return nil }
    let lots = items.compactMap { stored[$0] }
    guard lots.count == items.count, validBinding(binding, action: action, lots: lots) else {
      return nil
    }
    var value = 0
    for lot in lots {
      guard case .technology(let id, _, let condition) = lot.content,
        let definition = SalvageDefinitions.definition(id: id)
      else { return nil }
      let alienConversion: Bool
      if case .alien = binding { alienConversion = true } else { alienConversion = false }
      if !alienConversion, case .fit(let axis, _) = action, let loot = lot.loot,
        case .technology(_, _, _, let fixedAxis) = loot.content, axis != fixedAxis
      {
        return nil
      }
      if action == .sell {
        let price =
          lot.loot?.saleValueTenths
          ?? SalvageDefinitions.saleValue(
            definition: definition, conditionPercent: condition)
        guard price <= Int.max / 17 - value else { return nil }
        value += price
      }
    }
    return .init(
      command: command, revision: revision, items: lots, action: action,
      saleValueTenths: value, binding: binding)
  }
  public mutating func commitSettlement(_ proposal: SalvageSettlementProposal)
    -> SalvageSettlementReceipt
  {
    if case .committed(let committed) = settlements[proposal.command] {
      return committed == proposal ? .committed(committed) : .refused
    }
    guard proposal.revision == revision, settlements.count < Self.maximumSettlements,
      prepareSettlement(
        command: proposal.command, items: proposal.items.map(\.identity),
        action: proposal.action, binding: proposal.binding) == proposal
    else { return .refused }
    for lot in proposal.items { stored.removeValue(forKey: lot.identity) }
    let receipt = SalvageSettlementReceipt.committed(proposal)
    settlements[proposal.command] = receipt
    settledItemCount += proposal.items.count
    revision &+= 1
    return receipt
  }

  private func validBinding(
    _ binding: SalvageTransactionBinding?,
    action: SalvageDefinitionAction, lots: [SalvageLot]
  ) -> Bool {
    guard let binding else { return true }
    guard binding.location?.slot.valid ?? true else { return false }
    switch binding {
    case .equipment(let target, _, let version, let axis, let feature, let location):
      guard version > 0, lots.count == 1, case .fit(let selectedAxis, let mount) = action,
        axis == selectedAxis, case .technology(let id, _, _) = lots[0].content,
        let definition = SalvageDefinitions.definition(id: id)
      else { return false }
      if case .commanderResearch = target, definition.category != .computerCore { return false }
      if case .laser(_, let targetMount, _) = target, targetMount != mount { return false }
      if let location,
        !validEquipmentLocation(
          location, target: target, definition: definition,
          axis: axis, mount: mount)
      {
        return false
      }
      if case .feature(let expected) = definition.effect {
        return feature == expected && axis == nil && mount == nil
      }
      guard feature == nil else { return false }
      if case .scalar(let axes) = definition.effect {
        return axis.map { axes.contains($0) } == true
      }
      return axis == nil
    case .research(let recipeID, _, let version, let location):
      guard version > 0, action == .research,
        let recipe = SalvageDefinitions.researchRecipes.first(where: { $0.id == recipeID }),
        lots.count == recipe.requiredCount
      else { return false }
      if let location {
        switch recipe.destination {
        case .navigation: guard location.slot == .navigation else { return false }
        case .targeting: guard location.slot == .targetingCore else { return false }
        case .alienPrecision:
          guard [.navigation, .targetingCore].contains(location.slot) else { return false }
        }
      }
      return lots.allSatisfy {
        if case .technology(let id, _, _) = $0.content { return id == recipe.requiredDefinitionID }
        return false
      }
    case .alien(let recipeID, let target, _, let version, let location):
      let recipe = SalvageAlienDefinitions.recipe(recipeID)
      guard version > 0, lots.count == recipe.requiredArtefactCount,
        lots.allSatisfy({
          if case .technology(let id, _, _) = $0.content {
            return id == recipe.requiredDefinitionID
          }
          return false
        })
      else { return false }
      if let location {
        guard location.hullInstanceID == target.hull else { return false }
        switch target {
        case .shield: guard location.slot == .shield else { return false }
        case .combatMount(_, let mount): guard location.slot == .laser(mount) else { return false }
        case .missilePylon(_, let index):
          guard location.slot == .missilePylon(index) else { return false }
        }
      }
      switch (recipeID, target) {
      case (.shieldRegenerator, .shield(_, let axis)):
        return [.frontShieldRecharge, .rearShieldRecharge].contains(axis)
          && action == .fit(axis: axis, mount: nil)
      case (.plasmaEmitter, .combatMount(_, let mount)):
        return action == .fit(axis: nil, mount: mount)
      case (.seekerMissile, .missilePylon(_, let index)):
        return (0..<SalvageDefinitions.maximumNativePylons).contains(index)
          && action == .fit(axis: nil, mount: nil)
      default: return false
      }
    }
  }

  private func validEquipmentLocation(
    _ location: ComponentFittingLocation,
    target: SalvageUpgradeTarget, definition: SalvageTechnologyDefinition,
    axis: SalvageUpgradeAxis?, mount: LaserMount?
  ) -> Bool {
    switch target {
    case .hull(let hull): guard location.hullInstanceID == hull else { return false }
    case .laser(let hull, let facing, _):
      guard location.hullInstanceID == hull, location.slot == .laser(facing) else { return false }
    case .commanderResearch: guard definition.category == .computerCore else { return false }
    }
    switch definition.category {
    case .computerCore:
      return [.navigation, .targetingCore, .targetingMining, .targetingSalvage].contains(
        location.slot)
        && axis.map { [.scanningRange, .acquisitionError, .automationError].contains($0) } == true
    case .driveTechnology:
      if let axis, [.spoolDuration, .jumpFuelCost, .jumpReach].contains(axis) {
        return location.slot == .navigation
      }
      return location.slot == .drive
    case .laserTechnology:
      guard let mount else { return false }
      return location.slot == .laser(mount)
    case .shieldTechnology: return location.slot == .shield
    case .energyTechnology: return location.slot == .energy
    case .recoveredMissile:
      if case .missilePylon = location.slot { return true }
      return false
    case .laserHardpoint:
      guard let mount else { return false }
      return location.slot == .hullStructure || location.slot == .laser(mount)
    case .missilePylon:
      if case .missilePylon = location.slot { return true }
      return location.slot == .hullStructure
    case .spareEscapePod:
      if case .spareEscapePod = location.slot { return true }
      return location.slot == .utility(.escapePod)
    case .alienArtefact: return false
    case .featureModule:
      guard case .feature(let feature) = definition.effect else { return false }
      switch feature {
      case .miningTargetingModule: return location.slot == .targetingMining
      case .salvageTargetingModule: return location.slot == .targetingSalvage
      case .fuelScoops: return location.slot == .utility(.fuelScoops)
      case .ecm: return location.slot == .utility(.ecm)
      case .salvageCutter: return location.slot == .utility(.salvageCutter)
      }
    }
  }

  /// Persist the original roll even when it is empty; changing source data cannot reroll it.
  public mutating func inspectLoot(
    wreck: WreckIdentity, section: SalvageSectionProfile,
    source: SalvageLootSource
  ) -> SalvageLootPlan? {
    let identity = WreckSectionIdentity(wreck: wreck, section: section.index)
    if let existing = plans[identity] { return existing.plan }
    guard Self.validWreck(wreck), !isWreckDestroyed(wreck), section.index < 64,
      !isDepleted(identity),
      plans.count < Self.maximumPlans, canTrack(wreck), validSource(source)
    else { return nil }
    let plan = SalvageLootProfiles.plan(section: identity, seed: seed, source: source)
    guard validPlan(plan), estimatedLots(plan) <= 65535 else { return nil }
    let units = section.structural && plan.profile != .asteroid ? structuralUnits(identity) : 0
    plans[identity] = .init(
      plan: plan, issued: Array(repeating: 0, count: plan.items.count),
      discarded: Array(repeating: false, count: plan.items.count), structuralUnits: units)
    revision &+= 1
    return plan
  }

  public func remainingStructuralMaterial(for section: WreckSectionIdentity) -> Int {
    guard !isWreckDestroyed(section.wreck), let record = plans[section], !record.destroyed else {
      return 0
    }
    return record.structuralUnits - record.issuedStructural
  }

  /// Destruction is terminal for this issued lot. Culling only releases its actor binding.
  @discardableResult public mutating func destroy(
    lot: SalvageLotIdentity,
    protection: MissionProtection
  ) -> Bool {
    guard let item = pending[lot], item.category != .occupiedPod,
      !protection.protectedPayloads.contains(.salvage(lot))
    else { return false }
    pending.removeValue(forKey: lot)
    bindings.removeValue(forKey: lot)
    offers = offers.filter { $0.value != lot }
    revision &+= 1
    return true
  }

  /// Disabled-source plans retain their original known manifest and legal provenance after every cut.
  func empSourceIsConsistent(_ record: EMPHullRecord) -> Bool {
    let matching = plans.filter { $0.key.wreck == record.wreck }
    guard
      matching.isEmpty
        || (record.pods.count + record.capturedCrewCount == record.crewTotal
          && record.lostCrewCount == 0),
      let catalogue = record.hull.body.physical?.catalogueShipID,
      let profile = SalvageCatalogue.empProfile(catalogueShipID: catalogue)
    else { return false }
    return matching.allSatisfy { section, progress in
      let source = progress.plan.source
      return profile.sections.contains { $0.index == section.section }
        && source.roles == profile.sourceRoles && source.manifest == record.salvageCargo
        && source.legalValue == record.salvageLegal.value && source.ownership == .abandoned
        && source.stolenProvenance == (record.salvageLegal.value == 0)
        && source.manifestSection == 1 && !source.manifestAlreadySettled
    }
  }

  private func issuedSection(_ section: WreckSectionIdentity) -> Bool {
    isDepleted(section) || plans[section] != nil
  }

  private func validSource(_ source: SalvageLootSource) -> Bool {
    (0...255).contains(source.legalValue) && (0...7).contains(source.economy)
      && (0...14).contains(source.technology) && source.manifestSection < 64
      && (source.manifest?.count ?? 0) <= 17
  }

  private func validPlan(_ plan: SalvageLootPlan) -> Bool {
    guard Self.validWreck(plan.section.wreck), plan.section.section < 64,
      validSource(plan.source),
      plan.profile == SalvageLootProfiles.profile(roles: plan.source.roles),
      plan.items.count <= 18, estimatedLots(plan) <= 65535,
      plan.items.isEmpty || plan.emptyReason == nil,
      plan.items.enumerated().allSatisfy({ index, item in
        item.identity == SalvageLotIdentity(section: plan.section, lot: UInt16(index))
          && validPlannedItem(item, source: plan.source)
      })
    else { return false }
    if let profile = plan.profile {
      guard
        plan.bucket.map({ bucket in
          SalvageLootProfiles.weights(for: profile).contains { $0.bucket == bucket }
        })
          ?? (plan.emptyReason == .invalidSection)
      else { return false }
    } else if plan.emptyReason != .unsupportedSource {
      return false
    }
    if let manifest = plan.source.manifest, !manifest.allSatisfy(\.valid) {
      return plan.items.isEmpty && plan.emptyReason == .invalidManifest
    }
    return true
  }

  private func validPlannedItem(_ item: SalvageLootItem, source: SalvageLootSource) -> Bool {
    guard item.massKg.isFinite, item.massKg > 0, item.halfExtents.length.isFinite,
      item.halfExtents.x > 0, item.halfExtents.y > 0, item.halfExtents.z > 0,
      (0...Int.max / 17).contains(item.saleValueTenths),
      item.legality.sourceLegalValue == source.legalValue,
      item.legality.ownership == source.ownership,
      item.legality.stolenProvenance == source.stolenProvenance
    else { return false }
    switch item.content {
    case .commodity(let amount):
      guard amount.valid, item.effect == nil, item.bonusBasisPoints == 0,
        item.provenance == .human,
        item.legality.commodityIllegal
          == [.slaves, .narcotics, .firearms].contains(amount.commodity)
      else { return false }
      let mass = nativeMass(amount)
      let half = max(1, pow(max(1, mass) / 100, 1.0 / 3) * 4)
      let price = MarketItem.generate(economy: source.economy, fluctuation: 0)[
        amount.commodity.rawValue
      ].price
      let (value, overflow) = amount.quantity.multipliedReportingOverflow(by: price)
      return !overflow && item.saleValueTenths == value && item.massKg == mass
        && item.halfExtents == Vector3(half, half, half)
    case .technology(let id, let quality, let condition, let axis):
      guard let definition = SalvageDefinitions.definition(id: id), (0...100).contains(condition),
        item.massKg == definition.massKg, item.halfExtents == definition.halfExtents,
        item.provenance == definition.provenance, !item.legality.commodityIllegal,
        item.saleValueTenths
          == SalvageDefinitions.saleValue(definition: definition, conditionPercent: condition),
        !item.requiresChunking
      else { return false }
      if AlienModuleDefinition.isAttachmentDefinition(id) {
        guard source.roles.contains(.thargoid) else { return false }
        return (try? AlienModuleDefinition.validatePlanned(item)) != nil
      }
      if case .scalar(let axes) = definition.effect {
        return axis.map { axes.contains($0) && item.effect == .scalar(axes: [$0]) } == true
          && item.bonusBasisPoints == quality.bonusBasisPoints
      }
      return axis == nil && item.effect == definition.effect && item.bonusBasisPoints == 0
    }
  }

  private func validProgress(_ record: SalvagePlanProgress, section: WreckSectionIdentity) -> Bool {
    guard record.plan.section == section, validPlan(record.plan),
      record.issued.count == record.plan.items.count, record.discarded.count == record.issued.count,
      record.nextLot <= 65536, (0...5).contains(record.structuralUnits),
      (0...record.structuralUnits).contains(record.issuedStructural),
      record.issuedStructural == 0 || record.issuedStructural == record.structuralUnits,
      record.materialKind == nil || [.alloys, .minerals].contains(record.materialKind!),
      record.issuedStructural == 0 || record.materialKind != nil,
      record.plan.profile != .asteroid || record.structuralUnits == 0
    else { return false }
    var count = record.issuedStructural > 0 ? 1 : 0
    for index in record.issued.indices {
      let item = record.plan.items[index]
      let total = nativeQuantity(item)
      let issued = record.issued[index]
      guard (0...total).contains(issued) else { return false }
      if record.discarded[index] {
        guard case .technology = item.content, issued == 1 else { return false }
      } else {
        let limit = chunkLimit(item)
        guard issued == total || issued % limit == 0 else { return false }
        if issued > 0 { count += (issued - 1) / limit + 1 }
      }
    }
    return count == Int(record.nextLot)
      && (!isDepleted(section) || record.destroyed || fullyIssued(record))
  }

  private func fullyIssued(_ record: SalvagePlanProgress) -> Bool {
    record.issuedStructural == record.structuralUnits
      && zip(record.issued, record.plan.items).allSatisfy { $0 == nativeQuantity($1) }
  }

  private func nativeQuantity(_ item: SalvageLootItem) -> Int {
    if case .commodity(let amount) = item.content { return amount.quantity }
    return 1
  }
  private func chunkLimit(_ item: SalvageLootItem) -> Int {
    guard case .commodity(let amount) = item.content else { return 1 }
    switch amount.commodity.unit {
    case "t": return 5
    case "kg": return 1000
    default: return 1_000_000
    }
  }
  private func estimatedLots(_ plan: SalvageLootPlan) -> Int {
    plan.items.reduce(0) { sum, item in
      let quantity = nativeQuantity(item)
      guard quantity > 0, quantity <= Int.max / 17 else { return 65537 }
      return min(65537, sum + min(65537, (quantity - 1) / chunkLimit(item) + 1))
    }
  }
  private func nativeMass(_ amount: CommodityAmount) -> Double {
    Double(amount.quantity)
      * (amount.commodity.unit == "t" ? 1000 : amount.commodity.unit == "kg" ? 1 : 0.001)
  }
  private func structuralUnits(_ section: WreckSectionIdentity) -> Int {
    SalvageLotEmission.structuralUnits(seed: seed, section: section)
  }

  private func chunk(_ item: SalvageLootItem, identity: SalvageLotIdentity, quantity: Int)
    -> SalvageLootItem
  {
    SalvageLotEmission.chunk(item, identity: identity, quantity: quantity)
  }

  private func structuralItem(_ record: SalvagePlanProgress, lot: SalvageLotIdentity)
    -> SalvageLootItem
  {
    SalvageLotEmission.structural(
      plan: record.plan, quantity: record.structuralUnits,
      material: record.materialKind ?? .minerals, identity: lot)
  }

  private func issuedItem(_ record: SalvagePlanProgress, lot: SalvageLotIdentity)
    -> SalvageLootItem?
  {
    guard lot.section == record.plan.section, UInt32(lot.lot) < record.nextLot else { return nil }
    var cursor = 0
    if record.issuedStructural > 0 {
      if lot.lot == 0 { return structuralItem(record, lot: lot) }
      cursor = 1
    }
    for index in record.issued.indices where !record.discarded[index] && record.issued[index] > 0 {
      let item = record.plan.items[index]
      let limit = chunkLimit(item)
      let count = (record.issued[index] - 1) / limit + 1
      if Int(lot.lot) < cursor + count {
        let ordinal = Int(lot.lot) - cursor
        return chunk(
          item, identity: lot, quantity: min(limit, nativeQuantity(item) - ordinal * limit))
      }
      cursor += count
    }
    return nil
  }

  private mutating func advancePlanned(
    wreck: WreckIdentity, section: SalvageSectionProfile,
    pose: ShipPose, velocity: Vector3, angularVelocity: Vector3, tool: SalvageTool,
    elapsed: Double, operation: UInt64, source: SalvageLootSource?
  ) -> SalvageWorkResult {
    let identity = WreckSectionIdentity(wreck: wreck, section: section.index)
    var staged = self
    if staged.plans[identity] == nil {
      guard let source, staged.inspectLoot(wreck: wreck, section: section, source: source) != nil
      else { return .capacityRefused }
    }
    guard var record = staged.plans[identity], !record.destroyed else { return .alreadyDepleted }
    if record.materialKind == nil { record.materialKind = tool == .cutter ? .alloys : .minerals }
    if tool == .miningLaser || damagedTechnology.contains(identity) {
      for index in record.issued.indices where record.issued[index] == 0 {
        if case .technology = record.plan.items[index].content {
          record.issued[index] = 1
          record.discarded[index] = true
        }
      }
    }
    let next = min(section.workSeconds, progress(identity) + elapsed)
    if next < section.workSeconds {
      staged.plans[identity] = record
      staged.work[identity] = next
      staged.lastOperation = operation
      self = staged
      return .progress(seconds: next, required: section.workSeconds)
    }
    var items: [SalvageLootItem] = []
    func append(_ item: SalvageLootItem) -> Bool {
      guard record.nextLot < 65536 else { return false }
      items.append(item)
      record.nextLot += 1
      return true
    }
    if record.issuedStructural < record.structuralUnits {
      guard
        append(structuralItem(record, lot: .init(section: identity, lot: UInt16(record.nextLot))))
      else { return .capacityRefused }
      record.issuedStructural = record.structuralUnits
    }
    for index in record.issued.indices {
      let item = record.plan.items[index]
      while record.issued[index] < nativeQuantity(item) && items.count < 8 {
        guard record.nextLot < 65536 else { return .capacityRefused }
        let quantity = min(chunkLimit(item), nativeQuantity(item) - record.issued[index])
        let issued = chunk(
          item, identity: .init(section: identity, lot: UInt16(record.nextLot)), quantity: quantity)
        guard append(issued) else { return .capacityRefused }
        record.issued[index] += quantity
      }
    }
    guard pending.count + items.count <= Self.maximumPending else { return .capacityRefused }
    let normal = pose.orientation.apply(section.normal) * (1 / section.normal.length)
    let cardinal = abs(normal.x) < 0.8 ? Vector3(1, 0, 0) : Vector3(0, 1, 0)
    let cross = normal.cross(cardinal)
    let tangent = cross * (1 / cross.length)
    let offset = pose.orientation.apply(section.localPosition)
    let lots = items.enumerated().map { index, item -> SalvageLot in
      let content: SalvageLotContent
      switch item.content {
      case .commodity(let amount): content = .commodity(amount)
      case .technology(let id, let quality, let condition, _):
        content = .technology(definitionID: id, quality: quality, conditionPercent: condition)
      }
      return .init(
        identity: item.identity, content: content,
        position: pose.position + offset + normal * (item.halfExtents.length + 10)
          + tangent * Double(index % 5) * 8,
        velocity: velocity + angularVelocity.cross(offset) + normal * 3,
        halfExtents: item.halfExtents, massKg: item.massKg, loot: item)
    }
    guard lots.allSatisfy({ $0.position.length.isFinite && $0.velocity.length.isFinite }) else {
      return .blocked
    }
    staged.plans[identity] = record
    staged.work.removeValue(forKey: identity)
    staged.damagedTechnology.remove(identity)
    staged.lastOperation = operation
    for lot in lots { staged.pending[lot.identity] = lot }
    if fullyIssued(record) { staged.depleted[wreck, default: 0] |= 1 << section.index }
    staged.revision &+= 1
    self = staged
    return lots.isEmpty ? .destroyed : .released(lots)
  }

  private func sorted(_ lots: Dictionary<SalvageLotIdentity, SalvageLot>.Values) -> [SalvageLot] {
    lots.sorted {
      let a = $0.identity
      let b = $1.identity
      let aw = a.section.wreck
      let bw = b.section.wreck
      if aw.system.galaxy != bw.system.galaxy { return aw.system.galaxy < bw.system.galaxy }
      if aw.system.system != bw.system.system { return aw.system.system < bw.system.system }
      if aw.site != bw.site { return aw.site < bw.site }
      if aw.lineage != bw.lineage { return aw.lineage < bw.lineage }
      return a.section.section == b.section.section
        ? a.lot < b.lot : a.section.section < b.section.section
    }
  }

  private func makeLots(
    wreck: WreckIdentity, section: SalvageSectionProfile, pose: ShipPose,
    velocity: Vector3, angularVelocity: Vector3, preserveTechnology: Bool
  ) -> [SalvageLot] {
    var state =
      seed ^ wreck.lineage ^ UInt64(wreck.site) << 32 ^ UInt64(section.index)
      ^ UInt64(truncatingIfNeeded: wreck.system.system) &* 0xBF58_476D_1CE4_E5B9
      ^ UInt64(truncatingIfNeeded: wreck.system.galaxy) &* 0x9E37_79B9_7F4A_7C15
    func draw() -> UInt64 {
      state &+= 0x9E37_79B9_7F4A_7C15
      var value = state
      value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
      value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
      return value ^ (value >> 31)
    }
    var contents: [(SalvageLotContent, Vector3, Double)] = []
    if section.structural {
      for _ in 0..<(1 + Int(draw() % 5)) {
        contents.append(
          (
            .commodity(
              .init(
                commodity: preserveTechnology ? .alloys : .minerals,
                quantity: 1)), .init(8, 8, 8), 1000
          ))
      }
    }
    if preserveTechnology {
      for id in section.technologyDefinitionIDs {
        guard let definition = SalvageDefinitions.definition(id: id) else { continue }
        contents.append(
          (
            .technology(
              definitionID: id,
              quality: SalvageQuality(rawValue: 1 + Int(draw() % 3))!,
              conditionPercent: 50 + Int(draw() % 51)), definition.halfExtents, definition.massKg
          ))
      }
    }
    let offset = pose.orientation.apply(section.localPosition)
    let transformedNormal = pose.orientation.apply(section.normal * (1 / section.normal.length))
    let normal = transformedNormal * (1 / transformedNormal.length)
    let cardinal = abs(normal.x) < 0.8 ? Vector3(1, 0, 0) : Vector3(0, 1, 0)
    let cross = normal.cross(cardinal)
    let tangent = cross * (1 / cross.length)
    return contents.enumerated().map { index, content in
      .init(
        identity: .init(section: .init(wreck: wreck, section: section.index), lot: UInt16(index)),
        content: content.0,
        position: pose.position + offset + normal * (content.1.length + 10)
          + tangent * Double(index % 5) * 8,
        velocity: velocity + angularVelocity.cross(offset) + normal * 3,
        halfExtents: content.1, massKg: content.2)
    }
  }
}
