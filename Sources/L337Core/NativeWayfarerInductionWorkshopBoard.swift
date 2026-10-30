import Foundation

extension NativeWayfarerInductionAction {
  var isWorkshopAction: Bool {
    [
      .issueWorkshopStock, .viewWorkshopStock, .acceptWorkshopUnit, .pickupWorkshopUnit,
      .serviceWorkshopUnit, .receiveWorkshopUnit, .cancelWorkshopBooking, .cancelHeldWorkshopUnit,
      .returnWorkshopUnit,
    ].contains(self)
  }
}

extension Game {
  var inductionWorkshopRows: [ContractBoardRow] {
    var rows: [ContractBoardRow] = []
    func row(_ action: NativeWayfarerInductionAction, reference: UUID? = nil, title: String? = nil)
      -> ContractBoardRow
    {
      .init(
        board: action.key, offer: nil, title: title ?? action.title,
        reason: inductionWorkshopActionIssues(action, reference: reference).first,
        wayfarerInduction: action, inductionWorkshopReference: reference)
    }
    for child in commander.scriptState.instances.values.sorted(by: {
      $0.id.uuidString < $1.id.uuidString
    }) {
      guard let contract = child.savedNativeInductionWorkshop, contract.end == nil else { continue }
      if contract.pickup == nil {
        rows.append(row(.cancelWorkshopBooking, reference: child.id))
        if systemIdentity == NativeWayfarerInduction.workshop {
          rows.append(row(.pickupWorkshopUnit, reference: child.id))
        }
      } else if contract.cancellation != nil {
        if systemIdentity == NativeWayfarerInduction.workshop {
          rows.append(row(.returnWorkshopUnit, reference: child.id))
        }
      } else {
        rows.append(row(.cancelHeldWorkshopUnit, reference: child.id))
        if contract.service == nil && systemIdentity == NativeWayfarerInduction.clinic {
          rows.append(row(.serviceWorkshopUnit, reference: child.id))
        }
        if contract.service != nil && systemIdentity == NativeWayfarerInduction.workshop {
          rows.append(row(.receiveWorkshopUnit, reference: child.id))
        }
      }
    }
    if systemIdentity == NativeWayfarerInduction.workshop,
      let state = wayfarerInductionMission?.savedWayfarerInduction,
      state.charterSignatures?.contains(where: { $0.operatorID == .workshop }) == true
    {
      if let source = state.charterWorkshopSource {
        rows.append(row(.viewWorkshopStock))
        for unit in source.units where unit.status == .available && unit.instance == nil {
          rows.append(
            row(
              .acceptWorkshopUnit, reference: unit.id,
              title: "Reserve original workshop serial " + unit.serial.uuidString.prefix(8)))
        }
      } else {
        rows.append(row(.issueWorkshopStock))
      }
    }
    return rows
  }
  func inductionWorkshopActionIssues(_ action: NativeWayfarerInductionAction, reference: UUID?)
    -> [String]
  {
    if action == .issueWorkshopStock { return inductionWorkshopSourceIssues() }
    if action == .viewWorkshopStock {
      return [
        "Read-only original stock/complete-route quote. Actual booking, pickup, service and owner return use separate rows."
      ]
    }
    if action == .acceptWorkshopUnit { return inductionWorkshopBookingIssues(unit: reference) }
    guard let reference else { return ["Select the exact original workshop booking."] }
    let child: ScriptInstance
    do { child = try inductionWorkshopChild(reference) } catch {
      return ["Restore this original workshop serial, owned fitting and native custody."]
    }
    guard let contract = child.savedNativeInductionWorkshop else {
      return ["Original workshop custody unavailable."]
    }
    switch action {
    case .pickupWorkshopUnit:
      if contract.pickup != nil { return ["The original is already aboard."] }
    case .cancelWorkshopBooking:
      if contract.pickup != nil {
        return ["After pickup, cancel delivery and retain original return custody."]
      }
    case .serviceWorkshopUnit:
      if contract.pickup == nil || contract.service != nil || contract.cancellation != nil {
        return ["Service needs the same original failed serial aboard, before cancellation."]
      }
    case .receiveWorkshopUnit:
      if contract.service == nil || contract.cancellation != nil {
        return ["Actual Renas service and original uncancelled owner return are required."]
      }
      if commander.credits > 4_294_967_295 - contract.booking.rewardNative {
        return ["Original workshop payment would overflow credits."]
      }
    case .cancelHeldWorkshopUnit:
      if contract.pickup == nil || contract.cancellation != nil {
        return ["Only the original held uncancelled workshop unit can request return."]
      }
    case .returnWorkshopUnit:
      if contract.pickup == nil || contract.cancellation == nil {
        return ["Separately cancel delivery before returning the original unit."]
      }
    default: return ["Unsupported workshop operation."]
    }
    return []
  }
  var inductionWorkshopDetail: [String] {
    let review = contractBoard.wayfarerInductionQuote
    let action = review?.action ?? contractBoard.selected?.wayfarerInduction
    var lines = [
      "ORIGINAL ENMADAN WORKSHOP / RENAS SERVICE / OWNER RETURN",
      "Six new unique2t original failed serials per charter epoch; separate from induction cassette, old W02/W03 stock and the six capacity windows.",
      "Complete currently reachable out-and-return quote:430+90L CR, hazard0. It sets payment, not compulsory hops or free fuel.",
      "Nonperishable and untimed: no integrity allowance, deadline or hidden timer.",
      "Booking Confirm reserves one exact original serial, an eligible workshop-owned window and2t real hold space, within the independent three-active-contract limit.",
      "Pickup at actual Enmadan replaces that reservation with the same carried original. Actual Renas service changes its same failed serial to operational; return to the original Enmadan owner pays the frozen quote once.",
      "Cancellation before pickup returns unchanged warehouse stock/window/space. After pickup it retains actual serial/condition/cargo/window until owner return or recorded loss; no replacement or cash.",
      "No source issue, load/reopen, service or return grants audit/stage12, accreditation or clue. Back/Escape changes nothing.",
    ]
    if let quote = review?.workshopQuote {
      let names = quote.route.worldKeys.compactMap {
        try? Universe.originalWorlds.world(key: $0).name
      }
      lines += [
        "CAPTURED COMPLETE QUOTE: " + names.joined(separator: " > "),
        String(
          format: "2t / %.1fCR / %d quoted legs / no deadline",
          Double(quote.offer.rewardNative) / 10, quote.route.distancesLY.count),
        "Original serial: " + quote.offer.serial.uuidString,
        "Stock revision\(quote.stockRevision); capacity revision\(quote.capacityRevision).",
      ]
    }
    if let window = review?.workshopWindow {
      lines.append("Exact workshop-owned window: " + window.unit.uuidString)
    }
    if let id = review?.workshopReference ?? contractBoard.selected?.inductionWorkshopReference,
      let contract = commander.scriptState.instances[id]?.savedNativeInductionWorkshop
    {
      lines += [
        "Original serial: " + contract.booking.serial.uuidString,
        "Retained condition: " + contract.condition.diagnostic,
        String(
          format: "Frozen complete-route quote %.1fCR", Double(contract.booking.rewardNative) / 10),
      ]
      if action == .cancelHeldWorkshopUnit {
        lines.append(
          "Confirm requests actual owner return. The2t cargo and window remain held; no immediate release or payment."
        )
      }
      if action == .returnWorkshopUnit {
        lines.append(
          "Confirm receives the same cancelled original at Enmadan, archives its actual condition and releases cargo/window without cash or fresh stock."
        )
      }
      if action == .receiveWorkshopUnit {
        lines.append("Confirm receives this same serviced original and pays its frozen quote once.")
      }
    }
    return lines + (review?.issues ?? [])
  }
}
