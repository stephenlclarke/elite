import Foundation

public enum SalvageComponentEffectError: Error, Equatable, Sendable {
  case missingStoredItem, missingComponent, invalidBinding, locationMismatch
  case componentMismatch, originMismatch, unsupportedEffect, incompatibleFamily
}

/// G1 must recheck live occupancy and publish progression plus lot consumption atomically.
public struct SalvageComponentUpgradeQuote: Sendable {
  public let binding: SalvageTransactionBinding
  public let item: ComponentUpgrade
  public let definition: ComponentFamilyDefinition
  public let progression: ComponentUpgradeQuote
}

/// Converts recovered deltas into the shared component engine's declared units.
/// No equipment, resource level, fuel, cash or installation entitlement is changed here.
public enum SalvageComponentEffects {
  public static func quote(
    lotID: SalvageLotIdentity, ledger: SalvageLedger,
    component: ComponentInstance?, liveLocation: ComponentFittingLocation?,
    binding: SalvageTransactionBinding
  ) throws -> SalvageComponentUpgradeQuote {
    guard let lot = ledger.inventory.first(where: { $0.identity == lotID }) else {
      throw SalvageComponentEffectError.missingStoredItem
    }
    guard let component else { throw SalvageComponentEffectError.missingComponent }
    guard
      case .equipment(
        let target, let expected, let version, let axis, let feature, let quotedLocation) = binding,
      feature == nil, let axis, version > 0
    else {
      throw SalvageComponentEffectError.invalidBinding
    }
    guard let quotedLocation, let liveLocation, quotedLocation == liveLocation,
      liveLocation.slot.valid
    else { throw SalvageComponentEffectError.locationMismatch }
    guard expected == component.id else { throw SalvageComponentEffectError.componentMismatch }
    guard Int(version) == component.origin.identity.version else {
      throw SalvageComponentEffectError.originMismatch
    }
    switch target {
    case .hull(let hull):
      guard hull == liveLocation.hullInstanceID else {
        throw SalvageComponentEffectError.locationMismatch
      }
    case .laser: throw SalvageComponentEffectError.incompatibleFamily
    case .commanderResearch: throw SalvageComponentEffectError.invalidBinding
    }
    guard case .technology(let id, let quality, _) = lot.content,
      let definition = SalvageDefinitions.definition(id: id),
      case .scalar(let axes) = definition.effect,
      axes.contains(axis)
    else { throw SalvageComponentEffectError.unsupportedEffect }
    guard hasCoherentFixedEffect(lot, axis: axis) else {
      throw SalvageComponentEffectError.unsupportedEffect
    }
    guard let mapping = mapping(axis), liveLocation.slot == mapping.slot else {
      throw SalvageComponentEffectError.unsupportedEffect
    }
    guard component.family == mapping.family,
      let family = EquipmentModuleTemplates.definitions.first(where: { $0.family == mapping.family }
      )
    else { throw SalvageComponentEffectError.incompatibleFamily }
    let item = ComponentUpgrade(
      identity: .salvage(lot.identity), boundComponent: component.id,
      origin: component.origin.identity, basisPoints: [mapping.axis: quality.bonusBasisPoints])
    let progression = try ComponentProgression.quote(
      component: component, item: item,
      definition: family, inventoryRevision: ledger.revision)
    return .init(binding: binding, item: item, definition: family, progression: progression)
  }

  /// Legacy unselected items remain usable; rolled items retain their exact serial and effect.
  static func hasCoherentFixedEffect(_ lot: SalvageLot, axis: SalvageUpgradeAxis) -> Bool {
    guard case .technology(let id, let quality, let condition) = lot.content else { return false }
    guard let fixed = lot.loot else { return true }
    guard fixed.identity == lot.identity,
      case .technology(let fixedID, let fixedQuality, let fixedCondition, let fixedAxis) = fixed
        .content
    else { return false }
    return fixedID == id && fixedQuality == quality && fixedCondition == condition
      && fixedAxis == axis && fixed.effect == .scalar(axes: [axis])
      && fixed.bonusBasisPoints == quality.bonusBasisPoints
  }

  private static func mapping(_ axis: SalvageUpgradeAxis)
    -> (family: ComponentFamily, axis: ComponentAxis, slot: ComponentFittingSlot)?
  {
    switch axis {
    case .energyCapacity: (EquipmentModuleTemplates.energyFamily, .energyCapacity, .energy)
    case .energyRecharge: (EquipmentModuleTemplates.energyFamily, .energyRecharge, .energy)
    case .spoolDuration: (EquipmentModuleTemplates.navigationFamily, .jumpSpool, .navigation)
    case .jumpFuelCost: (EquipmentModuleTemplates.navigationFamily, .jumpFuelCost, .navigation)
    case .jumpReach: (EquipmentModuleTemplates.navigationFamily, .jumpReach, .navigation)
    case .frontShieldCapacity:
      (EquipmentModuleTemplates.shieldFamily, .frontShieldCapacity, .shield)
    case .rearShieldCapacity: (EquipmentModuleTemplates.shieldFamily, .rearShieldCapacity, .shield)
    case .frontShieldRecharge:
      (EquipmentModuleTemplates.shieldFamily, .frontShieldRecharge, .shield)
    case .rearShieldRecharge: (EquipmentModuleTemplates.shieldFamily, .rearShieldRecharge, .shield)
    default: nil
    }
  }
}
