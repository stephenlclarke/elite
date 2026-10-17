import Foundation

/// Ephemeral interaction context, separate from persistent commander and hull identities.
public struct InventoryContextEpoch: Sendable, Equatable {
  private let value: UUID
  init() { value = UUID() }
  /// Reuses the already captured context for discarded fitting previews only.
  /// An actual user mutation allocates its own command once in the Game adapter.
  var planningCommandID: UUID { value }
}

public enum InventorySubject: Sendable, Equatable {
  case equipment(OwnedEquipmentItem)
  case recovered(SalvageLot)
}

public struct InventoryInformationRow: Sendable, Equatable {
  public let text: String
  public let ink: Ink
  public let subject: InventorySubject?
  public let preview: InventoryActionPreview?
  init(
    _ text: String, _ ink: Ink, subject: InventorySubject? = nil,
    preview: InventoryActionPreview? = nil
  ) {
    self.text = text
    self.ink = ink
    self.subject = subject
    self.preview = preview
  }
}

public struct InventoryCommand: Sendable, Equatable {
  enum Action: Sendable, Equatable {
    case fit(OwnedEquipmentItem, ComponentFittingSlot)
    case store(OwnedEquipmentItem)
    case installFeature(SalvageLot, definition: RecoveredFeatureDefinition)
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
  public let extraDetails: [String]
  init(label: String, detail: String, command: InventoryCommand?, extraDetails: [String] = []) {
    self.label = label
    self.detail = detail
    self.command = command
    self.extraDetails = extraDetails
  }
}

public struct InventoryControl: Sendable, Equatable {
  public let bounds: CanvasRect
  public let command: InventoryCommand
}

/// Kept by the native view only after the corresponding frame was successfully painted.
public struct InventoryInteraction: Sendable, Equatable {
  public static let actionWidth = 90.0
  public static let actionGap = 12.0
  public var controls: [InventoryControl] = []
  public var selected = 0
  public init() {}
  public var selectedIndex: Int? {
    guard !controls.isEmpty else { return nil }
    return ((selected % controls.count) + controls.count) % controls.count
  }
  public var primary: InventoryCommand? {
    selectedIndex.map { controls[$0].command }
  }
  public func command(at point: SIMD2<Double>) -> InventoryCommand? {
    controls.first { $0.bounds.contains(ScreenPoint(point.x, point.y)) }?.command
  }
}

extension Game {
  public func inventoryActionPreview(for subject: InventorySubject) -> InventoryActionPreview {
    guard let inventory = commander.equipmentInventory else {
      return .init(label: "", detail: "Ownership must be initialized first", command: nil)
    }
    do {
      switch subject {
      case .equipment(let item): return try inventoryEquipmentPreview(item, inventory: inventory)
      case .recovered(let lot): return try inventoryRecoveredPreview(lot, inventory: inventory)
      }
    } catch {
      return .init(label: "", detail: "Fitting unavailable with current resources", command: nil)
    }
  }

  private func inventoryCommand(
    _ action: InventoryCommand.Action, inventory: OwnedEquipmentInventory, source: UInt64? = nil
  ) -> InventoryCommand {
    .init(
      owner: inventory.owner, hull: inventory.activeHull, context: inventoryContextEpoch,
      shipID: commander.shipID, ownedRevision: inventory.revision, sourceRevision: source,
      action: action)
  }

  private func inventoryEquipmentPreview(
    _ item: OwnedEquipmentItem, inventory: OwnedEquipmentInventory
  ) throws -> InventoryActionPreview {
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
      try projected.storeEquipment(
        item, expectedRevision: inventory.revision,
        command: inventoryContextEpoch.planningCommandID)
      return .init(
        label: "Store", detail: "Keep this device aboard",
        command: inventoryCommand(.store(item), inventory: inventory))
    }
    let slot = try inventoryFitSlot(item.node)
    try projected.fitEquipment(
      item, at: slot, expectedRevision: inventory.revision,
      command: inventoryContextEpoch.planningCommandID)
    return .init(
      label: "Fit", detail: "Destination: " + inventorySlotLabel(slot),
      command: inventoryCommand(.fit(item, slot), inventory: inventory))
  }

