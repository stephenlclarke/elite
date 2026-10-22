import Foundation

extension NativeWayfarerInductionAction {
  var isSeedStockAction: Bool {
    self == .issueSeedStock || self == .viewSeedStock || self == .acceptSeedLot
      || self == .cancelSeedBooking || isSeedCustodyAction
  }
}

extension Game {
  var inductionSeedRows: [ContractBoardRow] {
    var rows: [ContractBoardRow] = inductionSeedCustodyRows
    rows += commander.scriptState.instances.values.sorted {
      $0.id.uuidString < $1.id.uuidString
    }.compactMap { child in
      guard let contract = child.savedNativeInductionSeed, contract.close == nil,
        contract.custody == nil
      else {
        return nil
      }
      let action = NativeWayfarerInductionAction.cancelSeedBooking
      return .init(
        board: action.key, offer: nil,
        title: "Cancel uncollected seed lot " + contract.booking.unit.uuidString.prefix(8),
        reason: inductionSeedCancellationIssues(instance: child.id).first,
        wayfarerInduction: action, inductionSeedReference: child.id)
    }
    guard systemIdentity == NativeInductionCapacityOperator.seed.station,
      let state = wayfarerInductionMission?.savedWayfarerInduction,
      state.charterSignatures?.contains(where: { $0.operatorID == .seed }) == true
    else { return rows }
    let action: NativeWayfarerInductionAction =
      state.charterSeedSource == nil ? .issueSeedStock : .viewSeedStock
    rows.append(
      .init(
        board: action.key, offer: nil, title: action.title,
        reason: wayfarerInductionReview(action).issues.first, wayfarerInduction: action))
    if let source = state.charterSeedSource {
      for unit in source.units where unit.status == .available && unit.instance == nil {
        rows.append(
          .init(
            board: NativeWayfarerInductionAction.acceptSeedLot.key, offer: nil,
            title: "Reserve original seed lot " + unit.id.uuidString.prefix(8),
            reason: inductionSeedBookingIssues(unit: unit.id).first,
            wayfarerInduction: .acceptSeedLot, inductionSeedReference: unit.id))
      }
    }
    return rows
  }

  func inductionSeedSourceIssues() -> [String] {
    guard let mission = wayfarerInductionMission, mission.outcome == .active,
      mission.suspension == nil,
      let state = mission.savedWayfarerInduction, state.charterSeedSource == nil,
      state.charterChoice != nil, state.charterCapacity != nil,
      state.charterSignatures?.contains(where: { $0.operatorID == .seed }) == true,
      NativeInductionCrewLogSave.validateClaims(commander)
    else {
      return [
        "Original seed consent and finite capacity must exist; an issued sample batch cannot be replaced or replenished."
      ]
    }
    guard nativeInductionSeedPack != nil else {
      return ["Restore the exact original seed family content."]
    }
    guard let dock = commander.nativeStations?.currentMainDock,
      nativeMainStationDockEvidenceIsCurrent,
      systemIdentity == NativeInductionCapacityOperator.seed.station,
      case .living(let facility) = nativeOriginalMainStationDestination,
      facility.identity == dock.station, facility.observation.actor == dock.actor
    else {
      return [
        "Use the original seed custodian's actual living Enlirin main orbital for separate batch issue."
      ]
    }
    return []
  }
  mutating func confirmInductionSeedIssue(
    dock: NativeMainStationDockReceipt,
    carrier: UUID, revision: UInt64
  ) throws {
    guard inductionSeedSourceIssues().isEmpty,
      commander.nativeStations?.currentMainDock == dock, commander.hullInstanceID == carrier,
      commander.equipmentInventory?.revision == revision,
      var mission = wayfarerInductionMission, let state = mission.savedWayfarerInduction,
      let choice = state.charterChoice, let capacity = state.charterCapacity,
      let signature = state.charterSignatures?.first(where: { $0.operatorID == .seed }),
      mission.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let time = commander.flightSimulation.physicalTime
    let clock = commander.scriptState.flightSeconds
    let sequence = commander.scriptState.nextEvent + 1
    let fingerprint = try capacity.fingerprint
    let operation = try NativeInductionSeedIssue.identity(
      consent: signature.operation,
      allocation: capacity.allocation.operation, revision: capacity.revision,
      fingerprint: fingerprint,
      dock: dock, carrier: carrier, fit: revision, time: time, flightSeconds: clock,
      sequence: sequence)
    let issue = NativeInductionSeedIssue(
      operation: operation, sequence: sequence, parent: mission.id,
      commanderOwner: choice.owner,
      operatorOwner: NativeInductionCapacityOperator.seed.owner(epoch: choice.terms.epoch),
      epoch: choice.terms.epoch, policy: choice.policy, consent: signature.operation,
      allocation: capacity.allocation.operation, capacityRevision: capacity.revision,
      capacityFingerprint: fingerprint, family: NativeInductionSeedPack.stateID,
      familyVersion: NativeInductionSeedPack.version,
      familyDigest: NativeInductionSeedPack.digest,
      profile: .original, dock: dock, carrier: carrier, inventoryRevision: revision,
      physicalTime: time, flightSeconds: clock)
    let source = try NativeInductionSeedSource(issue: issue, parent: state)
    let next = try state.issuingSeedBatch(source)
    mission.savedWayfarerInduction = next
    mission.revision += 1
    mission.acknowledge(sequence)
    mission.journal.append(
      "Actual Enlirin seed custodian issued this epoch's one original batch of six new unique3t samples for Lareria, separate from induction cargo and the six capacity windows. The same signed issue delegates only read-only source-unit quote/refusal inspection to original Avenor. No pickup, timer start, window reservation, cash, clue or stage12 progress."
    )
    commander.scriptState.nextEvent = sequence
    commander.scriptState.instances[mission.id] = mission
    notify("ORIGINAL SEED BATCH RECORDED - SIX SAMPLES / READ-ONLY QUOTES")
  }

