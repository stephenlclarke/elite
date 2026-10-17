/// Stock device values use immutable hull-native ratios, except navigation reach in LY.
/// These definitions describe components; they do not grant equipment or purchase receipts.
public enum EquipmentModuleTemplates {
  public static let shieldFamily = ComponentFamily("shield")
  public static let navigationFamily = ComponentFamily("navigation")
  public static let energyFamily = ComponentFamily("energy")

  private static let shieldAxes: Set<ComponentAxis> = [
    .frontShieldCapacity, .rearShieldCapacity, .frontShieldRecharge, .rearShieldRecharge,
  ]
  private static let shieldIDs = [
    "basic", "basicII", "intermediate", "intermediateII", "advanced", "advancedII", "elite",
  ]
  private static let shieldNames = [
    "Basic", "Basic II", "Intermediate", "Intermediate II", "Advanced", "Advanced II", "Elite",
  ]

  public static let shield: ComponentFamilyDefinition = {
    let capacities = [1.0, 1.5, 1.8, 2.0, 2.3, 6.9, 9.2]
    let legacy = [
      ("pulse", 1.5), ("mining", 5.0), ("beam", 1.5), ("military", 2.3),
      ("capital", 6.9),
    ]
    return .init(
      family: shieldFamily, revision: 1,
      grades: shieldIDs.enumerated().map { index, id in
        template(
          shieldFamily, id, order: index, statistics: shieldStats(capacities[index]),
          required: shieldAxes)
      },
      terminalLimits: [
        .frontShieldCapacity: 11.96, .rearShieldCapacity: 11.96,
        .frontShieldRecharge: 1.3, .rearShieldRecharge: 1.3,
      ],
      historicalOrigins: legacy.enumerated().map { index, entry in
        template(
          shieldFamily, "legacy." + entry.0, order: index,
          statistics: shieldStats(entry.1), required: shieldAxes)
      })
  }()

  public static let navigation: ComponentFamilyDefinition = .init(
    family: navigationFamily, revision: 1,
    grades: ["basic", "intermediate", "advanced"].enumerated().map { index, id in
      template(
        navigationFamily, id, order: index,
        statistics: [.jumpReach: Double((index + 1) * 7), .jumpSpool: 1, .jumpFuelCost: 1],
        required: [.jumpReach])
    },
    terminalLimits: [.jumpReach: 27.3, .jumpSpool: 0.7, .jumpFuelCost: 0.7])

  public static let energy: ComponentFamilyDefinition = .init(
    family: energyFamily, revision: 1,
    grades: ["basic", "intermediate", "advanced"].enumerated().map { index, id in
      template(
        energyFamily, id, order: index,
        statistics: [.energyCapacity: 1, .energyRecharge: Double(index + 1)],
        required: [.energyRecharge])
    },
    terminalLimits: [.energyCapacity: 1.3, .energyRecharge: 3.9])

  public static let definitions = [shield, navigation, energy]

  /// Saved keys are interpreted in their original namespace, never as new display labels.
  /// Shield mappings retain the immutable old origin separately from its reconciled grade.
  public struct LegacyMapping: Equatable, Sendable {
    public let origin: ComponentTemplate
    public let grade: ComponentTemplateVersion
  }

  public static func legacyMapping(family: ComponentFamily, key: String) -> LegacyMapping? {
    if family == navigationFamily {
      let keys = ["Navigation: Basic", "Navigation: Advanced", "Navigation: Military"]
      guard let index = keys.firstIndex(of: key) else { return nil }
      return mapping(navigation.grades[index])
    }
    if family == energyFamily {
      switch key {
      case "Extra Energy Unit": return mapping(energy.grades[1])
      case "Naval Energy Unit": return mapping(energy.grades[2])
      default: return nil
      }
    }
    guard family == shieldFamily else { return nil }
    if key == "Basic Shield" { return mapping(shield.grades[0]) }
    let keys = ["Pulse", "Mining", "Beam", "Military", "Capital Ship"]
    guard
      let index = keys.firstIndex(where: {
        key == $0 + " Shield Booster" || key == $0 + " Shield Module"
      })
    else { return nil }
    let origin = shield.historicalOrigins[index]
    // Legacy Mining (5x) and Beam (1.5x) keep their strength, not their nominal renamed tier.
    let gradeIndex = [1, 4, 1, 4, 5][index]
    return .init(origin: origin, grade: shield.grades[gradeIndex].identity)
  }

  public static func legacyNavigation(rawValue: Int) -> LegacyMapping? {
    guard (1...3).contains(rawValue) else { return nil }
    return mapping(navigation.grades[rawValue - 1])
  }

  public static func displayName(for identity: ComponentTemplateVersion) -> String? {
    guard let definition = definitions.first(where: { $0.family == identity.family }),
      let index = definition.grades.firstIndex(where: { $0.identity == identity })
    else { return nil }
    return identity.family == shieldFamily
      ? shieldNames[index] : ["Basic", "Intermediate", "Advanced"][index]
  }

  /// Legacy spelling aliases affect presentation only; they never parse saved navigation keys.
  public static func shieldGrade(named name: String) -> ComponentTemplateVersion? {
    let canonical: String
    switch name {
    case "Intermediary": canonical = "Intermediate"
    case "Intermediary II": canonical = "Intermediate II"
    default: canonical = name
    }
    guard let index = shieldNames.firstIndex(of: canonical) else { return nil }
    return shield.grades[index].identity
  }

  private static func mapping(_ template: ComponentTemplate) -> LegacyMapping {
    .init(origin: template, grade: template.identity)
  }

  private static func shieldStats(_ capacity: Double) -> ComponentStatistics {
    [
      .frontShieldCapacity: capacity, .rearShieldCapacity: capacity,
      .frontShieldRecharge: 1, .rearShieldRecharge: 1,
    ]
  }

  private static func template(
    _ family: ComponentFamily, _ id: String, order: Int, statistics: ComponentStatistics,
    required: Set<ComponentAxis>
  ) -> ComponentTemplate {
    .init(
      identity: .init(family: family, id: family.id + "." + id, version: 1),
      order: order, statistics: statistics, requiredAxes: required)
  }
}
