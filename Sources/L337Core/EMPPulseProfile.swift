enum EMPPulseProfileError: Error, Equatable, Sendable {
  case missingEnergySystem, invalidEnergyGrade, invalidReserve, invalidDistance
}

/// Project balance for a future pulse. Resolving this value never authorizes or emits a shot.
struct EMPPulseProfile: Equatable, Sendable {
  let energyStage: Int
  let power: Double
  let range: Double
  let energyCost: Double
  let heatCost: Double
  let cooldown: Double
  let warmup: Double
  let splashRadius: Double

  private init(energyStage: Int) {
    let factor = 1 + 0.5 * Double(energyStage)
    self.energyStage = energyStage
    power = 32 * factor
    range = 3000 * factor
    energyCost = 8
    heatCost = 18
    cooldown = 1.5
    warmup = 10
    splashRadius = range / 3
  }

  /// Callers prepare/migrate equipment at their existing mutation boundary, never in this reader.
  static func resolve(for commander: Commander) throws -> Self {
    try commander.validateEquipmentState()
    guard let fitted = commander.fittedEquipment(at: .energy),
      fitted.node.family == EquipmentPurchaseCatalog.energy,
      let component = fitted.component
    else { throw EMPPulseProfileError.missingEnergySystem }
    let definition = EquipmentModuleTemplates.energy
    try ComponentProgression.validateLoaded(component, definition: definition)
    guard let grade = definition.grades.first(where: { $0.identity == component.grade }),
      (0...3).contains(grade.order)
    else { throw EMPPulseProfileError.invalidEnergyGrade }
    guard let modules = commander.fittedAlienEnergyModuleCount else {
      throw EMPPulseProfileError.invalidEnergyGrade
    }
    let stage = grade.order.addingReportingOverflow(modules)
    guard !stage.overflow else { throw EMPPulseProfileError.invalidEnergyGrade }
    return Self(energyStage: stage.partialValue)
  }

  func primaryDrain(remainingReserve: Double) throws -> Double {
    guard remainingReserve.isFinite, remainingReserve >= 0 else {
      throw EMPPulseProfileError.invalidReserve
    }
    return min(remainingReserve, power)
  }

  /// Distance is supplied from the actual target-centred release geometry by the future producer.
  func splashDrain(distance: Double, remainingReserve: Double) throws -> Double {
    guard distance.isFinite, distance >= 0 else { throw EMPPulseProfileError.invalidDistance }
    let full = try primaryDrain(remainingReserve: remainingReserve)
    // Attenuate pulse power before clipping to the remaining reserve.
    return min(full, power * max(0, 1 - distance / splashRadius))
  }
}
