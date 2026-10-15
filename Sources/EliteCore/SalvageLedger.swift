import Foundation

public struct SalvageWreckMotion: Equatable, Codable, Sendable {
  public let pose: ShipPose
  public let velocity: Vector3
  public let angularVelocity: Vector3
  public init(pose: ShipPose, velocity: Vector3, angularVelocity: Vector3) {
    self.pose = pose
    self.velocity = velocity
    self.angularVelocity = angularVelocity
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
  case unavailable, protectedPayload, noScoops, unsafeApproach, oversized, fullHold, invalidCargo
}

public enum SalvageCollectionReceipt: Equatable, Codable, Sendable {
  case collected(SalvageLot)
  case refused(SalvageCollectionRefusal)
}

public struct SalvageSettlementProposal: Equatable, Codable, Sendable {
  public let command: UUID
  public let revision: UInt64
  public let items: [SalvageLot]
  public let action: SalvageDefinitionAction
  public let saleValueTenths: Int
}

public enum SalvageSettlementReceipt: Equatable, Codable, Sendable {
  case committed(SalvageSettlementProposal)
  case refused
}

/// G1 publishes this state with cargo, equipment and cash in one actor transaction.
public struct SalvageLedger: Equatable, Codable, Sendable {
  public static let maximumPending = 256
  public static let maximumInventory = 128
  public static let maximumPartial = 256
  public static let maximumWrecks = 4096
  public static let maximumSettlements = 1024
  public static let maximumSettledItems = 2048
  private let seed: UInt64
  private var motions: [WreckIdentity: SalvageWreckMotion] = [:]
  private var depleted: [WreckIdentity: UInt64] = [:]
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
    case seed, motions, depleted, work, damagedTechnology, pending, stored, offers, bindings
    case settlements, lastOperation, settledItemCount, sequence, revision
  }

  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    seed = try values.decode(UInt64.self, forKey: .seed)
    motions =
      try values.decodeIfPresent([WreckIdentity: SalvageWreckMotion].self, forKey: .motions) ?? [:]
    depleted = try values.decode([WreckIdentity: UInt64].self, forKey: .depleted)
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
    guard trackedWrecks.count <= Self.maximumWrecks,
      motions.allSatisfy({ Self.validWreck($0.key) && Self.validMotion($0.value) }),
      depleted.count <= Self.maximumWrecks, work.count <= Self.maximumPartial,
      pending.count <= Self.maximumPending, stored.count <= Self.maximumInventory,
      offers.count <= pending.count, bindings.count <= pending.count,
      settlements.count <= Self.maximumSettlements,
      (0...Self.maximumSettledItems).contains(settledItemCount),
      damagedTechnology.isSubset(of: Set(work.keys)),
      depleted.keys.allSatisfy({ Self.validWreck($0) }),
      work.allSatisfy({
        Self.validWreck($0.key.wreck) && $0.key.section < 64
          && !isDepleted($0.key) && $0.value.isFinite && $0.value > 0
      }),
      pending.allSatisfy({
        $0.key == $0.value.identity && validLot($0.value)
          && isDepleted($0.key.section) && stored[$0.key] == nil
      }),
      stored.allSatisfy({
        $0.key == $0.value.identity && isTechnology($0.value) && validLot($0.value)
          && isDepleted($0.key.section)
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
        proposal.items.allSatisfy({
          isTechnology($0) && validLot($0) && isDepleted($0.identity.section)
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
          saleValue += SalvageDefinitions.saleValue(
            definition: definition, conditionPercent: condition)
        }
      }
      guard proposal.saleValueTenths == saleValue else { return false }
    }
    return settled.count == settledItemCount
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
    Set(motions.keys).union(depleted.keys).union(work.keys.map(\.wreck))
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
      && abs(basis.x.length - 1) < epsilon && abs(basis.y.length - 1) < epsilon
      && abs(basis.z.length - 1) < epsilon && abs(basis.x.dot(basis.y)) < epsilon
      && abs(basis.x.dot(basis.z)) < epsilon && abs(basis.y.dot(basis.z)) < epsilon
      && basis.x.cross(basis.y).dot(basis.z) > 1 - epsilon
  }

  public func wreckMotion(for identity: WreckIdentity) -> SalvageWreckMotion? { motions[identity] }

  /// Store live canonical motion on cull/save; this ledger never advances offscreen time.
  @discardableResult public mutating func updateWreck(
    identity: WreckIdentity,
    motion: SalvageWreckMotion
  ) -> Bool {
    guard Self.validWreck(identity), Self.validMotion(motion), canTrack(identity) else {
      return false
    }
    motions[identity] = motion
    return true
  }

  public var pendingLots: [SalvageLot] { sorted(pending.values) }
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
    elapsed: Double, operation: UInt64, conditions: SalvageWorkConditions
  ) -> SalvageWorkResult {
    let identity = WreckSectionIdentity(wreck: wreck, section: section.index)
    guard Self.validWreck(wreck), section.index < 64, elapsed.isFinite, elapsed > 0, elapsed <= 1,
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
    guard Self.validWreck(section.wreck), section.section < 64,
      lastOperation.map({ operation > $0 }) ?? true
    else {
      return .blocked
    }
    guard !isDepleted(section) else { return .alreadyDepleted }
    guard canTrack(section.wreck) else {
      return .capacityRefused
    }
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
            category: lot.category, ownership: .abandoned, claimant: nil,
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
    case .technology:
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
    action: SalvageDefinitionAction
  ) -> SalvageSettlementProposal? {
    if case .committed(let proposal) = settlements[command] {
      return proposal.items.map(\.identity) == items && proposal.action == action ? proposal : nil
    }
    guard !items.isEmpty, Set(items).count == items.count,
      settlements.count < Self.maximumSettlements,
      items.count <= Self.maximumSettledItems - settledItemCount
    else { return nil }
    let lots = items.compactMap { stored[$0] }
    guard lots.count == items.count else { return nil }
    var value = 0
    for lot in lots {
      guard case .technology(let id, _, let condition) = lot.content,
        let definition = SalvageDefinitions.definition(id: id)
      else { return nil }
      if action == .sell {
        let price = SalvageDefinitions.saleValue(
          definition: definition, conditionPercent: condition)
        guard price <= Int.max / 17 - value else { return nil }
        value += price
      }
    }
    return .init(
      command: command, revision: revision, items: lots, action: action,
      saleValueTenths: value)
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
        action: proposal.action) == proposal
    else { return .refused }
    for lot in proposal.items { stored.removeValue(forKey: lot.identity) }
    let receipt = SalvageSettlementReceipt.committed(proposal)
    settlements[proposal.command] = receipt
    settledItemCount += proposal.items.count
    revision &+= 1
    return receipt
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
