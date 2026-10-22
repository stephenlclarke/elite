import Foundation

extension NativeWayfarerInductionAction {
  var isClinicCustodyAction: Bool {
    [
      .pickupClinicSample, .receiveClinicSample, .cancelHeldClinicSample, .returnClinicSample,
      .retryClinicExpiry,
    ].contains(self)
  }
  var isInductionAnyBerthAction: Bool {
    [
      .cancelClinicSample, .cancelHeldClinicSample, .retryClinicExpiry, .cancelWorkshopBooking,
      .cancelHeldWorkshopUnit,
    ].contains(self)
  }
}

extension Game {
  var inductionClinicCustodyRows: [ContractBoardRow] {
    var rows: [ContractBoardRow] = []
    for child in commander.scriptState.instances.values.sorted(by: {
      $0.id.uuidString < $1.id.uuidString
    }) {
      guard let contract = child.savedNativeInductionClinic, contract.outcome == .active else {
        continue
      }
      var actions: [NativeWayfarerInductionAction] = []
      if contract.custody == nil {
        if systemIdentity == NativeWayfarerInduction.clinic { actions = [.pickupClinicSample] }
      } else if let custody = contract.custody, custody.end == nil {
        if NativeInductionClinicSave.pendingExpiry(child, engine: commander.scriptState) != nil {
          actions = [.retryClinicExpiry]
        } else {
          if custody.cancellation == nil {
            actions = [.cancelHeldClinicSample]
            if systemIdentity == NativeWayfarerInduction.receiver {
              actions.insert(.receiveClinicSample, at: 0)
            }
          } else if systemIdentity == NativeWayfarerInduction.clinic {
            actions = [.returnClinicSample]
          }
        }
      }
      rows += actions.map { action in
        .init(
          board: action.key, offer: nil,
          title: action.title + " / " + contract.booking.unit.uuidString.prefix(8),
          reason: inductionClinicCustodyIssues(action, instance: child.id).first,
          wayfarerInduction: action, inductionClinicReference: child.id)
      }
    }
    return rows
  }
  func inductionClinicCustodyIssues(_ action: NativeWayfarerInductionAction, instance: UUID?)
    -> [String]
  {
    guard let instance, let child = commander.scriptState.instances[instance],
      let contract = child.savedNativeInductionClinic, contract.outcome == .active,
      nativeInductionClinicPack != nil, NativeInductionCrewLogSave.validateClaims(commander)
    else { return ["Restore the exact original clinic sample, owner and family content."] }
    if action == .retryClinicExpiry {
      return child.suspension != nil
        && NativeInductionClinicSave.pendingExpiry(child, engine: commander.scriptState) != nil
        ? [] : ["Only the original suspended queued integrity expiry may be retried."]
    }
    if action == .pickupClinicSample {
      guard contract.custody == nil, contract.close == nil,
        let occupied = commander.checkedCargoTonnes, occupied <= commander.standardCargoCapacity,
        commander.passengerFit?.allowed == true
      else {
        return ["The reserved original sample and actual hold/fitting must remain available."]
      }
      return []
    }
    do { _ = try inductionClinicHeldChild(instance) } catch {
      return ["Keep the same original sample aboard with positive native integrity time."]
    }
    guard let custody = contract.custody else { return ["Actual pickup is required."] }
    if action == .receiveClinicSample {
      guard custody.cancellation == nil else {
        return ["This delivery was cancelled; return the original to Renas."]
      }
      if commander.credits > 4_294_967_295 - contract.booking.terms.rewardNative {
        return ["Receiving would overflow credits."]
      }
    }
    if action == .cancelHeldClinicSample && custody.cancellation != nil {
      return ["Return is already outstanding."]
    }
    if action == .returnClinicSample && custody.cancellation == nil {
      return ["Separately cancel delivery before returning it to the owner."]
    }
    return []
  }
  func inductionClinicCustodyDetail(_ review: NativeWayfarerInductionReview) -> [String] {
    guard let id = review.clinicReference,
      let contract = commander.scriptState.instances[id]?.savedNativeInductionClinic
    else { return ["Original clinic record unavailable."] }
    var lines = [
      review.action.title.uppercased(), "Original sample: " + contract.booking.unit.uuidString,
      String(
        format: "Frozen quote %.1fCR; %d quoted reachable legs. Fly any reachable route.",
        Double(contract.booking.terms.rewardNative) / 10, contract.booking.route.distancesLY.count),
    ]
    switch review.action {
    case .pickupClinicSample:
      lines += [
        "Confirm moves the same original sample from Renas warehouse to your actual1t hold reservation. No second tonne is needed or created.",
        "The1800 qualifying-flight-second integrity clock starts only now. Pause stops flight time; saves/loading retain its exact deadline. No fuel or teleport is granted.",
      ]
    case .receiveClinicSample:
      lines += [
        "Confirm at actual living Navidor receives the same original sample with positive integrity, pays the frozen quote once, and returns its clinic-owned capacity window. No audit/stage12 or clue is granted."
      ]
    case .cancelHeldClinicSample:
      lines += [
        "Confirm cancels delivery after pickup. Cargo, the original window and integrity clock remain held until actual Renas owner return or recorded terminal failure. No instant release, cash or fresh stock."
      ]
    case .returnClinicSample:
      lines += [
        "Confirm returns the same cancelled original sample at its actual living Renas owner. The window and carried tonne are released once; no cash or success. Returned issued stock is archived, never replenished with a fresh integrity clock."
      ]
    case .retryClinicExpiry:
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
