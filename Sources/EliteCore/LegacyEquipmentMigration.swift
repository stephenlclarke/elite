import Foundation

extension Commander {
  var legacyIssueStateValid: Bool {
    guard let legacyOwnedEquipment, savedEquipmentInventory == nil,
      savedEquipmentPurchaseHistory == nil, savedEquipmentVersion == nil
    else { return false }
    return (try? legacyOwnedEquipment.validateIssues(in: scriptState)) != nil
      && legacyEquipmentMirrorsMatch
  }

  /// The old bag must agree with its old capability mirrors before conversion.
  /// This check never synchronizes, replaces an original or guesses consumption.
  var legacyEquipmentMirrorsMatch: Bool {
    guard let legacyOwnedEquipment, legacyOwnedEquipment.valid,
      (0...nativePerformance.missiles).contains(missiles),
      (0..<FuelStorage.maximumCount + 1).contains(fuelStorageUnits)
    else { return false }
    var actual: [(OwnedGearKind, OwnedGearSlot)] = []
    for mount in LaserMount.allCases {
      if let laser = laser(on: mount) { actual.append((.laser(laser), .laser(mount))) }
    }
    for index in 0..<missiles { actual.append((.missile, .pylon(index))) }
    for name in equipment.sorted() where OwnedGearKind.module(name).valid {
      actual.append((.module(name), .module(name)))
    }
    for index in 0..<fuelStorageUnits { actual.append((.fuelStorage, .fuelStorage(index))) }
    let fitted = legacyOwnedEquipment.fitted
    return fitted.count == actual.count
      && actual.allSatisfy { kind, slot in
        fitted.contains { $0.kind == kind && $0.fittedSlot == slot }
      }
  }

  /// All original physical IDs survive. Only genuinely implicit free systems are
  /// materialized, once, at this explicit legacy admission boundary.
  mutating func migrateLegacyOwnedEquipment(
    owner: UUID, hull: UUID, allocatingItemIDs: () -> UUID
  ) throws {
    guard let legacy = legacyOwnedEquipment else { return }
    try validateEquipmentState()
    guard scriptState.valid, legacy.items.count <= OwnedEquipmentInventory.maximumCount else {
      throw EquipmentMigrationError.unsupportedLegacyState
    }
    var items = try legacy.items.map { item -> OwnedEquipmentItem in
      guard let node = item.kind.canonicalNode, let preferred = item.preferredSlot.canonicalSlot,
        item.fittedSlot == nil || item.fittedSlot?.canonicalSlot != nil
      else {
        throw EquipmentMigrationError.invalidCrosswalk
      }
      let provenance: EquipmentAcquisitionProvenance
      if let mission = item.issuedBy {
        guard let resource = item.sourceResource, let instance = scriptState.instances[mission],
          let issue = instance.gearIssues[resource], let index = issue.items.firstIndex(of: item.id)
        else { throw EquipmentMigrationError.obligationMismatch }
        provenance = .missionIssue(
          mission: mission, resource: resource, index: index,
          packDigest: instance.digest)
      } else {
        provenance = .legacyUnknown
      }
      let slot = item.fittedSlot?.canonicalSlot
      return .init(
        id: item.id, node: node, provenance: provenance,
        component: try migratedComponent(node: node, name: item.kind.name, id: item.id),
        location: slot.map { .init(hullInstanceID: hull, slot: $0) },
        boundHull: item.kind == .module("Large Cargo Bay") ? hull : nil,
        preferredSlot: preferred,
        retainedLegacyState: .init(
          conditionBasisPoints: item.condition, modifications: item.modifications))
    }
    var restorations: [UUID: [String: [EquipmentIssueDisplacement]]] = [:]
    for (name, slot) in [
      ("Basic Shield", ComponentFittingSlot.shield),
      ("Basic Energy System", .energy), (NavigationTier.basic.equipmentName, .navigation),
    ] {
      let fitted = items.first { $0.location?.slot == slot }
      var issue: EquipmentIssueSource?
      if let fitted {
        guard case .missionIssue(let mission, let resource, _, let digest) = fitted.provenance,
          scriptState.instances[mission]?.gearIssues[resource]?.status == .issued
        else { continue }
        issue = .init(mission: mission, resource: resource, packDigest: digest)
      }
      guard let node = EquipmentRuntimeCatalog.node(for: name) else {
        throw EquipmentMigrationError.invalidCrosswalk
      }
      let foundation: OwnedEquipmentItem
      if let retained = items.first(where: { item in
        if case .missionIssue = item.provenance { return false }
        return item.node == node && item.location == nil
          && (item.retainedLegacyState?.pristine ?? true)
      }) {
        foundation = retained
      } else {
        let identity = allocatingItemIDs()
        foundation = .init(
          id: identity, node: node, provenance: .standard,
          component: try migratedComponent(node: node, name: name, id: identity))
        items.append(foundation)
      }
      let location = ComponentFittingLocation(hullInstanceID: hull, slot: slot)
      if let issue {
        restorations[issue.mission, default: [:]][issue.resource, default: []]
          .append(.init(item: foundation.id, location: location))
      } else {
        items = items.map { $0.id == foundation.id ? $0.moved(to: location) : $0 }
      }
    }
    let inventory = try OwnedEquipmentInventory(owner: owner, activeHull: hull, items: items)
    try inventory.validate(
      context: EquipmentRuntimeCatalog.context(
        owner: owner, hull: hull,
        performance: nativePerformance))
    var engine = scriptState
    let surviving = Set(items.map(\.id))
    for id in engine.instances.keys {
      guard var instance = engine.instances[id] else { continue }
      for (resource, record) in instance.gearIssues {
        guard let node = record.kind.canonicalNode, (record.savedGearVersion ?? 1) == 1 else {
          throw EquipmentMigrationError.obligationMismatch
        }
        let missing = Set(record.items).subtracting(record.consumed).subtracting(surviving)
        let historicalMissing = record.status == .returned ? Set<UUID>() : missing
        guard !record.loan || historicalMissing.isEmpty else {
          throw EquipmentMigrationError.obligationMismatch
        }
        instance.gearIssues[resource] = .init(
          resource: resource, kind: record.kind, items: record.items,
          loan: record.loan, returnRemaining: record.returnRemaining, status: record.status,
          consumed: record.consumed, savedGearVersion: 2,
          source: .init(mission: id, resource: resource, packDigest: instance.digest), node: node,
          displacements: restorations[id]?[resource] ?? [],
          legacyMissingItems: historicalMissing.isEmpty ? nil : historicalMissing)
      }
      engine.instances[id] = instance
    }
    let entitlements = try items.filter { $0.provenance == .legacyUnknown }.map { item in
      try EquipmentPurchaseProgression.legacyEntitlement(
        for: .init(id: item.id, node: item.node, provenance: item.provenance), owner: owner,
        graph: EquipmentRuntimeCatalog.graph)
    }
    var candidate = self
    candidate.legacyOwnedEquipment = nil
    candidate.savedEquipmentInventory = inventory
    candidate.savedEquipmentPurchaseHistory = .init(owner: owner, legacy: entitlements)
    candidate.savedEquipmentVersion = 2
    candidate.scriptState = engine
    candidate.mirrorFittedEquipment()
    guard candidate.valid else { throw EquipmentMigrationError.obligationMismatch }
    self = candidate
  }
}
