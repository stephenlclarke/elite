import Foundation

/// Stable family identity, supplied by the authoritative template catalogue.
public struct ComponentFamily: Hashable, Codable, Sendable {
  public let id: String
  public init(_ id: String) { self.id = id }
}

public enum ComponentAxis: String, CaseIterable, Codable, Sendable {
  case frontShieldCapacity, rearShieldCapacity, frontShieldRecharge, rearShieldRecharge
  case energyCapacity, energyRecharge, damage, energyDemand, heat, firingInterval, jumpSpool
  case speed, acceleration, jumpReach, scanPrecision

  public var higherIsBetter: Bool {
    ![.energyDemand, .heat, .firingInterval, .jumpSpool].contains(self)
  }
  fileprivate func valid(_ value: Double) -> Bool {
    value.isFinite && (self == .firingInterval || self == .jumpSpool ? value > 0 : value >= 0)
  }
  fileprivate func meets(_ value: Double, _ threshold: Double) -> Bool {
    let tolerance = max(1, max(abs(value), abs(threshold))) * Double.ulpOfOne * 8
    return higherIsBetter ? value + tolerance >= threshold : value - tolerance <= threshold
  }
  fileprivate func noWorse(_ value: Double, than baseline: Double) -> Bool {
    higherIsBetter ? value >= baseline : value <= baseline
  }
}

public typealias ComponentStatistics = [ComponentAxis: Double]

public struct ComponentTemplateVersion: Hashable, Codable, Sendable {
  public let family: ComponentFamily
  public let id: String
  public let version: Int
  public init(family: ComponentFamily, id: String, version: Int) {
    self.family = family
    self.id = id
    self.version = version
  }
}

public struct ComponentTemplate: Equatable, Codable, Sendable {
  public let identity: ComponentTemplateVersion
  public let order: Int
  public let statistics: ComponentStatistics
  public let requiredAxes: Set<ComponentAxis>
  public let compatibleFeatures: Set<String>
  public init(
    identity: ComponentTemplateVersion, order: Int, statistics: ComponentStatistics,
    requiredAxes: Set<ComponentAxis>, compatibleFeatures: Set<String> = []
  ) {
    self.identity = identity
    self.order = order
    self.statistics = statistics
    self.requiredAxes = requiredAxes
    self.compatibleFeatures = compatibleFeatures
  }
}

/// Directional terminal bounds: benefit maxima and cost minima, in actual native stat units.
public struct ComponentFamilyDefinition: Equatable, Codable, Sendable {
  public let family: ComponentFamily
  public let revision: Int
  public let grades: [ComponentTemplate]
  public let terminalLimits: ComponentStatistics
  /// Historical immutable origins remain verifiable after the active grade table changes.
  public let historicalOrigins: [ComponentTemplate]
  public init(
    family: ComponentFamily, revision: Int, grades: [ComponentTemplate],
    terminalLimits: ComponentStatistics, historicalOrigins: [ComponentTemplate] = []
  ) {
    self.family = family
    self.revision = revision
    self.grades = grades
    self.terminalLimits = terminalLimits
    self.historicalOrigins = historicalOrigins
  }
}

public enum ComponentUpgradeIdentity: Hashable, Codable, Sendable {
  case salvage(SalvageLotIdentity)
  case service(UUID)
}

public struct ComponentUpgrade: Equatable, Codable, Sendable {
  public let identity: ComponentUpgradeIdentity
  public let boundComponent: UUID
  public let origin: ComponentTemplateVersion
  /// Only finite, declared 500/1000/1500-basis-point effects are admitted.
  public let basisPoints: [ComponentAxis: Int]
  public init(
    identity: ComponentUpgradeIdentity, boundComponent: UUID, origin: ComponentTemplateVersion,
    basisPoints: [ComponentAxis: Int]
  ) {
    self.identity = identity
    self.boundComponent = boundComponent
    self.origin = origin
    self.basisPoints = basisPoints
  }
}

public struct ComponentUpgradeReceipt: Equatable, Codable, Sendable {
  public let item: ComponentUpgradeIdentity
  public let component: UUID
  public let origin: ComponentTemplateVersion
  public let appliedAbsoluteEffects: ComponentStatistics
  public let gradeBefore: ComponentTemplateVersion
  public let gradeAfter: ComponentTemplateVersion
}

public struct ComponentInstance: Equatable, Codable, Sendable {
  public let id: UUID
  public let origin: ComponentTemplate
  public let statistics: ComponentStatistics
  public let grade: ComponentTemplateVersion
  public let features: Set<String>
  public let receipts: [ComponentUpgradeReceipt]
  public var family: ComponentFamily { origin.identity.family }
  public init(
    id: UUID, origin: ComponentTemplate, statistics: ComponentStatistics? = nil,
    grade: ComponentTemplateVersion? = nil, features: Set<String> = [],
    receipts: [ComponentUpgradeReceipt] = []
  ) {
    self.id = id
    self.origin = origin
    self.statistics = statistics ?? origin.statistics
    self.grade = grade ?? origin.identity
    self.features = features
    self.receipts = receipts
  }
}

