import Foundation

enum NativeWayfarerInductionAction: String, Sendable {
  case accept, pickup, receive, cassette, service, keyLoan, launchArk, receiveArk, replaceArk,
    fundRescueLaunch,
    progress
  var key: String { NativeWayfarerInduction.stateID + "/" + rawValue }
  var title: String {
    switch self {
    case .accept: "Senn / review Exchange induction"
    case .pickup: "Renas clinic / review sealed cold crate"
    case .receive: "Navidor clinic / review intact crate reception"
    case .cassette: "Enmadan workshop / review failed cassette collection"
    case .service: "Renas repair desk / review original service and owner return"
    case .keyLoan: "Enlirin seed vault / review consent and original key loan"
    case .launchArk: "Enlirin seed custodians / review original ark launch"
    case .receiveArk: "Lareria cradle / review original ark receiving and key return"
    case .replaceArk: "Enlirin custodians / review the one reserved ark launch"
    case .fundRescueLaunch: "Cevilis custodian / review original rescue fuel allocation"
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
  let missionRevision: UInt64?
  let arkRevision: UInt64?
  let rescueRevision: UInt64?
  let issues: [String]
  let reviewToken = UUID()
  var allowed: Bool { action != .progress && issues.isEmpty }
}

extension Game {
  var wayfarerInductionRows: [ContractBoardRow] {
    guard !isMissionTrial, wayfarerInductionPack != nil else { return [] }
    let action: NativeWayfarerInductionAction
    if let state = wayfarerInductionMission?.savedWayfarerInduction {
      if systemIdentity == NativeInductionCrewLogSource.location,
        state.crewLog != nil, state.crewLogLoss == nil,
        inductionCrewLogChild?.savedNativeCrewLog?.rescueFuel == nil,
        inductionCrewLogChild != nil
      {
        action = .fundRescueLaunch
      } else if systemIdentity == NativeWayfarerInduction.seedSource, let link = state.ark,
        state.seedReception == nil,
        commander.scriptState.instances[link.job]?.savedNativeArk?.loss != nil
      {
        action = .replaceArk
      } else {
        action = state.action(at: systemIdentity)
      }
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
      missionRevision: wayfarerInductionMission?.revision,
      arkRevision: wayfarerInductionMission?.savedWayfarerInduction?.ark.flatMap {
        commander.scriptState.instances[$0.job]?.revision
      },
      rescueRevision: inductionCrewLogChild?.revision,
      issues: action == .progress ? [] : inductionActionIssues(action, trade: trade))
  }

  private func inductionActionIssues(
    _ action: NativeWayfarerInductionAction, trade: NativeInductionTradeEvidence?
  ) -> [String] {
    var issues: [String] = []
    if isMissionTrial { issues.append("Return to your commander before starting this induction.") }
    if paused { issues.append("Resume before confirming the induction action.") }
    let expected = action.station
    if !nativeMainStationDockEvidenceIsCurrent || systemIdentity != expected {
      issues.append("Use the actual registered main orbital berth for " + action.title + ".")
    }
    if !scriptDurabilityAvailable { issues.append("Choose a writable commander save first.") }
    if wayfarerInductionPack == nil { issues.append("Restore the approved Exchange opening.") }
    if commander.hullInstanceID == nil || commander.equipmentInventory == nil {
      issues.append("The actual owned carrier and fitting must be available.")
    }
    if action != .receive && action != .service && action != .launchArk && action != .receiveArk
      && action != .replaceArk && action != .fundRescueLaunch,
      commander.tradeCargoCapacity - commander.cargoTonnes < 1
    {
      issues.append("Keep one free tonne for the serial induction consignment.")
    }
    switch action {
    case .accept: issues += inductionAcceptanceIssues(trade)
    case .pickup: issues += inductionPickupIssues()
    case .receive, .cassette, .service, .keyLoan: issues += inductionContinuationIssues(action)
    case .launchArk: issues += inductionArkLaunchIssues()
    case .receiveArk: issues += inductionArkReceivingIssues()
    case .replaceArk: issues += inductionArkReplacementIssues()
    case .fundRescueLaunch: issues += inductionRescueFundingIssues()
    case .progress: break
    }
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
      quote.missionRevision == current.missionRevision, quote.arkRevision == current.arkRevision,
      quote.rescueRevision == current.rescueRevision,
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
      mission.savedArkReserve = NativeInductionArkReserve(permission: permission)
      mission.milestones = [0]
      candidate.commander.scriptState.instances[missionID] = mission
      candidate.emitScriptEvent("mission.accepted", only: missionID)
      candidate.notify("EXCHANGE INDUCTION ACCEPTED - REVIEW RENAS CLINIC PICKUP")
    } else if quote.action == .pickup {
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
    if quote.action == .receive || quote.action == .cassette || quote.action == .service
      || quote.action == .keyLoan
    {
      try candidate.confirmInductionContinuation(
        quote.action, dock: dock, carrier: carrier, revision: revision)
    }
    if quote.action == .launchArk {
      try candidate.confirmInductionArkLaunch(dock: dock, carrier: carrier, revision: revision)
    }
    if quote.action == .receiveArk {
      try candidate.confirmInductionArkReceiving(dock: dock, carrier: carrier, revision: revision)
    }
    if quote.action == .replaceArk {
      try candidate.confirmInductionArkReplacement(dock: dock, carrier: carrier, revision: revision)
    }
    if quote.action == .fundRescueLaunch {
      try candidate.confirmInductionRescueFunding(dock: dock)
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
      "Confirm intact clinic reception at Navidor before the original cooling deadline, then collect Enmadan's failed workshop cassette for the Renas repair desk.",
      "Reception frees the clinic tonne; cassette collection needs one free tonne and has no deadline.",
      "At Renas repair desk, Confirm service of the same original cassette and its owner's receiving record. This releases its tonne and pays nothing.",
      "At Enlirin, review the seed custodians' consent before Confirm borrows their unique one-tonne vault key for Lareria's receiving cradle. The key stays their property; the seed travels aboard the ark.",
      "The loan is untimed, needs one free tonne and cannot be sold, fitted or released as personal equipment. At Enlirin, separately review and Confirm the one original ark registration; no extra player cargo space is required.",
      "The registered ark uses actual native aperture docking and its own custodian escrow for needed-hop fuel. Each real main station has a separate finite 100-LY ark-service reserve. Saving, revisiting or reopening never refills stock or funds; actual Lareria receiving and original key return need their separate Confirm review.",
      "Original escort terms: one custodian Haflinger, forty unique seed tonnes and six living crew, with its own finite 1000 CR fuel escrow. Its authored tank is 13 LY, drive 9 LY per hop and spool 12 seconds; your separate original vault key occupies one tonne.",
      "One initial reserve holds a distinct Haflinger, forty distinct seed tonnes, six distinct crew and a separate 1000 CR fuel issue. Only proved original-ark destruction and fresh Enlirin custodian consent can release it once. The same original key must still be aboard. Unused prior escrow returns to its custodian; no payment or progress is awarded.",
      "The destroyed hull, seed and crew remain lost. Station fuel stock stays depleted. After the single reserve is consumed, no further launch or new key is available without a separate real authored source.",
      "These stages pay nothing and grant no accreditation or clue. "
        + NativeWayfarerInduction.laterStages,
    ]
    if let status = inductionCrewLogStatus { lines.append(status) }
    if let state = inductionCrewLogChild?.savedNativeCrewLog {
      if let account = state.rescueFuel {
        lines.append(
          String(
            format:
              "Original rescue launch NPC fuel escrow: %.1f CR remaining / initial1000CR. Source SH029: 13LY tank, 9LY drive, 12s spool. This is separate from player cash and both seed-ark accounts.",
            Double(account.remainingCredits) / 10))
        lines.append(
          "Future real dock service shares the existing depleted100LY main-station reserve with seed arks; no extra station stock or arrival fuel is granted. Native route travel and Enmadan survivor/recorder receiving remain unavailable until their actual provider joins are complete."
        )
        lines.append(
          "One uncrewed Burro and separate future1000CR funding are reserved. Replacement cannot create people or a recorder: only the same original two surviving crew in actual supported custody may transfer after real rebrief/launch. The replacement branch remains unavailable."
        )
      } else {
        lines.append(
          "This existing source has no rescue fuel issue. After recovering its original recorder, use actual Cevilis custodian rebrief and Confirm the still-unissued finite1000CR allocation. Loading, reopening or revisiting does not grant funds."
        )
      }
    }
    if let status = inductionArkStatus { lines.append(status) }
    if wayfarerInductionMission?.savedWayfarerInduction?.seedReception != nil {
      lines += [
        "Cevilis source: empty mechanically disabled original Burro tender, separate marked Burro rescue launch with two original crew, and their original one-tonne custody recorder for Enmadan shelter.",
        "Source offsets in physical metres from the main station's non-spinning reference: tender(60000,20000,0), launch(60300,20000,0), recorder(60000,20000,100). Admission waits for real clearance/local range; no marker counts as pickup or rescue.",
        "Fit Fuel Scoops and keep one free tonne. Safely bring only the original recorder into the lower forward scoop at X0/Y-45m/Z+55m; package plus bounds must fit aperture half extents16m at relative speed <=\(Int(ScoopApproachController.maximumRelativeSpeed))m/s. Optional Salvage targeting can guide the same actual scoop. The tender, launch and their equipment stay custodian property; no player cabins are needed.",
        "Stage8 protects the original recorder as mission cargo, identifying both original launch occupants and Enmadan shelter. Its carrier loss releases the tonne but retains original pickup/loss history, with no reissue. Stage9 actual launch travel and survivors/recorder receiving remain unavailable; no payment, clue or accreditation is awarded here.",
      ]
    }
    if let link = wayfarerInductionMission?.savedWayfarerInduction?.ark,
      let state = commander.scriptState.instances[link.job]?.savedNativeArk
    {
      let route = state.authorization.route.worldKeys.compactMap {
        try? Universe.originalWorlds.world(key: $0).name
      }
      lines.append("Registered escort route: " + route.joined(separator: " > "))
      lines.append(
        "Assigned manifest: forty seed tonnes and six crew; the original borrowed player key remains separate."
      )
      lines.append(
        String(
          format: "Current custodian fuel escrow: %.1f CR. Player cash is separate.",
          Double(state.fuel.remainingCredits) / 10))
    }
    if let parent = wayfarerInductionMission {
      lines.append(
        parent.savedArkRecovery == nil
          ? "Custodian reserve: one initial allocation available only after proved original loss and actual rebrief."
          : "Custodian reserve consumed: no further hull, seed, crew or fuel-funding issue is available."
      )
    }
    if let state = wayfarerInductionMission?.savedWayfarerInduction {
      if let reception = state.reception {
        lines.append(
          String(
            format:
              "Original clinic crate received intact at Navidor with %.1f flight seconds remaining.",
            reception.remaining))
        if let key = state.seedKey {
          if state.seedReception != nil {
            lines.append(
              "Lareria received the forty original seed tonnes with all six original crew alive. The original vault key and unused custodian escrow were returned; the carried tonne is released. No player payment, clue or accreditation."
            )
          }
          lines.append(
            state.seedReception != nil
              ? "Original Enlirin vault key returned at the actual Lareria receiving cradle."
              : state.seedKeyLoss == nil
                ? "Original Enlirin vault key aboard on loan; return is restricted to Lareria's seed-ark receiving cradle. Original ark registration is reviewed separately at Enlirin; actual cradle receiving and original key return are reviewed separately at Lareria."
                : "The original vault key was lost; its outstanding custodian loan remains recorded. No replacement or return is granted."
          )
          lines.append(
            "Loan source: " + key.source.resource + "; issued original remains custodian property.")
        } else if state.cassetteService != nil {
          lines.append(
            "Renas serviced the same original cassette and confirmed its owner's receipt. The workshop tonne is released."
          )
        } else if state.cassette != nil {
          lines.append(
            state.cassetteLoss == nil
              ? "Enmadan's original failed cassette is aboard. Review service and owner return at Renas repair desk."
              : "The original workshop cassette was lost. No replacement is created.")
        } else {
          lines.append(
            "Next: collect the one-tonne failed cassette at Enmadan main orbital workshop.")
        }
      } else if let crate = state.crate {
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
