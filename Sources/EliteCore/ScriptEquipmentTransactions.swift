import Foundation

extension Game {
  func issueScriptGear(
    _ definition: ScriptGearDefinition, fields: [String: ScriptValue], command: UUID,
    state: inout ScriptInstance, candidate: inout Commander
  ) throws -> (String, [String: ScriptValue])? {
    if state.gearIssues[definition.id] != nil { return nil }
    let fit: Bool
    if let value = fields["fit"] {
      guard case .bool(let desired) = value else {
        throw MissionPackError("Equipment fit must be true or false.")
      }
      fit = desired
    } else {
      fit = false
    }
    guard definition.valid, let kind = definition.kind, let node = kind.canonicalNode,
      let inventory = candidate.equipmentInventory
    else { throw EquipmentIssueError.invalidRequest }
    let source = EquipmentIssueSource(
      mission: state.id, resource: definition.id, packDigest: state.digest)
    let identities = (0..<definition.quantity).map {
      OwnedGear.issuedIdentity(mission: state.id, resource: definition.id, index: $0)
    }
    let devices = identities.enumerated().map { index, id in
      IssuedDeviceRequest(
        id: id, node: node, index: index,
        preferredSlot: definition.slot(index).canonicalSlot)
    }
    let context = EquipmentRuntimeCatalog.context(
      owner: inventory.owner, hull: inventory.activeHull, performance: candidate.nativePerformance)
    var allocated: Set<ComponentFittingSlot> = []
    let fittings: [IssueFitting]
    if fit {
      fittings = try devices.map { device -> IssueFitting in
        let choices: [ComponentFittingSlot]
        switch kind {
        case .missile:
          choices = (0..<max(0, min(32, candidate.nativePerformance.missiles))).map {
            .missilePylon($0)
          }
        case .fuelStorage:
          choices = (0..<FuelStorage.maximumCount).map { .fuelStorage($0) }
        default:
          choices = device.preferredSlot.map { [$0] } ?? []
        }
        let available = choices.filter { !allocated.contains($0) }
        let free = available.first { slot in
          !inventory.items.contains { $0.location?.slot == slot }
        }
        guard let slot = free ?? available.first else { throw OwnedEquipmentError.unsupportedSlot }
        allocated.insert(slot)
        let location = ComponentFittingLocation(hullInstanceID: inventory.activeHull, slot: slot)
        return .init(
          item: device.id, location: location,
          replacing: inventory.items.first { $0.location == location })
      }
    } else {
      fittings = []
    }
    let request = EquipmentIssueRequest(
      command: command, source: source, devices: devices, fitting: fit ? .fitAll(fittings) : .held)
    // These temporary candidate values derive budget facts only. Admission owns physical creation.
    var projected = inventory.items
    for (index, device) in devices.enumerated() {
      let location = fit ? fittings[index].location : nil
      if let location {
        projected = projected.map { $0.location == location ? $0.moved(to: nil) : $0 }
      }
      projected.append(
        .init(
          id: device.id, node: node,
          provenance: .missionIssue(
            mission: source.mission, resource: source.resource,
            index: device.index, packDigest: source.packDigest),
          component: EquipmentRuntimeCatalog.stockComponent(for: node, id: device.id),
          location: location,
          boundHull: device.preferredSlot == .utility(.cargoExpansion) ? inventory.activeHull : nil,
          preferredSlot: device.preferredSlot))
    }
    let budget = try candidate.equipmentFitBudget(projectedItems: projected)
    let obligations = try candidate.equipmentIssueObligations()
    let quote = try EquipmentIssueTransactions.quoteAdmission(
      request: request, inventory: inventory, context: context, obligations: obligations,
      budget: budget)
    let applied = try EquipmentIssueTransactions.applyAdmission(
      quote: quote, inventory: inventory, context: context, obligations: obligations, budget: budget
    )
    guard applied.receipt.command == command, applied.receipt.source == source,
      applied.receipt.operation == .issued, applied.receipt.originalItems == identities,
      applied.receipt.consumedItems.isEmpty
    else { throw EquipmentIssueError.identityMismatch }
    candidate.savedEquipmentInventory = applied.inventory
    candidate.mirrorFittedEquipment()
    state.gearIssues[definition.id] = .init(
      resource: definition.id, kind: kind, items: identities, loan: definition.loan,
      returnRemaining: definition.returnPolicy == "remaining", savedGearVersion: 2,
      source: source, node: node, displacements: applied.receipt.displacements)
    return (
      "equipment.issued",
      [
        "gear": .string(definition.id), "items": .array(identities.map { .string($0.uuidString) }),
        "loan": .bool(definition.loan),
      ]
    )
  }