  var inductionSeedDetail: [String] {
    let state = wayfarerInductionMission?.savedWayfarerInduction
    if let review = contractBoard.wayfarerInductionQuote {
      if review.action.isSeedCustodyAction { return inductionSeedCustodyDetail(review) }
      if review.action == .cancelSeedBooking, let id = review.seedReference,
        let booking = commander.scriptState.instances[id]?.savedNativeInductionSeed?.booking
      {
        return [
          "CANCEL UNCOLLECTED ORIGINAL SEED SAMPLE",
          "Sample: " + booking.unit.uuidString,
          "Confirm cancels this booking, returns its same seed-owner capacity window and frees its reserved3t. The unchanged original seed lot remains at the warehouse. No timer, payment or success.",
          "Back/Escape retains the booking.",
        ] + review.issues
      }
      if review.action == .acceptSeedLot, let quote = review.seedQuote {
        var lines = [
          "RESERVE ORIGINAL SEED SAMPLE / PICKUP IS SEPARATE",
          "Sample: " + quote.offer.stockUnit.uuidString,
          String(
            format: "Reserve3t actual hold space. Frozen quote %.1fCR / %d legs to Lareria.",
            Double(quote.offer.rewardNative) / 10, quote.route.distancesLY.count),
          "Fly any reachable route; quoted hops are not mandatory. Actual pickup, original custody and receiver still apply.",
          "Confirm reserves this original seed lot and one eligible window owned by the seed. The independent maximum of three active contracts still applies.",
          "No cargo moves and the7200s integrity clock has not started. Use the separate Enlirin pickup row, then carry the original to actual Lareria receiving. Before pickup, cancel returns the original stock/window/hold space without cash or success.",
        ]
        if let window = review.seedWindow {
          lines.append("Exact seed window: " + window.unit.uuidString)
        }
        return lines + review.issues
      }
    }
    var lines = [
      "ORIGINAL ENLIRIN SEED BATCH / LARERIA RECEIVER",
      "Separate owner rebrief/Confirm issues one new finite batch: six unique3t samples for this charter epoch. They stay seed-vault property, separate from induction cargo and the six capacity windows.",
      "Current reachable source-to-receiver quotes set price:510+95L CR, hazard0, where L is actual quoted itinerary legs. No forced direct jump or unreachable offer.",
      "Only separate actual sample pickup starts its7200 qualifying armed-flight seconds. Pause stops that clock; saving/loading cannot reset it. This source review starts no deadline.",
      "The same actual owner issue grants original Avenor only read-only current-epoch original available-unit quote/refusal inspection. It grants no remote pickup or window booking authority.",
      "Confirm issue transfers no cargo or cash, reserves no window and grants no signature, audit, stage12 receipt, accreditation or clue. Back/Escape issues nothing. Actual pickup, integrity, receiver payment and held return each require their separate review/Confirm.",
    ]
    if let source = state?.charterSeedSource {
      lines.append(
        "Original source: " + source.identity.uuidString + "; operator owner "
          + source.issue.operatorOwner.uuidString)
      lines.append(
        "Six original source samples recorded; no replenishment or consignment activation on load/reopen."
      )
      if let quote = contractBoard.wayfarerInductionQuote?.seedQuote,
        quote.issue == source.issue.operation, quote.familyDigest == source.issue.familyDigest
      {
        let names = quote.route.worldKeys.compactMap {
          try? Universe.originalWorlds.world(key: $0).name
        }
        lines += [
          "READ-ONLY SOURCE QUOTE AT REVIEW: " + names.joined(separator: " > "),
          String(
            format: "%dt / %.1fCR / %d actual legs / integrity%.0fs after actual pickup",
            quote.offer.tonnes,
            Double(quote.offer.rewardNative) / 10, quote.route.distancesLY.count,
            quote.offer.flightAllowance),
          "Seed lot serial: " + quote.offer.stockUnit.uuidString,
          "Source revision\(quote.stockRevision); capacity revision\(quote.capacityRevision). Acceptance is a separate original-sample booking row.",
        ]
      } else {
        lines.append(
          "No current live reachable source quote. Restore actual source contact, family content, owned fitting and usable fuel/navigation; stock is not replaced."
        )
      }
    }
    return lines
  }
}
