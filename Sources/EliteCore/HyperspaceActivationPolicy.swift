import Foundation

/// Immediate travel is an explicit branch, never a zero or epsilon timed spool.
public enum HyperspaceActivation: Equatable, Sendable {
  case timed(seconds: Double)
  case immediate
}

public enum HyperspaceDrivePolicyError: Error, Equatable {
  case invalidNavigationMultiplier, invalidActivationSeconds, invalidMassLockDistance
}

public struct HyperspaceDrivePolicy: Equatable, Sendable {
  public let activation: HyperspaceActivation
  public let massLockScale: Double
  private init(activation: HyperspaceActivation, massLockScale: Double) {
    self.activation = activation
    self.massLockScale = massLockScale
  }
  /// The caller supplies only its actual fitted drive, plus the resolved navigation ratio once.
  /// nil describes stock Basic policy; it never mints an owned Basic device or receipt.
  public static func normal(
    component: ComponentInstance?, navigationSpoolMultiplier: Double
  ) throws -> Self {
    guard navigationSpoolMultiplier.isFinite, navigationSpoolMultiplier > 0 else {
      throw HyperspaceDrivePolicyError.invalidNavigationMultiplier
    }
    let tier: HyperspaceDriveTier
    let seconds: Double
    if let component {
      try ComponentProgression.validateLoaded(
        component, definition: HyperspaceDriveDefinition.componentDefinition)
      guard
        let resolved = HyperspaceDriveTier.allCases.first(where: {
          HyperspaceDriveDefinition.template(for: $0).identity == component.grade
        }), let value = component.statistics[.jumpSpool],
        value >= HyperspaceDriveDefinition.minimumOrdinarySeconds
      else { throw HyperspaceDrivePolicyError.invalidActivationSeconds }
      tier = resolved
      seconds = value
    } else {
      tier = .basic
      seconds = tier.activationSeconds
    }
    let effective = seconds * navigationSpoolMultiplier
    guard effective.isFinite, effective > 0, effective <= 1e12 else {
      throw HyperspaceDrivePolicyError.invalidActivationSeconds
    }
    return .init(activation: .timed(seconds: effective), massLockScale: tier.massLockScale)
  }
  /// Pure capability description. Only the central actor can authorize this from an actual
  /// salvaged owned alien drive fitted with authenticated PLUGH docking evidence.
  public static let alienFoundation = Self(activation: .immediate, massLockScale: 0)

  /// Pure declared NPC policy. NativeNPCDriveSource must authenticate the live fitted component;
  /// these values alone never authorize an actor, opening, fuel debit or journey.
  static func authoredNPC(_ drive: ScriptNPCDriveDefinition) throws -> Self {
    guard drive.valid else { throw HyperspaceDrivePolicyError.invalidActivationSeconds }
    return .init(
      activation: .timed(seconds: drive.activationSeconds), massLockScale: drive.massLockScale)
  }

  public func massLockDistance(base: Double) throws -> Double {
    guard base.isFinite, base >= 0 else {
      throw HyperspaceDrivePolicyError.invalidMassLockDistance
    }
    let distance = base * massLockScale
    guard distance.isFinite else { throw HyperspaceDrivePolicyError.invalidMassLockDistance }
    return distance
  }
}
