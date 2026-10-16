import Foundation

/// Ephemeral interaction context, separate from persistent commander and hull identities.
public struct InventoryContextEpoch: Sendable, Equatable {
  private let value: UUID
  init() { value = UUID() }
}

public enum InventorySubject: Sendable, Equatable {
  case equipment(OwnedEquipmentItem)
  case recovered(SalvageLot)
}

public struct InventoryInformationRow: Sendable, Equatable {
  public let text: String
  public let ink: Ink
  public let subject: InventorySubject?
  init(_ text: String, _ ink: Ink, subject: InventorySubject? = nil) {
    self.text = text
    self.ink = ink
    self.subject = subject
  }
}

public struct InventoryCommand: Sendable, Equatable {
  enum Action: Sendable, Equatable {
    case fit(OwnedEquipmentItem, ComponentFittingSlot)
    case store(OwnedEquipmentItem)
    case upgrade(
      OwnedEquipmentItem, SalvageLot, SalvageUpgradeAxis, ComponentFittingSlot,
      before: ComponentStatistics, after: ComponentStatistics, grade: ComponentTemplateVersion)
  }
  let owner: UUID
  let hull: UUID
  let context: InventoryContextEpoch
  let shipID: String
  let ownedRevision: UInt64
  let sourceRevision: UInt64?
  let action: Action
}

public struct InventoryActionPreview: Sendable, Equatable {
  public let label: String
  public let detail: String
  public let command: InventoryCommand?
}

public struct InventoryControl: Sendable, Equatable {
  public let bounds: CanvasRect
  public let command: InventoryCommand
  init(bounds: CanvasRect, command: InventoryCommand) {
    self.bounds = bounds
    self.command = command
  }
}

/// Kept by the native view only after the corresponding frame was successfully painted.
public struct InventoryInteraction: Sendable, Equatable {
  public var controls: [InventoryControl] = []
  public var selected = 0
  public init() {}
  public var primary: InventoryCommand? {
    guard !controls.isEmpty else { return nil }
    return controls[max(0, selected) % controls.count].command
  }
  public func command(at point: SIMD2<Double>) -> InventoryCommand? {
    controls.first { $0.bounds.contains(point) }?.command
  }
}

extension Game {
  public func inventoryActionPreview(for subject: InventorySubject) -> InventoryActionPreview {
    guard let inventory = commander.equipmentInventory else {
      return .init(label: "", detail: "Ownership must be initialized first", command: nil)
    }
    func command(_ action: InventoryCommand.Action, source: UInt64? = nil) -> InventoryCommand {
      .init(
        owner: inventory.owner, hull: inventory.activeHull, context: inventoryContextEpoch,
        shipID: commander.shipID,
        ownedRevision: inventory.revision,
        sourceRevision: source, action: action)
    }
    do {
      switch subject {
      case .equipment(let item):
        guard inventory.items.contains(item), docked else {
          return .init(label: "", detail: "Dock to change physical fittings", command: nil)
        }
        var projected = commander
        if item.location != nil {
          guard inventoryMayStore(item) else {
            return .init(
              label: "", detail: "Required ship system - replace with a compatible device",
              command: nil)
          }
          try projected.storeEquipment(item, expectedRevision: inventory.revision)
          return .init(
            label: "Store", detail: "Keep this device aboard", command: command(.store(item)))
        }
        let slot = try inventoryFitSlot(item.node)
        try projected.fitEquipment(item, at: slot, expectedRevision: inventory.revision)
        return .init(
          label: "Fit", detail: "Destination: " + inventorySlotLabel(slot),
          command: command(.fit(item, slot)))
      case .recovered(let lot):
        guard commander.salvageLedger.inventory.contains(lot),
          case .technology(let id, _, _) = lot.content,
          let definition = SalvageDefinitions.definition(id: id),
          case .scalar(let axes) = definition.effect
        else { return .init(label: "", detail: "No ordinary compatible fitting", command: nil) }
        let choices = axes.compactMap {
          axis -> (SalvageUpgradeAxis, ComponentFittingSlot, SalvageComponentUpgradeQuote)? in
          guard let slot = SalvageComponentEffects.fittingSlot(for: axis),
            let effect = try? commander.previewRecoveredUpgrade(
              lot: lot.identity, axis: axis, slot: slot)
          else { return nil }
          return (axis, slot, effect)
        }
        guard !choices.isEmpty else {
          return .init(label: "", detail: "No ordinary compatible fitting", command: nil)
        }
        let (axis, slot, effect) = choices[max(0, inventoryUpgradeChoice) % choices.count]
        guard let item = commander.fittedEquipment(at: slot) else {
          throw RecoveredEquipmentError.missingComponent
        }
        let details = effect.progression.absoluteEffects.keys.sorted { $0.rawValue < $1.rawValue }
          .map { key in
            inventoryStatChange(
              key, before: effect.progression.before[key]!, after: effect.progression.after[key]!)
          }.joined(separator: ", ")
        return .init(
          label: "Fit now", detail: inventoryAxisLabel(axis) + ": " + details,
          command: command(
            .upgrade(
              item, lot, axis, slot, before: effect.progression.before,
              after: effect.progression.after, grade: effect.progression.resultingGrade),
            source: commander.salvageLedger.revision))
      }
    } catch {
      return .init(label: "", detail: "Fitting unavailable with current resources", command: nil)
    }
  }

