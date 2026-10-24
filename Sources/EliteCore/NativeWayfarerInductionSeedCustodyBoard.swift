import Foundation

extension NativeWayfarerInductionAction {
  var isSeedCustodyAction: Bool {
    [
      .pickupSeedLot, .receiveSeedLot, .cancelHeldSeedLot, .returnSeedLot,
      .retrySeedExpiry,
    ].contains(self)
  }

}

extension Game {
  var inductionSeedCustodyRows: [ContractBoardRow] {
    var rows: [ContractBoardRow] = []
    for child in commander.scriptState.instances.values.sorted(by: {
      $0.id.uuidString < $1.id.uuidString
    }) {
      guard let contract = child.savedNativeInductionSeed, contract.outcome == .active else {
        continue
      }
      var actions: [NativeWayfarerInductionAction] = []
      if contract.custody == nil {
        if systemIdentity == NativeWayfarerInduction.seedSource { actions = [.pickupSeedLot] }
      } else if let custody = contract.custody, custody.end == nil {
        if NativeInductionSeedSave.pendingExpiry(child, engine: commander.scriptState) != nil {
          actions = [.retrySeedExpiry]
        } else {
          if custody.cancellation == nil {
            actions = [.cancelHeldSeedLot]
            if systemIdentity == NativeWayfarerInduction.seedReceiver {
              actions.insert(.receiveSeedLot, at: 0)
            }
          } else if systemIdentity == NativeWayfarerInduction.seedSource {
            actions = [.returnSeedLot]
          }
        }
      }
      rows += actions.map { action in
        .init(
          board: action.key, offer: nil,
          title: action.title + " / " + contract.booking.unit.uuidString.prefix(8),
          reason: inductionSeedCustodyIssues(action, instance: child.id).first,
          wayfarerInduction: action, inductionSeedReference: child.id)
      }
    }
    return rows
  }
  func inductionSeedCustodyIssues(_ action: NativeWayfarerInductionAction, instance: UUID?)
    -> [String]
  {
    guard let instance, let child = commander.scriptState.instances[instance],
      let contract = child.savedNativeInductionSeed, contract.outcome == .active,
      nativeInductionSeedPack != nil, NativeInductionCrewLogSave.validateClaims(commander)
    else { return ["Restore the exact original seed lot, owner and family content."] }
    if action == .retrySeedExpiry {
      return child.suspension != nil
        && NativeInductionSeedSave.pendingExpiry(child, engine: commander.scriptState) != nil
        ? [] : ["Only the original suspended queued integrity expiry may be retried."]
    }
    if action == .pickupSeedLot {
      guard contract.custody == nil, contract.close == nil,
        let occupied = commander.checkedCargoTonnes, occupied <= commander.standardCargoCapacity,
        commander.passengerFit?.allowed == true
      else {
        return ["The reserved original seed lot and actual hold/fitting must remain available."]
      }
      return []
    }
    do { _ = try inductionSeedHeldChild(instance) } catch {
      return ["Keep the same original seed lot aboard with positive native integrity time."]
    }
    guard let custody = contract.custody else { return ["Actual pickup is required."] }
    if action == .receiveSeedLot {
      guard custody.cancellation == nil else {
        return ["This delivery was cancelled; return the original to Enlirin."]
      }
      if commander.credits > 4_294_967_295 - contract.booking.terms.rewardNative {
        return ["Receiving would overflow credits."]
      }
    }
    if action == .cancelHeldSeedLot && custody.cancellation != nil {
      return ["Return is already outstanding."]
    }
    if action == .returnSeedLot && custody.cancellation == nil {
      return ["Separately cancel delivery before returning it to the owner."]
    }
    return []
  }
  func inductionSeedCustodyDetail(_ review: NativeWayfarerInductionReview) -> [String] {
    guard let id = review.seedReference,
      let contract = commander.scriptState.instances[id]?.savedNativeInductionSeed
    else { return ["Original seed record unavailable."] }
    var lines = [
      review.action.title.uppercased(), "Original seed lot: " + contract.booking.unit.uuidString,
      String(
        format: "Frozen quote %.1fCR; %d quoted reachable legs. Fly any reachable route.",
        Double(contract.booking.terms.rewardNative) / 10, contract.booking.route.distancesLY.count),
    ]
    switch review.action {
    case .pickupSeedLot:
      lines += [
        "Confirm moves the same original seed lot from Enlirin warehouse to your actual3t hold reservation. No additional three tonnes are needed or created.",
        "The7200 qualifying-flight-second integrity clock starts only now. Pause stops flight time; saves/loading retain its exact deadline. No fuel or teleport is granted.",
      ]
    case .receiveSeedLot:
      lines += [
        "Confirm at actual living Lareria receives the same original seed lot with positive integrity, pays the frozen quote once, and returns its seed-owner capacity window. No audit/stage12 or clue is granted."
      ]
    case .cancelHeldSeedLot:
      lines += [
        "Confirm cancels delivery after pickup. Cargo, the original window and integrity clock remain held until actual Enlirin owner return or recorded terminal failure. No instant release, cash or fresh stock."
      ]
    case .returnSeedLot:
      lines += [
        "Confirm returns the same cancelled original seed lot at its actual living Enlirin owner. The window and carried three tonnes are released once; no cash or success. Returned issued stock is archived, never replenished with a fresh integrity clock."
      ]
    case .retrySeedExpiry:
      lines += [
        "Retry the original queued native one-shot expiry after restoring content. No replacement timer or reset allowance. Terminal failure returns the window and releases the expired cargo without restocking or payment."
      ]
    default: break
    }
    if let custody = contract.custody {
      lines.append(
        String(
          format: "Native integrity remaining %.1fs / original deadline %.1f flight seconds.",
          max(0, custody.timer.due - commander.scriptState.flightSeconds), custody.timer.due))
    }
    return lines + ["Back/Escape leaves the original record unchanged."] + review.issues
  }
}
