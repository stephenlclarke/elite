import Foundation

enum TargetColourCue: Sendable, Equatable {
  case hostile, wanted, recoverable, ordinary
  var ink: Ink? {
    switch self {
    case .hostile: .red
    case .wanted: .purple
    case .recoverable: .orange
    case .ordinary: nil
    }
  }
}

extension Game {
  /// One tool-independent authority for scanner, target details and world cues.
  func targetColourCue(for body: SpaceBody, context supplied: EncounterContext? = nil)
    -> TargetColourCue
  {
    guard body.energy.isFinite, body.energy > 0 else { return .ordinary }
    if let context = supplied ?? gameplayContext(),
      inductionCrewLogFacts(body) != nil
        || recordRecoveryFacts(body, context: context) != nil
        || identifiedSalvageFacts(body, context: context) != nil
    {
      return .recoverable
    }
    if let context = supplied ?? gameplayContext(),
      originalRescueFacts(body, context: context) != nil
    {
      return .recoverable
    }
    if body.physical?.empCrewPod != nil,
      let context = supplied ?? gameplayContext(), nativePodFacts(body, context: context) != nil
    {
      return .recoverable
    }
    if isEMPDisabled(body) { return .recoverable }
    if body.hull == .missile || body.physical?.ordnance != nil {
      return body.hostile || body.enemyMissile ? .hostile : .ordinary
    }
    if body.physical?.npc == nil || body.physical?.salvage != nil {
      if hasRecoverableColour(body, context: supplied) { return .recoverable }
    }
    if wantedRank(for: body) != nil { return .wanted }
    return body.hostile ? .hostile : .ordinary
  }

  private func hasRecoverableColour(_ body: SpaceBody, context supplied: EncounterContext?) -> Bool
  {
    guard let context = supplied ?? gameplayContext(),
      let metadata = recoverableMetadata(for: body, context: context),
      metadata.ownership == .abandoned, metadata.claimant == nil,
      !context.protection.protectedActors.contains(
        body.physical?.identity ?? context.player.identity)
    else { return false }
    switch metadata.category {
    case .rock:
      guard let identity = body.physical?.rock,
        let rock = miningFields.lazy.flatMap(\.rocks).first(where: { $0.identity == identity }),
        commander.miningLedger.remainingEnergy(for: rock) > 0
      else { return false }
      return true
    case .wreck, .section:
      guard let id = body.physical?.catalogueShipID,
        SalvageCatalogue.eligibility(
          catalogueShipID: id, ownership: metadata.ownership,
          activeStation: body.hull == .station && body.id == 0) == .allowed,
        let wreck = metadata.wreck, !commander.salvageLedger.isWreckDestroyed(wreck)
      else { return false }
      return true
    case .cargo, .technology, .module, .disabledDrone, .emptyPod: return true
    case .occupiedPod: return false
    }
  }
}