  private func inventoryRecoveredPreview(
    _ lot: SalvageLot, inventory: OwnedEquipmentInventory
  ) throws -> InventoryActionPreview {
    guard commander.salvageLedger.inventory.contains(lot),
      case .technology(let id, _, _) = lot.content,
      let definition = SalvageDefinitions.definition(id: id)
    else { return .init(label: "", detail: "No ordinary compatible fitting", command: nil) }
    if case .feature(let feature) = definition.effect {
      return try inventoryRecoveredFeaturePreview(lot, feature: feature, inventory: inventory)
    }
    guard case .scalar(let axes) = definition.effect else {
      return .init(label: "", detail: "No ordinary compatible fitting", command: nil)
    }
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
    let (axis, slot, effect) = choices[
      ((inventoryUpgradeChoice % choices.count) + choices.count) % choices.count]
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
      command: inventoryCommand(
        .upgrade(
          item, lot, axis, slot, before: effect.progression.before,
          after: effect.progression.after, grade: effect.progression.resultingGrade),
        inventory: inventory, source: commander.salvageLedger.revision),
      extraDetails: inventoryUpgradeDetails(effect.progression))
  }

  private func inventoryRecoveredFeaturePreview(
    _ lot: SalvageLot, feature: SalvageFeature, inventory: OwnedEquipmentInventory
  ) throws -> InventoryActionPreview {
    if feature.requiresTargetingCore && commander.targetingTier == nil {
      return .init(label: "", detail: "Fit a targeting computer core first", command: nil)
    }
    let quote = try commander.quoteRecoveredFeature(lot: lot.identity)
    return .init(
      label: "Fit now", detail: "Enable " + inventorySlotLabel(quote.definition.slot),
      command: inventoryCommand(
        .installFeature(lot, definition: quote.definition),
        inventory: inventory, source: commander.salvageLedger.revision),
      extraDetails: ["Fits the selected device; keeps its recovery record"])
  }

  @discardableResult
  public mutating func performInventoryCommand(_ command: InventoryCommand) -> Bool {
    performInventoryMutation(command).applied
  }

  mutating func performInventoryMutation(_ command: InventoryCommand) -> EquipmentMutationResult {
    guard screen == .inventory, !paused, let inventory = commander.equipmentInventory,
      inventoryContextEpoch == command.context,
      commander.shipID == command.shipID,
      inventory.owner == command.owner, inventory.activeHull == command.hull,
      inventory.revision == command.ownedRevision
    else {
      notify("FITTING CHANGED - REFRESH INVENTORY")
      return .refused(.staleContext)
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
      case .installFeature(let lot, let definition):
        guard candidate.commander.salvageLedger.revision == command.sourceRevision,
          candidate.commander.salvageLedger.inventory.contains(lot)
        else { throw RecoveredEquipmentError.staleQuote }
        let quote = try candidate.commander.quoteRecoveredFeature(lot: lot.identity)
        guard quote.definition == definition else {
          throw RecoveredEquipmentError.staleQuote
        }
        try candidate.applyRecoveredFeature(quote)
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
      candidate.inventoryContextEpoch = .init()
      self = candidate
      return .applied(
        .inventory(
          ownedRevision: candidate.commander.equipmentInventory?.revision ?? inventory.revision,
          sourceRevision: candidate.commander.salvageLedger.revision))
    } catch {
      notify("FITTING REFUSED - CHECK CURRENT INVENTORY")
      if error as? RecoveredEquipmentError == .staleQuote
        || error as? RecoveredFeatureError == .staleQuote
        || error as? OwnedEquipmentError == .staleRevision
      {
        return .refused(.staleContext)
      }
      return .refused(.fittingUnavailable)
    }
  }

  private func inventoryFitSlot(_ node: EquipmentNodeID) throws -> ComponentFittingSlot {
    if node == EquipmentRuntimeCatalog.standardMissile {
      guard
        let pylon = (0..<commander.missileCapacity).first(where: {
          commander.fittedEquipment(at: .missilePylon($0)) == nil
        })
      else { throw EquipmentRuntimeError.noSlot }
      return .missilePylon(pylon)
    }
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
    case .utility(let utility):
      switch utility {
      case .miningLaser: "Mining work tool"
      case .salvageCutter: "Salvage Cutter"
      case .empPirateBlaster: Equipment.empPirateBlaster
      case .fuelScoops: "Fuel Scoops"
      case .ecm: "ECM"
      case .escapePod: "Escape Pod"
      case .energyBomb: "Energy Bomb"
      case .cargoExpansion: "Cargo expansion"
      case .galacticHyperdrive: "Galactic Hyperdrive"
      }
    case .fuelStorage(let unit): "fuel storage \(unit + 1)"
    case .missilePylon(let index): "missile pylon \(index + 1)"
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
  private func inventoryUpgradeDetails(_ quote: ComponentUpgradeQuote) -> [String] {
    let grade = EquipmentModuleTemplates.displayName(for: quote.resultingGrade) ?? "Unknown"
    let next =
      quote.nextGrade.flatMap(EquipmentModuleTemplates.displayName)
      .map { "Next " + $0 + " (actual / required)" } ?? "Maximum grade limits (actual / limit)"
    return ["Resulting grade: " + grade, next]
      + quote.progress.map { progress in
        inventoryComponentAxisLabel(progress.axis) + ": "
          + inventoryStatChange(
            progress.axis, before: progress.actual, after: progress.threshold, separator: " / ")
      }
  }
  private func inventoryComponentAxisLabel(_ axis: ComponentAxis) -> String {
    switch axis {
    case .frontShieldCapacity: "Front capacity"
    case .rearShieldCapacity: "Rear capacity"
    case .frontShieldRecharge: "Front recharge"
    case .rearShieldRecharge: "Rear recharge"
    case .energyCapacity: "Energy capacity"
    case .energyRecharge: "Energy recharge"
    case .jumpSpool: "Jump spool"
    case .jumpFuelCost: "Fuel cost"
    case .jumpReach: "Jump reach"
    default: "Statistic"
    }
  }
  private func inventoryStatChange(
    _ axis: ComponentAxis, before: Double, after: Double, separator: String = " -> "
  ) -> String {
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
    return String(format: "%.4g%@%@%.4g%@", before * factor, unit, separator, after * factor, unit)
  }
}
