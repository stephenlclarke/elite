import Foundation

enum NativeMissionAdjudication: Sendable, Equatable {
  case unknown, currentVisit, frozenLaunch
}

/// Actual effect facts for MC1's once-only event projection. This is not an authority input.
/// Only the native damage kernel in this file constructs receipts after applying an effect.
struct NativeMissionImpactReceipt: Sendable {
  let kind: AttackKind
  let target: GameplayHitTarget?
  let victimPart: String?
  let victimComponentID: UUID?
  let damage: Double
  let hullDestroyed: Bool
  let componentDestroyed: Bool
  let eventID: UInt64?
  let sourceInstanceID: UUID
  let sourceActorID: UUID
  let sourceComponentID: UUID?
  let targetMissionInstanceID: UUID?
  let targetMissionActorID: UUID?
  let originalOrigin: AttackOrigin?
  let adjudication: NativeMissionAdjudication
  let terminalShotID: UUID?
  var targetBodyID: Int? {
    if case .body(let id) = target { return id }
    return nil
  }

  fileprivate init(
    kind: AttackKind, target: GameplayHitTarget?, victimPart: String?, victimComponentID: UUID?,
    damage: Double, hullDestroyed: Bool, componentDestroyed: Bool, eventID: UInt64?,
    sourceInstanceID: UUID, sourceActorID: UUID, sourceComponentID: UUID?,
    targetMissionInstanceID: UUID?, targetMissionActorID: UUID?, originalOrigin: AttackOrigin?,
    adjudication: NativeMissionAdjudication, terminalShotID: UUID?
  ) {
    self.kind = kind
    self.target = target
    self.victimPart = victimPart
    self.victimComponentID = victimComponentID
    self.damage = damage
    self.hullDestroyed = hullDestroyed
    self.componentDestroyed = componentDestroyed
    self.eventID = eventID
    self.sourceInstanceID = sourceInstanceID
    self.sourceActorID = sourceActorID
    self.sourceComponentID = sourceComponentID
    self.targetMissionInstanceID = targetMissionInstanceID
    self.targetMissionActorID = targetMissionActorID
    self.originalOrigin = originalOrigin
    self.adjudication = adjudication
    self.terminalShotID = terminalShotID
  }
}
