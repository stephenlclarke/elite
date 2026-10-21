import Foundation

enum NativeWayfarerInductionAction: String, Sendable {
  case accept, pickup, progress
  var key: String { NativeWayfarerInduction.stateID + "/" + rawValue }
  var title: String {
    switch self {
    case .accept: "Senn / review Exchange induction"
    case .pickup: "Renas clinic / review sealed cold crate"
    case .progress: "Senn / current induction records"
    }
  }
}
struct NativeWayfarerInductionReview: Sendable {
  let action: NativeWayfarerInductionAction
  let dock: NativeMainStationDockReceipt?
  let carrier: UUID?
  let inventoryRevision: UInt64?
  let trade: NativeInductionTradeEvidence?
  let epoch: UUID
  let issues: [String]
  let reviewToken = UUID()
  var allowed: Bool { action != .progress && issues.isEmpty }
}

extension Game {
  var wayfarerInductionRows: [ContractBoardRow] {
    guard !isMissionTrial, wayfarerInductionPack != nil else { return [] }
    let action: NativeWayfarerInductionAction
    if let state = wayfarerInductionMission?.savedWayfarerInduction {
      action =
        state.crate == nil && systemIdentity == NativeWayfarerInduction.clinic
        ? .pickup : .progress
    } else {
      guard systemIdentity == NativeWayfarerInduction.source else { return [] }
      action = .accept
    }
    return [
      .init(
        board: action.key, offer: nil, title: action.title,
        reason: wayfarerInductionReview(action).issues.first, wayfarerInduction: action)
    ]
  }

  func wayfarerInductionReview(
    _ action: NativeWayfarerInductionAction
  ) -> NativeWayfarerInductionReview {
    let trade =
      action == .accept
      ? commander.equipmentOwnerID.flatMap {
        NativeInductionTradeEvidence.first(in: commander.scriptState, owner: $0)
      } : wayfarerInductionMission?.savedWayfarerInduction?.permission.trade
    return .init(
      action: action, dock: commander.nativeStations?.currentMainDock,
      carrier: commander.hullInstanceID, inventoryRevision: commander.equipmentInventory?.revision,
      trade: trade, epoch: nativeStationRuntimeEpoch,
      issues: action == .progress ? [] : inductionActionIssues(action, trade: trade))
  }

  private func inductionActionIssues(
    _ action: NativeWayfarerInductionAction, trade: NativeInductionTradeEvidence?
  ) -> [String] {
    var issues: [String] = []
    if isMissionTrial { issues.append("Return to your commander before starting this induction.") }
    if paused { issues.append("Resume before confirming the induction action.") }
    let expected =
      action == .accept ? NativeWayfarerInduction.source : NativeWayfarerInduction.clinic
    if !nativeMainStationDockEvidenceIsCurrent || systemIdentity != expected {
      issues.append(
        action == .accept
          ? "Use Senn's actual Avenor main orbital berth."
          : "Use the actual Renas clinic main orbital berth.")
    }
    if !scriptDurabilityAvailable { issues.append("Choose a writable commander save first.") }
    if wayfarerInductionPack == nil { issues.append("Restore the approved Exchange opening.") }
    if commander.hullInstanceID == nil || commander.equipmentInventory == nil {
      issues.append("The actual owned carrier and fitting must be available.")
    }
    if commander.tradeCargoCapacity - commander.cargoTonnes < 1 {
      issues.append("Keep one free tonne for the serial induction consignment.")
    }
    issues += action == .accept ? inductionAcceptanceIssues(trade) : inductionPickupIssues()
    return issues
  }

  private func inductionAcceptanceIssues(_ trade: NativeInductionTradeEvidence?) -> [String] {
    var issues: [String] = []
    if wayfarerInductionMission != nil {
      issues.append("This commander already has the induction.")
    }
    if trade == nil {
      issues.append("Complete an ordinary delivery or actual native commodity sale first.")
    }
    if commander.scriptState.instances.count >= 128 {
      issues.append("The mission record capacity is full.")
    }
    return issues
  }

  private func inductionPickupIssues() -> [String] {
    var issues: [String] = []
    if wayfarerInductionMission?.suspension != nil {
      issues.append("Restore and resume this induction before clinic release.")
    }
    if wayfarerInductionMission?.outcome != .active
      || wayfarerInductionMission?.savedWayfarerInduction?.crate != nil
    {
      issues.append("The original clinic crate is unavailable; no stock is recreated.")
    }
    return issues
  }