  func settleScriptGear(
    _ record: ScriptGearIssue, release: Bool, command: UUID,
    state: inout ScriptInstance, candidate: inout Commander
  ) throws -> (String, [String: ScriptValue]) {
    guard let obligation = record.obligation, let inventory = candidate.equipmentInventory else {
      throw EquipmentIssueError.invalidRequest
    }
    let operation: EquipmentIssueSettlement = release ? .releaseLoan : .returnOriginals
    let context = EquipmentRuntimeCatalog.context(
      owner: inventory.owner, hull: inventory.activeHull, performance: candidate.nativePerformance)
    let obligations = try candidate.equipmentIssueObligations()
    let projection = try EquipmentIssueTransactions.projectSettlement(
      operation: operation, obligation: obligation, inventory: inventory,
      context: context, obligations: obligations)
    let budget = try candidate.equipmentFitBudget(projectedItems: projection.items)
    let quote = try EquipmentIssueTransactions.quoteSettlement(
      command: command, operation: operation, obligation: obligation, inventory: inventory,
      context: context, obligations: obligations, budget: budget)
    let applied = try EquipmentIssueTransactions.applySettlement(
      quote: quote, inventory: inventory, context: context, obligations: obligations, budget: budget
    )
    guard applied.receipt.command == command, applied.receipt.source == obligation.source,
      applied.receipt.originalItems == record.items,
      applied.receipt.consumedItems == record.consumed,
      applied.receipt.operation == (release ? .released : .returned)
    else { throw EquipmentIssueError.identityMismatch }
    candidate.savedEquipmentInventory = applied.inventory
    candidate.mirrorFittedEquipment()
    var settled = record
    settled.status = release ? .released : .returned
    state.gearIssues[record.resource] = settled
    return (
      release ? "equipment.released" : "equipment.returned",
      [
        "gear": .string(record.resource),
        "items": .array(
          record.items.filter { !record.consumed.contains($0) }.map {
            .string($0.uuidString)
          }),
        "consumed": .integer(Int64(record.consumed.count)),
      ]
    )
  }

  func refitScriptGear(
    _ record: ScriptGearIssue, fields: [String: ScriptValue], fitted: Bool, command: UUID,
    state: inout ScriptInstance, candidate: inout Commander
  ) throws -> (String, [String: ScriptValue]) {
    guard let index = fields["index"]?.integer, (0..<Int64(record.items.count)).contains(index),
      let inventory = candidate.equipmentInventory, let obligation = record.obligation,
      let item = inventory.items.first(where: { $0.id == record.items[Int(index)] })
    else { throw MissionPackError("The exact original equipment item is required.") }
    guard !fitted || item.location == nil else {
      throw MissionPackError("Only a stored issued item can be refitted.")
    }
    let slot: ComponentFittingSlot?
    if let value = fields["mount"] {
      guard let name = value.string, let mount = LaserMount(rawValue: name),
        case .laser = record.kind
      else { throw MissionPackError("A known laser mount is required.") }
      slot = .laser(mount)
    } else if fitted, case .missile = record.kind {
      slot = (0..<max(0, min(32, candidate.nativePerformance.missiles)))
        .map(ComponentFittingSlot.missilePylon).first { requested in
          !inventory.items.contains { $0.location?.slot == requested }
        }
    } else if fitted, case .fuelStorage = record.kind {
      slot = (0..<FuelStorage.maximumCount).map(ComponentFittingSlot.fuelStorage)
        .first { requested in !inventory.items.contains { $0.location?.slot == requested } }
    } else {
      slot = item.preferredSlot ?? EquipmentRuntimeCatalog.slot(for: item.node)
    }
    guard !fitted || slot != nil else { throw EquipmentIssueError.invalidRequest }
    let destination =
      fitted
      ? slot.map {
        ComponentFittingLocation(hullInstanceID: inventory.activeHull, slot: $0)
      } : nil
    let replacing = destination.flatMap { target in
      inventory.items.first { $0.location == target && $0.id != item.id }
    }
    guard replacing.map(EquipmentIssueTransactions.isIntrinsicFoundation) ?? true else {
      throw MissionPackError(
        "Store or return the actual occupied item before refitting this issue.")
    }
    let projected = inventory.items.map { current in
      if current.id == item.id { return current.moved(to: destination) }
      if current.id == replacing?.id { return current.moved(to: nil) }
      return current
    }
    let budget = try candidate.equipmentFitBudget(projectedItems: projected)
    let context = EquipmentRuntimeCatalog.context(
      owner: inventory.owner, hull: inventory.activeHull, performance: candidate.nativePerformance)
    let obligations = try candidate.equipmentIssueObligations()
    let quote = try EquipmentIssueTransactions.quoteFitting(
      command: command, obligation: obligation, item: item, destination: destination,
      replacing: replacing, inventory: inventory, context: context, obligations: obligations,
      budget: budget)
    let applied = try EquipmentIssueTransactions.applyFitting(
      quote: quote, inventory: inventory, context: context, obligations: obligations, budget: budget
    )
    guard applied.receipt.command == command, applied.receipt.source == obligation.source,
      applied.receipt.operation == (fitted ? .refitted : .stored),
      applied.receipt.originalItems == record.items,
      applied.receipt.consumedItems == record.consumed
    else { throw EquipmentIssueError.identityMismatch }
    candidate.savedEquipmentInventory = applied.inventory
    candidate.mirrorFittedEquipment()
    state.gearIssues[record.resource] = record.replacingDisplacements(applied.receipt.displacements)
    return (
      "equipment.changed",
      [
        "gear": .string(record.resource), "item": .string(item.id.uuidString),
        "fitted": .bool(fitted),
      ]
    )
  }
}
