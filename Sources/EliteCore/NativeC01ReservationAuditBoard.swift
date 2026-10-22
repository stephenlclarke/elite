import Foundation

extension Game {
  func glassMeridianAuditReview(_ action: NativeGlassMeridianAction) -> NativeGlassMeridianReview {
    let pin = try? NativeC01ReservationAuditReceipt.currentPin(in: self)
    var issues: [String] = []
    if pin == nil {
      issues.append(
        "Use Sorel's living Enmadan main berth with both genuine clock readings and the held original recorder. Older unbound commissions cannot create this audit."
      )
    }
    if action == .auditReservations,
      glassMeridianMission?.savedGlassMeridian?.reservationCase?.audit != nil
    {
      issues.append(
        "The original findings are already recorded. Review them or use Back; no second audit or payment is available."
      )
    }
    return .init(
      action: action, dock: commander.nativeStations?.currentMainDock,
      carrier: commander.hullInstanceID, inventoryRevision: commander.equipmentInventory?.revision,
      epoch: nativeStationRuntimeEpoch, issues: issues, auditPin: pin)
  }

  mutating func confirmGlassMeridianReservationAudit(_ review: NativeGlassMeridianReview) throws {
    if let audit = glassMeridianMission?.savedGlassMeridian?.reservationCase?.audit,
      audit.pin == review.auditPin, audit.consent == review.reviewToken
    {
      return
    }
    let current = glassMeridianAuditReview(.auditReservations)
    guard review.action == .auditReservations, review.allowed, current.allowed,
      review.auditPin == current.auditPin, review.dock == current.dock,
      review.epoch == current.epoch, review.carrier == current.carrier,
      review.inventoryRevision == current.inventoryRevision, let pin = current.auditPin,
      var mission = glassMeridianMission, var state = mission.savedGlassMeridian,
      state.reservationCase?.audit == nil, mission.revision < UInt64(Int64.max) - 1
    else {
      throw MissionPackError(
        "The original source, recorder, readings, berth or fitting changed; review Sorel's audit again."
      )
    }
    let audit = try NativeC01ReservationAuditReceipt.readAndCompare(
      in: self, pin: pin, consent: review.reviewToken)
    var candidate = self
    state.reservationCase?.audit = audit
    mission.savedGlassMeridian = state
    mission.milestones = [0, 1, 2, 3]
    mission.revision += 1
    mission.receipts.insert(audit.target)
    mission.receipts.insert(NativeC01ReservationAuditReceipt.localStage)
    mission.acknowledge(audit.sequence)
    mission.journal.append(
      "Sorel compared the original paid bookings and recovered calibration: one certificate, two claims, 30 seconds true overlap, a concealed 60-second clock offset and one extra reservation counter. Stage four only. The original 8kg recorder stays aboard; no cargo, payment, reward or clue is transferred."
    )
    candidate.commander.scriptState.nextEvent = audit.sequence
    candidate.commander.scriptState.instances[mission.id] = mission
    guard NativeGlassMeridianSave.validateClaims(candidate.commander) else {
      throw SaveError.invalidCommander
    }
    candidate.notify("SOREL AUDIT RECORDED - ENLIRIN STANDARD RECOVERY REMAINS UNAVAILABLE")
    self = candidate
  }

  func glassMeridianAuditDetail(_ action: NativeGlassMeridianAction) -> [String] {
    guard let value = glassMeridianMission?.savedGlassMeridian?.reservationCase else {
      return ["This older commission has no original booking corpus. Nothing can be backfilled."]
    }
    let source = value.source
    var lines = ["CAPTAIN ORIN SOREL - ENMADAN RESERVATION AUDIT"]
    let review = contractBoard.glassMeridianQuote ?? glassMeridianAuditReview(action)
    guard review.auditPin != nil || value.audit != nil else { return lines + review.issues }
    switch action {
    case .ledgerEntries:
      let projection = source.projection
      lines += [
        "The port authority issued one lane unit and one original certificate to the clinic.",
        "The contractor then sold freight a paid copy of the same certificate; no second unit was allocated.",
        "Balances: Clinic \(String(format: "%.1f", Double(projection.balances.clinic) / 10)) CR; Freight \(String(format: "%.1f", Double(projection.balances.freight) / 10)) CR; Contractor \(String(format: "%.1f", Double(projection.balances.contractor) / 10)) CR.",
      ]
      for (index, claim) in projection.claims.enumerated() {
        let customer = claim.customer == source.clinicCustomer ? "Clinic" : "Freight"
        lines.append(
          "Claim \(index + 1): \(claim.id.uuidString); \(customer) customer \(claim.customer.uuidString)"
        )
        lines.append(
          "True [\(claim.trueWindow.start), \(claim.trueWindow.end)); local [\(claim.localWindow.start), \(claim.localWindow.end))"
        )
        lines.append("Certificate \(claim.certificate.uuidString)")
        for payment in projection.payments where payment.claim == claim.id {
          lines.append(
            "Payment \(payment.operation.uuidString): \(String(format: "%.1f", Double(payment.amount) / 10)) CR."
          )
        }
      }
    case .recorderCalibration:
      lines.append(
        "The original held recorder supplies the independent calibration and both control references."
      )
      for clock in source.clocks {
        let label = clock.ordinal == 0 ? "A" : "B"
        lines.append(
          "Clock \(label): local offset \(clock.offset) seconds; reservation counter \(clock.reservationCounter)."
        )
        for calibration in source.recorder.calibrations
        where calibration.clockLineage == clock.lineage {
          lines.append(
            "Recorder calibration: \(calibration.offset) seconds; lineage \(calibration.clockLineage.uuidString)."
          )
        }
      }
      lines += [
        "The contents belong to the original commission and clock lineages, before either scan or recorder recovery.",
        "Replacements of an unread clock retain its original contents; a matching label cannot supply a reading.",
      ]
    case .auditReservations:
      lines += [
        "Compare the port authority's original ledger with the held recorder and both real clock readings.",
        "Findings: one certificate, two paid claims, 30 seconds true overlap.",
        "The apparent local separation conceals a +60 second clock offset and one extra reservation counter.",
        "Confirm records only Sorel's audit. Back changes nothing.",
        "The original 8kg recorder remains protected cargo. No cash, equipment, reward or final clue is granted.",
        "Next: recover-standard at Enlirin. That later stage remains unavailable.",
      ]
      if value.audit != nil {
        lines.append(
          "These original findings are already recorded and survive later genuine recorder loss.")
      }
    default: break
    }
    lines += review.issues
    return lines
  }

  /// Called only alongside the existing genuine loss publication. Old/unbound history is untouched.
  func observeC01ReservationLoss(
    state: inout NativeGlassMeridianState, mission: inout ScriptInstance
  ) throws -> UInt64? {
    guard let audit = state.reservationCase?.audit else { return nil }
    guard let loss = state.surveyor?.loss, state.reservationCase?.laterLoss == nil,
      loss.physicalTime >= audit.physicalTime,
      commander.scriptState.nextEvent >= audit.sequence,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let sequence = commander.scriptState.nextEvent + 1
    state.reservationCase?.laterLoss = .init(sequence: sequence, audit: audit.operation, loss: loss)
    mission.acknowledge(sequence)
    return sequence
  }
}