  @discardableResult
  public mutating func performInventoryCommand(_ command: InventoryCommand) -> Bool {
    guard screen == .inventory, let inventory = commander.equipmentInventory,
      inventoryContextEpoch == command.context,
      commander.shipID == command.shipID,
      inventory.owner == command.owner, inventory.activeHull == command.hull,
      inventory.revision == command.ownedRevision
    else {
      notify("FITTING CHANGED - REFRESH INVENTORY")
      return false
    }
    var candidate = self
    do {
      switch command.action {
      case .fit(let item, let slot):
        try candidate.fitEquipment(item, at: slot, expectedRevision: command.ownedRevision)
        candidate.notify("EQUIPMENT FITTED")
      case .store(let item):
        guard inventoryMayStore(item) else { throw EquipmentRuntimeError.incompatibleFit }
        try candidate.storeEquipment(item, expectedRevision: command.ownedRevision)
        candidate.notify("EQUIPMENT STORED")
      case .upgrade(let item, let lot, let axis, let slot, let before, let after, let grade):
        guard candidate.commander.salvageLedger.revision == command.sourceRevision,
          candidate.commander.salvageLedger.inventory.contains(lot),
          candidate.commander.fittedEquipment(at: slot) == item
        else { throw RecoveredEquipmentError.staleQuote }
        let quote = try candidate.commander.quoteRecoveredUpgrade(
          lot: lot.identity, axis: axis, slot: slot)
        guard quote.effect.progression.before == before, quote.effect.progression.after == after,
          quote.effect.progression.resultingGrade == grade
        else { throw RecoveredEquipmentError.staleQuote }
        try candidate.applyRecoveredUpgrade(quote)
      }
      self = candidate
      return true
    } catch {
      notify("FITTING REFUSED - CHECK CURRENT INVENTORY")
      return false
    }
  }

  private func inventoryFitSlot(_ node: EquipmentNodeID) throws -> ComponentFittingSlot {
    if node.family == EquipmentRuntimeCatalog.laserFamily {
      if equipmentWorkTool {
        guard node.key == LaserKind.mining.equipmentName else { throw EquipmentRuntimeError.noSlot }
        return .utility(.miningLaser)
      }
      return .laser(equipmentMount)
    }
    if node.family == EquipmentRuntimeCatalog.storageFamily {
      guard
        let unit = (0..<FuelStorage.maximumCount).first(where: {
          commander.fittedEquipment(at: .fuelStorage($0)) == nil
        })
      else { throw EquipmentRuntimeError.noSlot }
      return .fuelStorage(unit)
    }
    guard let slot = EquipmentRuntimeCatalog.slot(for: node) else {
      throw EquipmentRuntimeError.noSlot
    }
    return slot
  }
  private func inventoryMayStore(_ item: OwnedEquipmentItem) -> Bool {
    ![ComponentFittingSlot.shield, .energy, .navigation].contains { $0 == item.location?.slot }
  }
  private func inventorySlotLabel(_ slot: ComponentFittingSlot) -> String {
    switch slot {
    case .laser(let mount): mount.label + " laser"
    case .utility(.miningLaser): "Mining work tool"
    case .utility(let utility): utility.rawValue
    case .fuelStorage(let unit): "fuel storage \(unit + 1)"
    case .shield: "shield"
    case .energy: "energy"
    case .navigation: "navigation"
    case .targetingCore: "targeting core"
    case .targetingMining: "Mining module"
    case .targetingSalvage: "Salvage module"
    default: "compatible hull fitting"
    }
  }
  private func inventoryAxisLabel(_ axis: SalvageUpgradeAxis) -> String {
    switch axis {
    case .frontShieldCapacity: "Front shield capacity"
    case .rearShieldCapacity: "Rear shield capacity"
    case .frontShieldRecharge: "Front shield recharge"
    case .rearShieldRecharge: "Rear shield recharge"
    case .energyCapacity: "Energy capacity"
    case .energyRecharge: "Energy recharge"
    case .jumpReach: "Jump reach"
    case .spoolDuration: "Jump spool"
    case .jumpFuelCost: "Jump fuel cost"
    default: "Component statistic"
    }
  }
  private func inventoryStatChange(_ axis: ComponentAxis, before: Double, after: Double) -> String {
    let factor: Double
    let unit: String
    switch axis {
    case .frontShieldCapacity, .rearShieldCapacity:
      factor = commander.nativePerformance.shield
      unit = " units"
    case .frontShieldRecharge, .rearShieldRecharge:
      factor = commander.nativePerformance.shieldRecharge
      unit = " units/s"
    case .energyCapacity:
      factor = commander.nativePerformance.energy
      unit = " units"
    case .energyRecharge:
      factor = commander.nativePerformance.recharge
      unit = " units/s"
    case .jumpSpool:
      factor = commander.nativePerformance.spool
      unit = "s"
    case .jumpFuelCost:
      factor = 100
      unit = "%"
    case .jumpReach:
      factor = 1
      unit = " LY"
    default:
      factor = 1
      unit = ""
    }
    return String(format: "%.4g%@ -> %.4g%@", before * factor, unit, after * factor, unit)
  }
}