public struct ComponentAxisProgress: Equatable, Sendable {
  public let axis: ComponentAxis
  public let actual: Double
  public let threshold: Double
  public let fulfilled: Bool
  public let fraction: Double
}

public struct ComponentUpgradeQuote: Sendable {
  public let inventoryRevision: UInt64
  public let before: ComponentStatistics
  public let after: ComponentStatistics
  public let absoluteEffects: ComponentStatistics
  public let promotions: [ComponentTemplateVersion]
  public let resultingGrade: ComponentTemplateVersion
  public let nextGrade: ComponentTemplateVersion?
  public let progress: [ComponentAxisProgress]
  fileprivate let expected: ComponentInstance
  fileprivate let item: ComponentUpgrade
  fileprivate let definition: ComponentFamilyDefinition
  fileprivate let planned: ComponentInstance
}

public struct ComponentUpgradeApplication: Sendable {
  public let component: ComponentInstance
  public let consumedItem: ComponentUpgradeIdentity
  public let expectedInventoryRevision: UInt64
}

public enum ComponentProgressionError: Error, Equatable, Sendable {
  case invalidDefinition, invalidInstance, incompatibleFamily, wrongComponent, originMismatch
  case invalidEffect, replayedItem, noEffectiveChange, staleQuote, inventoryChanged
}

/// Does not own inventory, cash, purchase receipts, module entitlements or runtime resource levels.
/// The caller must atomically commit this result and consume the actual G2 inventory item using
/// the pinned inventory revision. G2's ledger is the sole cross-instance consumption authority.
public enum ComponentProgression {
  public static func quote(
    component: ComponentInstance, item: ComponentUpgrade, definition: ComponentFamilyDefinition,
    inventoryRevision: UInt64
  ) throws -> ComponentUpgradeQuote {
    let grades = try validate(definition)
    let index = try validate(component, item: item, definition: definition, grades: grades)
    let (statistics, effects) = try improved(
      component, item: item, limits: definition.terminalLimits)
    var finalIndex = index
    while finalIndex + 1 < grades.count && meets(statistics, template: grades[finalIndex + 1]) {
      finalIndex += 1
    }
    let final = grades[finalIndex]
    let promotions = grades[(index + 1)..<(finalIndex + 1)].map(\.identity)
    let receipt = ComponentUpgradeReceipt(
      item: item.identity, component: component.id, origin: component.origin.identity,
      appliedAbsoluteEffects: effects, gradeBefore: component.grade, gradeAfter: final.identity)
    let planned = ComponentInstance(
      id: component.id, origin: component.origin, statistics: statistics, grade: final.identity,
      features: component.features, receipts: component.receipts + [receipt])
    let next = finalIndex + 1 < grades.count ? grades[finalIndex + 1] : nil
    let thresholds = next?.statistics ?? definition.terminalLimits
    let axes = next?.requiredAxes ?? Set(thresholds.keys)
    let progress = ComponentAxis.allCases.filter(axes.contains).map { axis in
      let actual = statistics[axis]!
      let threshold = thresholds[axis]!
      let base = final.statistics[axis]!
      let fulfilled = axis.meets(actual, threshold)
      let span = axis.higherIsBetter ? threshold - base : base - threshold
      let distance = axis.higherIsBetter ? actual - base : base - actual
      let fraction: Double
      if fulfilled {
        fraction = 1
      } else if span > 0 {
        fraction = max(0, min(1, distance / span))
      } else {
        fraction = 0
      }
      return ComponentAxisProgress(
        axis: axis, actual: actual, threshold: threshold, fulfilled: fulfilled, fraction: fraction)
    }
    return .init(
      inventoryRevision: inventoryRevision, before: component.statistics, after: statistics,
      absoluteEffects: effects, promotions: promotions, resultingGrade: final.identity,
      nextGrade: next?.identity, progress: progress, expected: component, item: item,
      definition: definition, planned: planned)
  }

  public static func apply(
    _ quote: ComponentUpgradeQuote, component: ComponentInstance, item: ComponentUpgrade,
    definition: ComponentFamilyDefinition, inventoryRevision: UInt64
  ) throws -> ComponentUpgradeApplication {
    guard !component.receipts.contains(where: { $0.item == item.identity }) else {
      throw ComponentProgressionError.replayedItem
    }
    guard inventoryRevision == quote.inventoryRevision else {
      throw ComponentProgressionError.inventoryChanged
    }
    guard component == quote.expected, item == quote.item, definition == quote.definition else {
      throw ComponentProgressionError.staleQuote
    }
    let checked = try Self.quote(
      component: component, item: item, definition: definition, inventoryRevision: inventoryRevision
    )
    guard checked.planned == quote.planned else { throw ComponentProgressionError.staleQuote }
    return .init(
      component: checked.planned, consumedItem: item.identity,
      expectedInventoryRevision: inventoryRevision)
  }

