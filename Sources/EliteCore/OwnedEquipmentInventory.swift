import Foundation

public struct OwnedEquipmentItem: Equatable, Codable, Sendable {
  public let id: UUID
  public let node: EquipmentNodeID
  public let provenance: EquipmentAcquisitionProvenance
  public let component: ComponentInstance?
  public let location: ComponentFittingLocation?
  /// Permanent hull attachment survives storage; only the runtime can settle hull exchange.
  public let boundHull: UUID?
  public let preferredSlot: ComponentFittingSlot?
  public let retainedLegacyState: LegacyEquipmentState?

  public init(
    id: UUID, node: EquipmentNodeID, provenance: EquipmentAcquisitionProvenance,
    component: ComponentInstance? = nil, location: ComponentFittingLocation? = nil,
    boundHull: UUID? = nil, preferredSlot: ComponentFittingSlot? = nil,
    retainedLegacyState: LegacyEquipmentState? = nil
  ) {
    self.id = id
    self.node = node
    self.provenance = provenance
    self.component = component
    self.location = location
    self.boundHull = boundHull
    self.preferredSlot = preferredSlot
    self.retainedLegacyState = retainedLegacyState
  }

  func moved(to location: ComponentFittingLocation?) -> Self {
    .init(
      id: id, node: node, provenance: provenance, component: component, location: location,
      boundHull: boundHull, preferredSlot: preferredSlot, retainedLegacyState: retainedLegacyState)
  }
}

public struct OwnedEquipmentNodeCapability: Equatable, Sendable {
  public let slots: Set<ComponentFittingSlot>
  public let componentFamily: ComponentFamily?
  public init(slots: Set<ComponentFittingSlot>, componentFamily: ComponentFamily? = nil) {
    self.slots = slots
    self.componentFamily = componentFamily
  }
}

/// Caller-authorized facts for the one active hull, never inferred from equipment names.
public struct OwnedEquipmentContext: Equatable, Sendable {
  public let owner: UUID
  public let activeHull: UUID
  public let supportedSlots: Set<ComponentFittingSlot>
  public let nodes: [EquipmentNodeID: OwnedEquipmentNodeCapability]
  /// Installed counts only. Purchase history separately checks held plus fitted purchase caps.
  public let familyLimits: [EquipmentFamilyID: Int]
  public let definitions: [ComponentFamily: ComponentFamilyDefinition]

  public init(
    owner: UUID, activeHull: UUID, supportedSlots: Set<ComponentFittingSlot>,
    nodes: [EquipmentNodeID: OwnedEquipmentNodeCapability],
    familyLimits: [EquipmentFamilyID: Int],
    definitions: [ComponentFamily: ComponentFamilyDefinition] = [:]
  ) {
    self.owner = owner
    self.activeHull = activeHull
    self.supportedSlots = supportedSlots
    self.nodes = nodes
    self.familyLimits = familyLimits
    self.definitions = definitions
  }
}

public enum OwnedEquipmentError: Error, Equatable, Sendable {
  case invalidStructure, invalidContext, wrongOwner, wrongHull, unknownNode, unknownFamily
  case incompatibleComponent, unsupportedSlot, familyLimit, capacity, duplicateItem
  case staleRevision, staleItem, occupiedSlot, noChange, revisionExhausted
}

/// Physical items only: no funds, entitlement history, salvage consumption or resource levels.
public struct OwnedEquipmentInventory: Equatable, Codable, Sendable {
  public static let maximumCount = 256
  public let owner: UUID
  public let activeHull: UUID
  public private(set) var revision: UInt64
  public private(set) var items: [OwnedEquipmentItem]

  public init(
    owner: UUID, activeHull: UUID, revision: UInt64 = 0, items: [OwnedEquipmentItem] = []
  ) throws {
    self.owner = owner
    self.activeHull = activeHull
    self.revision = revision
    self.items = items
    try validateStructure()
  }

