import Foundation

extension NativeWayfarerInductionAction {
  var station: SystemIdentity {
    switch self {
    case .accept, .progress, .pooledCharter, .protectedCharter, .allocateCharterCapacity,
      .auditCharter, .certifyNetwork:
      NativeWayfarerInduction.source
    case .clinicConsent, .releaseClinicCapacity, .issueClinicStock, .viewClinicStock,
      .acceptClinicSample, .cancelClinicSample:
      NativeWayfarerInduction.clinic
    case .pickupClinicSample, .returnClinicSample, .cancelHeldClinicSample, .retryClinicExpiry:
      NativeWayfarerInduction.clinic
    case .receiveClinicSample: NativeWayfarerInduction.receiver
    case .issueWorkshopStock, .viewWorkshopStock, .acceptWorkshopUnit, .pickupWorkshopUnit,
      .receiveWorkshopUnit, .cancelWorkshopBooking, .cancelHeldWorkshopUnit, .returnWorkshopUnit:
      NativeWayfarerInduction.workshop
    case .serviceWorkshopUnit: NativeWayfarerInduction.clinic
    case .issueSeedStock, .viewSeedStock, .acceptSeedLot, .cancelSeedBooking,
      .pickupSeedLot, .cancelHeldSeedLot, .returnSeedLot, .retrySeedExpiry:
      NativeWayfarerInduction.seedSource
    case .receiveSeedLot: NativeWayfarerInduction.seedReceiver
    case .workshopConsent, .releaseWorkshopCapacity: NativeWayfarerInduction.workshop
    case .seedConsent, .releaseSeedCapacity: NativeWayfarerInduction.seedSource
    case .pickup: NativeWayfarerInduction.clinic
    case .receive: NativeWayfarerInduction.receiver
    case .service: NativeWayfarerInduction.clinic
    case .keyLoan, .launchArk, .replaceArk: NativeWayfarerInduction.seedSource
    case .receiveArk: NativeWayfarerInduction.seedReceiver
    case .fundRescueLaunch, .startRescueFlight: NativeInductionCrewLogSource.location
    case .receiveRescue: NativeInductionCrewLogSource.receiver
    case .authorizeUtility, .receiveUtility: NativeInductionUtilitySource.location
    case .cassette: NativeWayfarerInduction.workshop
    }
  }
}

extension NativeWayfarerInductionState {
  func action(at system: SystemIdentity) -> NativeWayfarerInductionAction {
    if crewLog != nil && crewLogLoss == nil && rescueReception == nil
      && system == NativeInductionCrewLogSource.receiver
    {
      return .receiveRescue
    }
    if seedKey != nil && seedKeyLoss == nil && seedReception == nil && ark != nil
      && system == NativeWayfarerInduction.seedReceiver
    {
      return .receiveArk
    }
    if seedKey != nil && seedKeyLoss == nil && ark == nil
      && system == NativeWayfarerInduction.seedSource
    {
      return .launchArk
    }
    if crate == nil && system == NativeWayfarerInduction.clinic { return .pickup }
    if crate != nil && loss == nil && reception == nil
      && system == NativeWayfarerInduction.receiver
    {
      return .receive
    }
    if reception != nil && cassette == nil && system == NativeWayfarerInduction.workshop {
      return .cassette
    }
    if cassetteService != nil && seedKey == nil && system == NativeWayfarerInduction.seedSource {
      return .keyLoan
    }
    if cassette != nil && cassetteLoss == nil && cassetteService == nil
      && system == NativeWayfarerInduction.clinic
    {
      return .service
    }
    return .progress
  }
}