  private static func validate(_ definition: ComponentFamilyDefinition) throws
    -> [ComponentTemplate]
  {
    let grades = definition.grades.sorted { $0.order < $1.order }
    guard !definition.family.id.isEmpty, definition.revision > 0, !grades.isEmpty,
      grades.count <= 64,
      definition.historicalOrigins.count <= 1024, let first = grades.first,
      !first.requiredAxes.isEmpty, first.requiredAxes.isSubset(of: Set(first.statistics.keys)),
      Set(definition.terminalLimits.keys) == Set(first.statistics.keys),
      valid(definition.terminalLimits),
      Set(grades.map(\.order)).count == grades.count,
      Set(grades.map(\.identity)).count == grades.count
    else { throw ComponentProgressionError.invalidDefinition }
    var versions: [ComponentTemplateVersion: ComponentTemplate] = [:]
    for template in grades + definition.historicalOrigins {
      guard template.identity.family == definition.family, !template.identity.id.isEmpty,
        template.identity.version > 0, template.order >= 0, valid(template.statistics),
        Set(template.statistics.keys) == Set(first.statistics.keys),
        !template.requiredAxes.isEmpty,
        template.requiredAxes.isSubset(of: Set(template.statistics.keys)),
        versions[template.identity].map({ $0 == template }) ?? true
      else { throw ComponentProgressionError.invalidDefinition }
      versions[template.identity] = template
    }
    for template in grades {
      guard template.requiredAxes == first.requiredAxes,
        template.statistics.allSatisfy({ axis, value in
          axis.noWorse(definition.terminalLimits[axis]!, than: value)
        })
      else { throw ComponentProgressionError.invalidDefinition }
    }
    for (previous, next) in zip(grades, grades.dropFirst()) {
      guard previous.compatibleFeatures.isSubset(of: next.compatibleFeatures),
        first.requiredAxes.allSatisfy({
          $0.noWorse(next.statistics[$0]!, than: previous.statistics[$0]!)
        }),
        first.requiredAxes.contains(where: { next.statistics[$0] != previous.statistics[$0] })
      else { throw ComponentProgressionError.invalidDefinition }
    }
    return grades
  }

  private static func validate(
    _ component: ComponentInstance, item: ComponentUpgrade, definition: ComponentFamilyDefinition,
    grades: [ComponentTemplate]
  ) throws -> Int {
    guard component.family == definition.family, item.origin.family == component.family else {
      throw ComponentProgressionError.incompatibleFamily
    }
    guard component.id == item.boundComponent else {
      throw ComponentProgressionError.wrongComponent
    }
    guard item.origin == component.origin.identity,
      (grades + definition.historicalOrigins).contains(component.origin)
    else { throw ComponentProgressionError.originMismatch }
    guard !component.receipts.contains(where: { $0.item == item.identity }) else {
      throw ComponentProgressionError.replayedItem
    }
    guard valid(component.statistics),
      Set(component.statistics.keys) == Set(component.origin.statistics.keys),
      let index = grades.firstIndex(where: { $0.identity == component.grade }),
      component.features.isSubset(of: grades[index].compatibleFeatures),
      meets(component.statistics, template: grades[index]),
      Set(component.receipts.map(\.item)).count == component.receipts.count,
      component.receipts.allSatisfy({
        $0.component == component.id && $0.origin == component.origin.identity
      })
    else { throw ComponentProgressionError.invalidInstance }
    guard !item.basisPoints.isEmpty,
      item.basisPoints.allSatisfy({ axis, points in
        component.origin.statistics[axis] != nil && [500, 1000, 1500].contains(points)
      })
    else { throw ComponentProgressionError.invalidEffect }
    return index
  }

  private static func improved(
    _ component: ComponentInstance, item: ComponentUpgrade, limits: ComponentStatistics
  ) throws -> (ComponentStatistics, ComponentStatistics) {
    var statistics = component.statistics
    var effects: ComponentStatistics = [:]
    for axis in ComponentAxis.allCases {
      guard let points = item.basisPoints[axis] else { continue }
      let original = component.origin.statistics[axis]!
      let current = statistics[axis]!
      let limit = limits[axis]!
      let magnitude = original * (Double(points) / 10_000)
      let headroom = axis.higherIsBetter ? limit - current : current - limit
      let applied = min(magnitude, max(0, headroom))
      let value =
        axis.higherIsBetter ? min(limit, current + applied) : max(limit, current - applied)
      // A grandfathered value beyond the terminal bound is retained exactly.
      let next = headroom <= 0 ? current : value
      guard axis.valid(next) else { throw ComponentProgressionError.invalidEffect }
      statistics[axis] = next
      effects[axis] = next - current
    }
    guard effects.values.contains(where: { $0 != 0 }) else {
      throw ComponentProgressionError.noEffectiveChange
    }
    return (statistics, effects)
  }

  private static func valid(_ statistics: ComponentStatistics) -> Bool {
    !statistics.isEmpty && statistics.allSatisfy { $0.key.valid($0.value) }
  }
  private static func meets(_ statistics: ComponentStatistics, template: ComponentTemplate) -> Bool
  {
    template.requiredAxes.allSatisfy { axis in
      statistics[axis].map { axis.meets($0, template.statistics[axis]!) } ?? false
    }
  }
}
