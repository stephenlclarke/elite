import Foundation

extension NativeWayfarerInductionAction {
  var station: SystemIdentity {
    switch self {
    case .accept, .progress: NativeWayfarerInduction.source
    case .pickup: NativeWayfarerInduction.clinic
    case .receive: NativeWayfarerInduction.receiver
    case .cassette: NativeWayfarerInduction.workshop
    }
  }
}

extension NativeWayfarerInductionState {
  func action(at system: SystemIdentity) -> NativeWayfarerInductionAction {
    if crate == nil && system == NativeWayfarerInduction.clinic { return .pickup }
    if crate != nil && loss == nil && reception == nil
      && system == NativeWayfarerInduction.receiver
    {
      return .receive
    }
    if reception != nil && cassette == nil && system == NativeWayfarerInduction.workshop {
      return .cassette
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
    if state.loss != nil || state.cassetteLoss != nil {
      return "The original consignment was lost. No replacement stock or success is granted."
    }
    if state.cassette != nil { return NativeWayfarerInduction.laterStages }
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
    if state?.cassette != nil { return "Renas repair desk / later receiving locked" }
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
        "VEIL: Enmadan released its original failed one-tonne cassette for Renas repair receiving. It remains workshop property; collection pays nothing. Repair receiving and stages 5-14 remain unavailable."
      )
    } else {
      throw SaveError.invalidCommander
    }
    mission.savedWayfarerInduction = next
    mission.payloads = next.payloads
    mission.milestones = next.milestones
    mission.revision += 1
    commander.scriptState.instances[mission.id] = mission
    notify(
      action == .receive
        ? "CLINIC CRATE RECEIVED INTACT - ENMADAN WORKSHOP NEXT"
        : "ORIGINAL FAILED CASSETTE ABOARD - LATER REPAIR RECEIVING LOCKED")
  }
}