extension Game {
  var wayfarerInductionObjective: String {
    guard let state = wayfarerInductionMission?.savedWayfarerInduction else {
      return
        "Review Senn's induction at Avenor after an ordinary delivery or native commodity sale."
    }
    if state.utilityReception != nil {
      if state.charterChoice == nil {
        return
          "At Avenor, compare Pooled windows and Protected reservations; separately Confirm one charter policy. No operator signature is granted by this choice."
      }
      if state.charterCapacity == nil {
        return
          "At actual Avenor, separately review/Confirm this earlier charter's still-unissued original capacity ledger. Loading issues nothing."
      }
      return
        "Actual owner consents \(state.charterSignatures?.count ?? 0)/3: Renas, Enmadan and Enlirin. Protected free-unit release is separate; actual consignment/source-quote audit remains next. No stage12, accreditation or final payment."
    }
    if let status = inductionUtilitySourceStatus { return status }
    if let status = inductionCrewLogStatus { return status }
    if state.loss != nil || state.cassetteLoss != nil || state.seedKeyLoss != nil {
      return "The original consignment was lost. No replacement stock or success is granted."
    }
    if let status = inductionArkStatus { return status }
    if state.seedKey != nil {
      return "Confirm the original custodian ark launch at Enlirin main orbital."
    }
    if state.cassetteService != nil {
      return
        "Review Enlirin's seed-custodian consent and Confirm its original one-tonne vault-key loan."
    }
    if state.cassette != nil {
      return "Confirm original cassette service and owner return at Renas repair desk."
    }
    if state.reception != nil {
      return "Collect Enmadan's original failed workshop cassette for Renas."
    }
    if let crate = state.crate {
      let remaining = (try? crate.remaining(at: commander.scriptState.flightSeconds)) ?? 0
      return remaining > 0
        ? "Confirm intact original-crate reception at Navidor before the fixed cooling deadline."
        : "The original sample is spoiled. No receiving success or replacement is granted."
    }
    return "Review the unique sealed clinic crate and Navidor destination at Renas."
  }

  var wayfarerInductionDestination: String {
    let state = wayfarerInductionMission?.savedWayfarerInduction
    if state?.utilityReception != nil {
      if state?.charterChoice == nil {
        return "Avenor main orbital G01-S007 / compare and Confirm charter policy"
      }
      if state?.charterCapacity == nil {
        return "Avenor main orbital G01-S007 / review still-unissued original capacity"
      }
      return
        "Original charter owners: Renas185 / Enmadan000 / Enlirin162 for separate consent; source-quote audit remains next"
    }
    if state?.rescueReception != nil {
      return "Enron G01-S190 / original utility handoff maintenance authorization"
    }
    if state?.crewLog != nil {
      return
        "Enmadan main orbital G01-S000 / same original launch, living crew and recorder receiving"
    }
    if state?.seedReception != nil {
      return "Cevilis G01-S211 / original custody-recorder recovery"
    }
    if state?.seedKey != nil {
      return "Lareria receiving cradle, G01-S091 / original ark receiving and key return"
    }
    if state?.cassetteService != nil { return "Enlirin main orbital seed vault, G01-S162" }
    if state?.cassette != nil { return "Renas main orbital repair desk, G01-S185" }
    if state?.reception != nil { return "Enmadan main orbital workshop, G01-S000" }
    if state?.crate != nil { return "Navidor main orbital clinic, G01-S164" }
    return "Renas main orbital clinic, G01-S185"
  }

  func inductionContinuationIssues(_ action: NativeWayfarerInductionAction) -> [String] {
    guard let mission = wayfarerInductionMission, mission.outcome == .active,
      mission.suspension == nil, let state = mission.savedWayfarerInduction, state.valid,
      state.permission.owner == commander.equipmentOwnerID
    else { return ["Restore this commander's active induction before confirming."] }
    if action == .receive {
      guard let crate = state.crate, state.loss == nil, state.reception == nil,
        let remaining = try? crate.remaining(at: commander.scriptState.flightSeconds),
        remaining > 0
      else { return ["The original sealed crate with usable cooling quality is required."] }
    } else if action == .cassette {
      guard state.reception != nil, state.cassette == nil else {
        return [
          "Confirm intact Navidor clinic receiving before this original cassette is released."
        ]
      }
    } else if action == .service {
      guard state.cassette != nil, state.cassetteLoss == nil, state.cassetteService == nil else {
        return [
          "The same original failed cassette must be aboard and not already serviced or returned."
        ]
      }
    }
    if action == .keyLoan {
      guard state.cassetteService != nil, state.seedKey == nil else {
        return [
          "Complete the original cassette service/return before borrowing the one original vault key."
        ]
      }
    }
    return []
  }