  mutating func confirmWayfarerInduction(_ quote: NativeWayfarerInductionReview) throws {
    let current = wayfarerInductionReview(quote.action)
    guard quote.allowed, current.allowed, quote.dock == current.dock,
      quote.carrier == current.carrier, quote.inventoryRevision == current.inventoryRevision,
      quote.trade == current.trade, quote.epoch == current.epoch,
      let owner = commander.equipmentOwnerID, let dock = current.dock,
      let carrier = current.carrier, let revision = current.inventoryRevision,
      let pack = wayfarerInductionPack
    else {
      throw MissionPackError("The actual berth, carrier or induction terms changed; review again.")
    }
    var candidate = self
    if quote.action == .accept {
      guard let trade = current.trade else { throw SaveError.invalidCommander }
      let missionID = NativeWayfarerInduction.mission(owner: owner)
      guard commander.scriptState.instances[missionID] == nil else {
        throw MissionPackError("The mission records changed; review again.")
      }
      var mission = ScriptInstance(
        id: missionID, definition: NativeWayfarerInduction.stateID,
        version: NativeWayfarerInduction.version, digest: pack.digest)
      let permission = NativeInductionPermission(
        mission: missionID,
        operation: try NativeWayfarerInduction.commissionOperation(
          mission: missionID, owner: owner, dock: dock, carrier: carrier, revision: revision),
        owner: owner, dock: dock, trade: trade, carrier: carrier, inventoryRevision: revision,
        physicalTime: commander.flightSimulation.physicalTime,
        flightSeconds: commander.scriptState.flightSeconds)
      let state = NativeWayfarerInductionState(permission: permission)
      guard state.valid else { throw SaveError.invalidCommander }
      mission.savedWayfarerInduction = state
      mission.milestones = [0]
      candidate.commander.scriptState.instances[missionID] = mission
      candidate.emitScriptEvent("mission.accepted", only: missionID)
      candidate.notify("EXCHANGE INDUCTION ACCEPTED - REVIEW RENAS CLINIC PICKUP")
    } else {
      guard var mission = wayfarerInductionMission,
        let state = mission.savedWayfarerInduction, state.crate == nil,
        mission.revision < UInt64(Int64.max) - 1
      else { throw SaveError.invalidCommander }
      let clock = commander.scriptState.flightSeconds
      let unit = NativeWayfarerInduction.clinicUnit(owner: owner)
      let crate = NativeInductionClinicCrate(
        unit: unit, coolingUnit: ScriptIdentity.uuid("induction-sealed-cooling-v1:\(unit)"),
        operation: try NativeWayfarerInduction.pickupOperation(
          permission: state.permission.operation, dock: dock, carrier: carrier,
          revision: revision, flightSeconds: clock),
        dock: dock, carrier: carrier, inventoryRevision: revision,
        physicalTime: commander.flightSimulation.physicalTime,
        issuedFlightSeconds: clock, allowance: NativeWayfarerInduction.flightAllowance,
        deadline: clock + NativeWayfarerInduction.flightAllowance)
      let next = try state.collecting(
        crate, freeTonnes: commander.tradeCargoCapacity - commander.cargoTonnes)
      mission.savedWayfarerInduction = next
      mission.payloads = next.payloads
      mission.milestones.insert(1)
      mission.revision += 1
      mission.journal.append(
        "Renas clinic released the original sealed 1t crate for Navidor. Its independent cooling allows 1800 armed-flight seconds from confirmed pickup."
      )
      candidate.commander.scriptState.instances[mission.id] = mission
      candidate.notify("SEALED CLINIC CRATE ABOARD - NAVIDOR / 1800 FLIGHT SECONDS")
    }
    self = candidate
  }

  func wayfarerInductionDetail() -> [String] {
    var lines = [
      "SENN: These routes belong to the clinics, workshops and crews using them.",
      "Accept at Avenor after one ordinary delivery or actual native commodity sale.",
      "Use your current carrier and fitting. One free tonne is sufficient for serial induction property.",
      "Renas clinic releases one unique sealed 1t cold crate, including its working independent cooling unit.",
      String(
        format: "Declared destination: Navidor, G%02d-S%03d, registered main orbital clinic berth.",
        NativeWayfarerInduction.receiver.galaxy + 1, NativeWayfarerInduction.receiver.system),
      "Clinic cooling allowance: 1800 seconds (30 minutes) of armed flight after Confirm pickup.",
      "Preparation is untimed. Pause stops the clock; saving/loading or reopening never resets the fixed deadline.",
      "At zero remaining allowance the sample is spoiled; ordinary commodities cannot replace this original.",
      "Pickup pays nothing and grants no accreditation or clue. "
        + NativeWayfarerInduction.laterStages,
    ]
    if let state = wayfarerInductionMission?.savedWayfarerInduction {
      if let crate = state.crate {
        let remaining = (try? crate.remaining(at: commander.scriptState.flightSeconds)) ?? 0
        lines.append(
          String(format: "Clinic integrity: %.1f armed-flight seconds remaining.", remaining))
        if state.loss != nil {
          lines.append(
            "The original crate was lost with its carrier. No replacement stock is created.")
        } else if remaining == 0 {
          lines.append(
            "The sample is spoiled. Future receiving/replacement needs actual clinic stock.")
        }
      } else {
        lines.append("The clinic crate has not been issued; its flight allowance is unarmed.")
      }
    }
    if let quote = contractBoard.wayfarerInductionQuote { lines += quote.issues }
    return lines
  }
}
