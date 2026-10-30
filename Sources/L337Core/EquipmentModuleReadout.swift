import Foundation

/// Presentation of the same immutable template and fitted statistics consumed by native mechanics.
enum EquipmentModuleReadout {
  static func supports(_ node: EquipmentNodeID) -> Bool {
    [
      EquipmentPurchaseCatalog.shields, EquipmentPurchaseCatalog.energy,
      EquipmentPurchaseCatalog.navigation,
    ].contains(node.family)
  }

  static func lines(node: EquipmentNodeID, fitted: ComponentInstance?) -> [String] {
    guard supports(node), let family = EquipmentRuntimeCatalog.definition(for: node.family),
      let baseline = family.grades.min(by: { $0.order < $1.order }),
      let stock = EquipmentRuntimeCatalog.stockComponent(
        for: node, id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)))
    else { return [] }
    let offered = summary(stock.statistics, family: family.family, baseline: baseline.statistics)
    let installed: String
    if let fitted, fitted.family == family.family {
      installed = summary(fitted.statistics, family: family.family, baseline: baseline.statistics)
    } else {
      installed = "none"
    }
    return ["Offer % Basic: " + offered, "Fitted % Basic: " + installed]
  }

  static func percentage(_ value: Double?, baseline: Double?) -> String {
    guard let value, let baseline, value.isFinite, value >= 0,
      baseline.isFinite, baseline > 0
    else { return "?" }
    let ratio = value / baseline * 100
    guard ratio.isFinite, ratio <= 1_000_000 else { return "?" }
    let format = abs(ratio - ratio.rounded()) < 1e-8 ? "%.0f" : "%.1f"
    return String(format: format, locale: Locale(identifier: "en_US_POSIX"), ratio)
  }

  static func summary(
    _ values: ComponentStatistics, family: ComponentFamily, baseline: ComponentStatistics
  ) -> String {
    func percent(_ axis: ComponentAxis) -> String {
      percentage(values[axis], baseline: baseline[axis]) + "%"
    }
    if family == EquipmentModuleTemplates.shieldFamily {
      return "cap F/R " + percent(.frontShieldCapacity) + "/" + percent(.rearShieldCapacity)
        + "; regen F/R " + percent(.frontShieldRecharge) + "/" + percent(.rearShieldRecharge)
    }
    if family == EquipmentModuleTemplates.energyFamily {
      return "capacity " + percent(.energyCapacity) + "; recharge " + percent(.energyRecharge)
    }
    if family == EquipmentModuleTemplates.navigationFamily {
      return "reach " + percent(.jumpReach) + "; time " + percent(.jumpSpool)
        + "; fuel " + percent(.jumpFuelCost)
    }
    return "unavailable"
  }
}
