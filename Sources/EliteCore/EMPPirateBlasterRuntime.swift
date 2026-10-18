import Foundation

extension Game {
  static let empRange = 3000.0
  static let empEnergyCost = 8.0
  static let empHeatCost = 18.0
  static let empCooldown = 1.5

  func isEMPDisabled(_ body: SpaceBody) -> Bool {
    guard let source = body.physical?.empSource,
      let record = commander.savedEMPState?.records[source]
    else { return false }
    return !record.terminal && !record.isRecovered && record.hull.binding == body.physical?.identity
  }

  func empTargetStatus(_ body: SpaceBody) -> String? {
    if body.physical?.empCrewPod != nil {
      guard let context = gameplayContext(), let pod = nativePodFacts(body, context: context) else {
        return "OCCUPIED ESCAPE POD - PROTECTED"
      }
      if !hasNativeRescueTools { return "OCCUPIED POD - FIT SALVAGE MODULE AND FUEL SCOOPS" }
      return pod.fits ? "OCCUPIED POD - SINGLE 1T RESCUE UNIT" : "OCCUPIED POD - REAL HOLD FULL"
    }
    guard let source = body.physical?.empSource,
      let record = commander.savedEMPState?.records[source], isEMPDisabled(body)
    else { return nil }
    if record.crewAboard > 0 {
      let inWindow =
        record.crewDeadline.map { commander.flightSimulation.physicalTime < $0 } ?? false
      return inWindow
        ? "DISABLED - \(record.crewAboard) CREW ABOARD / CUTTER CAPTURE"
        : "CREW RECOVERY DEADLINE - CAPTURE CLOSED"
    }
    if let profile = salvageProfile(for: body),
      profile.sections.allSatisfy({
        salvageSectionIsDepleted(.init(wreck: record.wreck, section: $0.index))
      })
    {
      return "ENGINES AND WEAPONS DISABLED - SALVAGE EXHAUSTED"
    }
    return "ENGINES AND WEAPONS DISABLED - UNOCCUPIED SALVAGE"
  }

}