  private enum CodingKeys: String, CodingKey { case owner, activeHull, revision, items }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    owner = try values.decode(UUID.self, forKey: .owner)
    activeHull = try values.decode(UUID.self, forKey: .activeHull)
    revision = try values.decode(UInt64.self, forKey: .revision)
    var records = try values.nestedUnkeyedContainer(forKey: .items)
    var decoded: [OwnedEquipmentItem] = []
    while !records.isAtEnd {
      guard decoded.count < Self.maximumCount else { throw OwnedEquipmentError.capacity }
      decoded.append(try records.decode(OwnedEquipmentItem.self))
    }
    items = decoded
    try validateStructure()
  }

  /// Mandatory after decoding and before accepting runtime load data; every mutation repeats it.
  public func validate(context: OwnedEquipmentContext) throws {
    try validateStructure()
    guard context.owner == owner else { throw OwnedEquipmentError.wrongOwner }
    guard context.activeHull == activeHull else { throw OwnedEquipmentError.wrongHull }
    guard context.supportedSlots.allSatisfy(\.valid),
      context.nodes.allSatisfy({ node, capability in
        !node.family.rawValue.isEmpty && !node.key.isEmpty && capability.slots.allSatisfy(\.valid)
      }),
      context.familyLimits.allSatisfy({ family, limit in
        !family.rawValue.isEmpty && (0...Self.maximumCount).contains(limit)
      })
    else { throw OwnedEquipmentError.invalidContext }
    var fitted: [EquipmentFamilyID: Int] = [:]
    for item in items {
      guard let capability = context.nodes[item.node] else { throw OwnedEquipmentError.unknownNode }
      guard let limit = context.familyLimits[item.node.family] else {
        throw OwnedEquipmentError.unknownFamily
      }
      if let family = capability.componentFamily {
        guard let component = item.component, component.family == family else {
          throw OwnedEquipmentError.incompatibleComponent
        }
        guard let definition = context.definitions[family], definition.family == family else {
          throw OwnedEquipmentError.unknownFamily
        }
        try ComponentProgression.validateLoaded(component, definition: definition)
      } else if item.component != nil {
        throw OwnedEquipmentError.incompatibleComponent
      }
      if let location = item.location {
        guard context.supportedSlots.contains(location.slot),
          capability.slots.contains(location.slot)
        else { throw OwnedEquipmentError.unsupportedSlot }
        fitted[item.node.family, default: 0] += 1
        guard fitted[item.node.family, default: 0] <= limit else {
          throw OwnedEquipmentError.familyLimit
        }
      }
    }
  }

  public mutating func admit(
    _ item: OwnedEquipmentItem, expectedRevision: UInt64, context: OwnedEquipmentContext
  ) throws {
    try mutate(expectedRevision: expectedRevision, context: context) { items in
      guard items.count < Self.maximumCount else { throw OwnedEquipmentError.capacity }
      guard !items.contains(where: { $0.id == item.id }) else {
        throw OwnedEquipmentError.duplicateItem
      }
      items.append(item)
    }
  }

  /// An occupied slot changes only when its complete current item is explicitly supplied.
  /// Replacement stores that item; it never removes it from physical ownership.
  public mutating func fit(
    expected item: OwnedEquipmentItem, at location: ComponentFittingLocation,
    replacing occupied: OwnedEquipmentItem? = nil,
    expectedRevision: UInt64, context: OwnedEquipmentContext
  ) throws {
    try mutate(expectedRevision: expectedRevision, context: context) { items in
      let index = try Self.index(of: item, in: items)
      guard item.location != location else { throw OwnedEquipmentError.noChange }
      if let occupant = items.firstIndex(where: { $0.location == location }) {
        guard let occupied else { throw OwnedEquipmentError.occupiedSlot }
        guard items[occupant] == occupied else { throw OwnedEquipmentError.staleItem }
        items[occupant] = occupied.moved(to: nil)
      } else if occupied != nil {
        throw OwnedEquipmentError.staleItem
      }
      items[index] = item.moved(to: location)
    }
  }

  public mutating func store(
    expected item: OwnedEquipmentItem, expectedRevision: UInt64, context: OwnedEquipmentContext
  ) throws {
    try mutate(expectedRevision: expectedRevision, context: context) { items in
      let index = try Self.index(of: item, in: items)
      guard item.location != nil else { throw OwnedEquipmentError.noChange }
      items[index] = item.moved(to: nil)
    }
  }

  /// The caller decides whether removal of a permanent hull-bound item is permitted.
  /// The returned complete item retains its attachment and acquisition provenance.
  @discardableResult public mutating func remove(
    expected item: OwnedEquipmentItem, expectedRevision: UInt64, context: OwnedEquipmentContext
  ) throws -> OwnedEquipmentItem {
    try mutate(expectedRevision: expectedRevision, context: context) { items in
      items.remove(at: try Self.index(of: item, in: items))
    }
    return item
  }

  public mutating func replaceGradedInstance(
    expected item: OwnedEquipmentItem, application: ComponentUpgradeApplication,
    expectedRevision: UInt64, sourceInventoryRevision: UInt64,
    context: OwnedEquipmentContext
  ) throws {
    try mutate(expectedRevision: expectedRevision, context: context) { items in
      let index = try Self.index(of: item, in: items)
      guard item.retainedLegacyState?.pristine ?? true else {
        throw OwnedEquipmentError.incompatibleComponent
      }
      guard let before = item.component,
        let definition = context.definitions[before.family]
      else { throw OwnedEquipmentError.incompatibleComponent }
      try ComponentProgression.validateApplication(
        application, before: before, definition: definition,
        sourceInventoryRevision: sourceInventoryRevision)
      items[index] = .init(
        id: item.id, node: item.node, provenance: item.provenance,
        component: application.component, location: item.location, boundHull: item.boundHull,
        preferredSlot: item.preferredSlot, retainedLegacyState: item.retainedLegacyState)
    }
  }

  private func validateStructure() throws {
    guard items.count <= Self.maximumCount else { throw OwnedEquipmentError.capacity }
    guard Set(items.map(\.id)).count == items.count else { throw OwnedEquipmentError.duplicateItem }
    let locations = items.compactMap(\.location)
    guard Set(locations).count == locations.count else { throw OwnedEquipmentError.occupiedSlot }
    for item in items {
      guard !item.node.family.rawValue.isEmpty, !item.node.key.isEmpty,
        item.component.map({ $0.id == item.id }) ?? true
      else { throw OwnedEquipmentError.invalidStructure }
      guard item.boundHull.map({ $0 == activeHull }) ?? true,
        item.location.map({ $0.hullInstanceID == activeHull }) ?? true
      else { throw OwnedEquipmentError.wrongHull }
      guard item.location?.slot.valid ?? true else { throw OwnedEquipmentError.unsupportedSlot }
      guard item.preferredSlot?.valid ?? true, item.retainedLegacyState?.valid ?? true,
        item.location == nil || (item.retainedLegacyState?.pristine ?? true)
      else { throw OwnedEquipmentError.invalidStructure }
      if item.node.family == EquipmentRuntimeCatalog.ammunitionFamily {
        guard item.node == EquipmentRuntimeCatalog.standardMissile, item.component == nil,
          item.boundHull == nil
        else { throw OwnedEquipmentError.invalidStructure }
      }
      if case .missionIssue(let mission, let resource, let index, let digest) = item.provenance {
        guard (0..<32).contains(index),
          EquipmentIssueSource(mission: mission, resource: resource, packDigest: digest).valid
        else { throw OwnedEquipmentError.invalidStructure }
      }
    }
  }

  /// Structural atomic primitive. Domain providers validate rights, receipts and budgets
  /// before calling it; release uses the same batch even when the physical array is equal.
  public func applyingBatch(
    items: [OwnedEquipmentItem], expectedRevision: UInt64, context: OwnedEquipmentContext
  ) throws -> Self {
    guard revision == expectedRevision else { throw OwnedEquipmentError.staleRevision }
    guard revision < UInt64.max else { throw OwnedEquipmentError.revisionExhausted }
    try validate(context: context)
    let candidate = try Self(
      owner: owner, activeHull: activeHull, revision: revision + 1, items: items)
    try candidate.validate(context: context)
    return candidate
  }

  private static func index(of expected: OwnedEquipmentItem, in items: [OwnedEquipmentItem]) throws
    -> Int
  {
    guard let index = items.firstIndex(where: { $0.id == expected.id }), items[index] == expected
    else {
      throw OwnedEquipmentError.staleItem
    }
    return index
  }

  private mutating func mutate(
    expectedRevision: UInt64, context: OwnedEquipmentContext,
    edit: (inout [OwnedEquipmentItem]) throws -> Void
  ) throws {
    guard revision == expectedRevision else { throw OwnedEquipmentError.staleRevision }
    guard revision < UInt64.max else { throw OwnedEquipmentError.revisionExhausted }
    try validate(context: context)
    var candidate = self
    try edit(&candidate.items)
    try candidate.validate(context: context)
    candidate.revision += 1
    self = candidate
  }
}