  mutating func confirmInductionContinuation(
    _ action: NativeWayfarerInductionAction, dock: NativeMainStationDockReceipt,
    carrier: UUID, revision: UInt64
  ) throws {
    guard var mission = wayfarerInductionMission, let state = mission.savedWayfarerInduction,
      mission.outcome == .active, mission.suspension == nil,
      mission.revision < UInt64(Int64.max) - 1,
      let owner = commander.equipmentOwnerID, owner == state.permission.owner,
      nativeMainStationDockEvidenceIsCurrent,
      commander.nativeStations?.currentMainDock == dock, systemIdentity == action.station
    else { throw SaveError.invalidCommander }
    let clock = commander.scriptState.flightSeconds
    let physicalTime = commander.flightSimulation.physicalTime
    let next: NativeWayfarerInductionState
    if action == .receive {
      guard let crate = state.crate else { throw SaveError.invalidCommander }
      let reception = NativeInductionClinicReception(
        operation: try NativeWayfarerInduction.continuationOperation(
          target: NativeWayfarerInduction.receivingTarget, previous: crate.operation,
          dock: dock, carrier: carrier, revision: revision, flightSeconds: clock),
        crateOperation: crate.operation, unit: crate.unit, coolingUnit: crate.coolingUnit,
        dock: dock, carrier: carrier, inventoryRevision: revision,
        physicalTime: physicalTime, flightSeconds: clock,
        remaining: try crate.remaining(at: clock))
      next = try state.receiving(reception)
      mission.journal.append(
        "Navidor clinic confirmed the original sealed crate and usable cooling quality. No payment or accreditation. Next: Enmadan's original failed workshop cassette."
      )
    } else if action == .cassette {
      guard let reception = state.reception else { throw SaveError.invalidCommander }
      let cassette = NativeInductionWorkshopCassette(
        operation: try NativeWayfarerInduction.continuationOperation(
          target: NativeWayfarerInduction.cassetteTarget, previous: reception.operation,
          dock: dock, carrier: carrier, revision: revision, flightSeconds: clock),
        receptionOperation: reception.operation,
        unit: NativeWayfarerInduction.cassetteUnit(owner: owner), dock: dock,
        carrier: carrier, inventoryRevision: revision, physicalTime: physicalTime,
        flightSeconds: clock, condition: "failed-workshop-original")
      next = try state.collectingCassette(
        cassette, freeTonnes: commander.tradeCargoCapacity - commander.cargoTonnes)
      mission.journal.append(
        "VEIL: Enmadan released its original failed one-tonne cassette for Renas repair receiving. It remains workshop property; collection pays nothing. Review actual service and the owner's receiving record at Renas repair desk."
      )
    } else if action == .service {
      next = try inductionCassetteService(
        state, dock: dock, carrier: carrier, revision: revision,
        physicalTime: physicalTime, flightSeconds: clock)
      mission.journal.append(
        "Renas repaired the original cassette and recorded Enmadan workshop's receipt. The original serial remains in the service history; no second unit, payment, accreditation or clue was created."
      )
    } else if action == .keyLoan {
      next = try inductionVaultKeyLoan(
        state, dock: dock, carrier: carrier, revision: revision,
        physicalTime: physicalTime, flightSeconds: clock)
      mission.journal.append(
        "VEIL: Enlirin's custodians consented to the seed transfer and loaned their original one-tonne vault key for Lareria's receiving cradle. It remains their property; the seed itself travels aboard the registered ark. Actual escort and key-return receiving remain unavailable."
      )
    } else {
      throw SaveError.invalidCommander
    }
    mission.savedWayfarerInduction = next
    mission.payloads = next.payloads
    mission.milestones = next.milestones
    mission.revision += 1
    commander.scriptState.instances[mission.id] = mission
    switch action {
    case .receive: notify("CLINIC CRATE RECEIVED INTACT - ENMADAN WORKSHOP NEXT")
    case .cassette: notify("ORIGINAL FAILED CASSETTE ABOARD - RENAS REPAIR DESK NEXT")
    case .service: notify("ORIGINAL CASSETTE SERVICED AND RETURNED - ENLIRIN CONSENT NEXT")
    case .keyLoan: notify("CUSTODIAN VAULT KEY ON LOAN - ACTUAL ESCORT STILL LOCKED")
    default: break
    }
  }
}
