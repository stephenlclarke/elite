import Foundation

enum NativeWayfarerInductionAction: String, Sendable {
  case accept, pickup, receive, cassette, service, keyLoan, launchArk, receiveArk, replaceArk,
    fundRescueLaunch, startRescueFlight, receiveRescue, authorizeUtility, receiveUtility,
    pooledCharter, protectedCharter, allocateCharterCapacity,
    clinicConsent, workshopConsent, seedConsent, releaseClinicCapacity, releaseWorkshopCapacity,
    releaseSeedCapacity, issueClinicStock, viewClinicStock, acceptClinicSample, cancelClinicSample,
    pickupClinicSample, receiveClinicSample, cancelHeldClinicSample, returnClinicSample,
    retryClinicExpiry,
    issueWorkshopStock, viewWorkshopStock, acceptWorkshopUnit, pickupWorkshopUnit,
    serviceWorkshopUnit, receiveWorkshopUnit, cancelWorkshopBooking, cancelHeldWorkshopUnit,
    returnWorkshopUnit, progress
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
    case .startRescueFlight: "Cevilis custodian / review original marked-launch escort"
    case .receiveRescue: "Enmadan reception / review original survivors and recorder return"
    case .authorizeUtility: "Enron utility crew / review original handoff maintenance authorization"
    case .receiveUtility: "Enron utility crew / review all three repaired handoffs"
    case .pooledCharter: "Avenor charter / review Pooled windows"
    case .protectedCharter: "Avenor charter / review Protected reservations"
    case .allocateCharterCapacity: "Avenor charter / review still-unissued original capacity"
    case .clinicConsent: "Renas clinic / review selected charter consent"
    case .workshopConsent: "Enmadan workshop / review selected charter consent"
    case .seedConsent: "Enlirin seed custodians / review selected charter consent"
    case .releaseClinicCapacity: "Renas clinic / review exact free-unit release"
    case .releaseWorkshopCapacity: "Enmadan workshop / review exact free-unit release"
    case .releaseSeedCapacity: "Enlirin seed custodians / review exact free-unit release"
    case .issueClinicStock:
      "Renas clinic / review six original sample issue and read-only delegation"
    case .viewClinicStock: "Renas clinic / original stock and read-only current route quote"
    case .acceptClinicSample: "Renas clinic / reserve original sample and window"
    case .cancelClinicSample: "Clinic booking / cancel before pickup"
    case .pickupClinicSample: "Renas clinic / collect reserved original sample"
    case .receiveClinicSample: "Navidor clinic / receive original sample and pay quote"
    case .cancelHeldClinicSample: "Clinic sample / cancel delivery and retain return custody"
    case .returnClinicSample: "Renas clinic / return cancelled original sample"
    case .retryClinicExpiry: "Clinic sample / retry original pending integrity expiry"
    case .issueWorkshopStock: "Enmadan workshop / issue six original failed serials"
    case .viewWorkshopStock: "Enmadan workshop / original stock and complete route quote"
    case .acceptWorkshopUnit: "Enmadan workshop / reserve original serial and window"
    case .pickupWorkshopUnit: "Enmadan workshop / collect original failed serial"
    case .serviceWorkshopUnit: "Renas service desk / repair original workshop serial"
    case .receiveWorkshopUnit: "Enmadan workshop / receive serviced original and pay quote"
    case .cancelWorkshopBooking: "Workshop booking / cancel before pickup"
    case .cancelHeldWorkshopUnit: "Workshop serial / cancel and retain original return custody"
    case .returnWorkshopUnit: "Enmadan workshop / receive cancelled original serial"
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
  let utilityRevision: UInt64?
  let capacityRevision: UInt64?
  let capacityUnit: UUID?
  let clinicQuote: NativeInductionClinicQuote?
  let issues: [String]
  var clinicReference: UUID? = nil
  var clinicWindow: NativeInductionCapacityReservation? = nil
  var clinicChildRevision: UInt64? = nil
  var workshopReference: UUID? = nil
  var workshopQuote: NativeInductionWorkshopQuote? = nil
  var workshopWindow: NativeInductionCapacityReservation? = nil
  var workshopChildRevision: UInt64? = nil
  let reviewToken = UUID()
  var allowed: Bool { action != .progress && issues.isEmpty }
}

extension Game {
  var wayfarerInductionRows: [ContractBoardRow] {
    guard !isMissionTrial, wayfarerInductionPack != nil else { return [] }
    if let state = wayfarerInductionMission?.savedWayfarerInduction,
      systemIdentity == NativeWayfarerInduction.source, state.utilityReception != nil,
      state.charterChoice == nil
    {
      return [NativeWayfarerInductionAction.pooledCharter, .protectedCharter].map { action in
        .init(
          board: action.key, offer: nil, title: action.title,
          reason: wayfarerInductionReview(action).issues.first, wayfarerInduction: action)
      }
    }
    let operatorRows = inductionCharterOperatorRows + inductionClinicRows + inductionWorkshopRows
    if !operatorRows.isEmpty { return operatorRows }
    let action: NativeWayfarerInductionAction
    if let state = wayfarerInductionMission?.savedWayfarerInduction {
      if systemIdentity == NativeWayfarerInduction.source, state.charterChoice != nil,
        state.charterCapacity == nil
      {
        action = .allocateCharterCapacity
      } else if systemIdentity == NativeInductionUtilitySource.location,
        state.rescueReception != nil,
        inductionUtilityChild == nil
      {
        action = .authorizeUtility
      } else if systemIdentity == NativeInductionUtilitySource.location,
        state.rescueReception != nil,
        state.utilityReception == nil, inductionUtilityChild != nil
      {
        action = .receiveUtility
      } else if systemIdentity == NativeInductionCrewLogSource.location,
        state.crewLog != nil, state.crewLogLoss == nil,
        inductionCrewLogChild?.savedNativeCrewLog?.rescueFuel == nil,
        inductionCrewLogChild != nil
      {
        action = .fundRescueLaunch
      } else if systemIdentity == NativeInductionCrewLogSource.location,
        state.crewLog != nil, state.crewLogLoss == nil,
        inductionCrewLogChild?.savedNativeCrewLog?.rescueFuel != nil,
        inductionCrewLogChild?.savedNativeCrewLog?.flight == nil
      {
        action = .startRescueFlight
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
    _ action: NativeWayfarerInductionAction, capacityUnit: UUID? = nil,
    prepareClinicQuote: Bool = false, clinicReference: UUID? = nil,
    prepareWorkshopQuote: Bool = false, workshopReference: UUID? = nil
  ) -> NativeWayfarerInductionReview {
    let unit =
      action.isCapacityRelease
      ? (capacityUnit ?? contractBoard.selected?.inductionCapacityUnit) : nil
    let workshopReference = workshopReference ?? contractBoard.selected?.inductionWorkshopReference
    let workshopQuote =
      prepareWorkshopQuote && (action == .viewWorkshopStock || action == .acceptWorkshopUnit)
      ? try? inductionWorkshopReadOnlyQuote(unit: workshopReference) : nil
    let workshopWindow = workshopQuote.flatMap { try? inductionWorkshopWindow(quote: $0) }
    let clinicReference = clinicReference ?? contractBoard.selected?.inductionClinicReference
    let clinicQuote =
      prepareClinicQuote && (action == .viewClinicStock || action == .acceptClinicSample)
      ? try? inductionClinicReadOnlyQuote(unit: clinicReference) : nil
    let clinicWindow = clinicQuote.flatMap { try? inductionClinicWindow(quote: $0) }
    var actionIssues =
      action == .progress
      ? [] : inductionActionIssues(action, trade: nil, capacityUnit: unit)
    if action == .acceptClinicSample {
      actionIssues += inductionClinicBookingIssues(unit: clinicReference)
      if prepareClinicQuote && (clinicQuote == nil || clinicWindow == nil) {
        actionIssues.append(
          "No current reachable quote or eligible clinic-owned window; review again after capacity release or navigation changes."
        )
      }
    }
    if action == .cancelClinicSample {
      actionIssues += inductionClinicCancellationIssues(instance: clinicReference)
    }
    if action.isClinicCustodyAction {
      actionIssues += inductionClinicCustodyIssues(action, instance: clinicReference)
    }
    if action.isWorkshopAction {
      actionIssues += inductionWorkshopActionIssues(action, reference: workshopReference)
      if action == .acceptWorkshopUnit && prepareWorkshopQuote
        && (workshopQuote == nil || workshopWindow == nil)
      {
        actionIssues.append(
          "No current reachable complete workshop quote or eligible same-owner window; review again."
        )
      }
    }
    let trade =
      action == .accept
      ? commander.equipmentOwnerID.flatMap {
        NativeInductionTradeEvidence.first(in: commander.scriptState, owner: $0)
      } : wayfarerInductionMission?.savedWayfarerInduction?.permission.trade
    if action == .accept {
      actionIssues = inductionActionIssues(action, trade: trade, capacityUnit: unit)
    }
    return .init(
      action: action, dock: commander.nativeStations?.currentMainDock,
      carrier: commander.hullInstanceID, inventoryRevision: commander.equipmentInventory?.revision,
      trade: trade, epoch: nativeStationRuntimeEpoch,
      missionRevision: wayfarerInductionMission?.revision,
      arkRevision: wayfarerInductionMission?.savedWayfarerInduction?.ark.flatMap {
        commander.scriptState.instances[$0.job]?.revision
      },
      rescueRevision: inductionCrewLogChild?.revision,
      utilityRevision: inductionUtilityChild?.revision,
      capacityRevision: wayfarerInductionMission?.savedWayfarerInduction?.charterCapacity?.revision,
      capacityUnit: unit,
      clinicQuote: clinicQuote,
      issues: actionIssues, clinicReference: clinicReference, clinicWindow: clinicWindow,
      clinicChildRevision: clinicReference.flatMap {
        commander.scriptState.instances[$0]?.revision
      },
      workshopReference: workshopReference, workshopQuote: workshopQuote,
      workshopWindow: workshopWindow,
      workshopChildRevision: workshopReference.flatMap {
        commander.scriptState.instances[$0]?.revision
      }
    )
  }

  private func inductionActionIssues(
    _ action: NativeWayfarerInductionAction, trade: NativeInductionTradeEvidence?,
    capacityUnit: UUID?
  ) -> [String] {
    var issues: [String] = []
    if isMissionTrial { issues.append("Return to your commander before starting this induction.") }
    if paused { issues.append("Resume before confirming the induction action.") }
    let expected = action.station
    if !nativeMainStationDockEvidenceIsCurrent
      || (!action.isInductionAnyBerthAction && systemIdentity != expected)
    {
      issues.append("Use the actual registered main orbital berth for " + action.title + ".")
    }
    if !scriptDurabilityAvailable { issues.append("Choose a writable commander save first.") }
    if wayfarerInductionPack == nil { issues.append("Restore the approved Exchange opening.") }
    if commander.hullInstanceID == nil || commander.equipmentInventory == nil {
      issues.append("The actual owned carrier and fitting must be available.")
    }
    if action != .receive && action != .service && action != .launchArk && action != .receiveArk
      && action != .replaceArk && action != .fundRescueLaunch && action != .startRescueFlight
      && action != .receiveRescue && action != .authorizeUtility && action != .receiveUtility
      && action.charterPolicy == nil && action != .allocateCharterCapacity
      && action.capacityOperator == nil && !action.isClinicStockAction && !action.isWorkshopAction,
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
    case .startRescueFlight: issues += inductionRescueFlightIssues()
    case .receiveRescue: issues += inductionRescueReceivingIssues()
    case .authorizeUtility: issues += inductionUtilityAuthorizationIssues()
    case .receiveUtility: issues += inductionUtilityReceivingIssues()
    case .pooledCharter, .protectedCharter: issues += inductionCharterChoiceIssues()
    case .allocateCharterCapacity: issues += inductionCapacityAllocationIssues()
    case .clinicConsent, .workshopConsent, .seedConsent, .releaseClinicCapacity,
      .releaseWorkshopCapacity, .releaseSeedCapacity:
      issues += inductionCharterOperatorIssues(action, unit: capacityUnit)
    case .issueClinicStock: issues += inductionClinicSourceIssues()
    case .viewClinicStock:
      issues += [
        "Read-only original source quote; use the separate booking, pickup and custody rows."
      ]
    case .acceptClinicSample, .cancelClinicSample, .pickupClinicSample, .receiveClinicSample,
      .cancelHeldClinicSample, .returnClinicSample, .retryClinicExpiry:
      break
    case .issueWorkshopStock, .viewWorkshopStock, .acceptWorkshopUnit, .pickupWorkshopUnit,
      .serviceWorkshopUnit, .receiveWorkshopUnit, .cancelWorkshopBooking, .cancelHeldWorkshopUnit,
      .returnWorkshopUnit:
      break
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
    let current = wayfarerInductionReview(
      quote.action, prepareClinicQuote: quote.action == .acceptClinicSample,
      prepareWorkshopQuote: quote.action == .acceptWorkshopUnit)
    guard quote.allowed, current.allowed, quote.dock == current.dock,
      quote.carrier == current.carrier, quote.inventoryRevision == current.inventoryRevision,
      quote.trade == current.trade, quote.epoch == current.epoch,
      quote.missionRevision == current.missionRevision, quote.arkRevision == current.arkRevision,
      quote.rescueRevision == current.rescueRevision,
      quote.utilityRevision == current.utilityRevision,
      quote.capacityRevision == current.capacityRevision,
      quote.capacityUnit == current.capacityUnit,
      quote.clinicReference == current.clinicReference,
      quote.clinicChildRevision == current.clinicChildRevision,
      quote.workshopReference == current.workshopReference,
      quote.workshopChildRevision == current.workshopChildRevision,
      quote.workshopWindow == current.workshopWindow,
      quote.workshopQuote?.offer.id == current.workshopQuote?.offer.id,
      quote.clinicWindow == current.clinicWindow,
      quote.clinicQuote?.offer.id == current.clinicQuote?.offer.id,
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
    if quote.action == .startRescueFlight {
      try candidate.confirmInductionRescueFlight(dock: dock, carrier: carrier, revision: revision)
    }
    if quote.action == .receiveRescue {
      try candidate.confirmInductionRescueReceiving(
        dock: dock, carrier: carrier, revision: revision)
    }
    if quote.action == .authorizeUtility {
      try candidate.confirmInductionUtilityAuthorization(
        dock: dock, carrier: carrier, revision: revision)
    }
    if quote.action == .receiveUtility {
      try candidate.confirmInductionUtilityReceiving(
        dock: dock, carrier: carrier, revision: revision)
    }
    if let policy = quote.action.charterPolicy {
      try candidate.confirmInductionCharterChoice(
        policy, dock: dock, carrier: carrier, revision: revision)
    }
    if quote.action == .allocateCharterCapacity {
      try candidate.confirmInductionCapacityAllocation(
        dock: dock, carrier: carrier, revision: revision)
    }
    if let operatorID = quote.action.capacityOperator {
      if quote.action.isCapacityRelease, let unit = quote.capacityUnit {
        try candidate.confirmInductionCharterRelease(
          operatorID, unit: unit, dock: dock, carrier: carrier, revision: revision)
      } else {
        try candidate.confirmInductionCharterConsent(
          operatorID, dock: dock, carrier: carrier, revision: revision)
      }
    }
    if quote.action == .issueClinicStock {
      try candidate.confirmInductionClinicIssue(dock: dock, carrier: carrier, revision: revision)
    }
    if quote.action == .acceptClinicSample {
      guard let clinic = current.clinicQuote, let window = current.clinicWindow else {
        throw SaveError.invalidCommander
      }
      try candidate.confirmInductionClinicBooking(quote: clinic, window: window)
    }
    if quote.action == .cancelClinicSample {
      guard let instance = current.clinicReference else { throw SaveError.invalidCommander }
      try candidate.closeInductionClinicBooking(instance: instance)
    }
    if quote.action.isClinicCustodyAction {
      guard let id = current.clinicReference else { throw SaveError.invalidCommander }
      switch quote.action {
      case .pickupClinicSample: try candidate.confirmInductionClinicPickup(id)
      case .receiveClinicSample: try candidate.finishInductionClinicCustody(id)
      case .cancelHeldClinicSample: try candidate.confirmInductionClinicHeldCancellation(id)
      case .returnClinicSample: try candidate.finishInductionClinicCustody(id, returning: true)
      case .retryClinicExpiry: try candidate.retryInductionClinicExpiry(id)
      default: throw SaveError.invalidCommander
      }
    }
    if quote.action.isWorkshopAction {
      switch quote.action {
      case .issueWorkshopStock:
        try candidate.confirmInductionWorkshopIssue(dock: dock, carrier: carrier, fit: revision)
      case .acceptWorkshopUnit:
        guard let workshop = current.workshopQuote, let window = current.workshopWindow else {
          throw SaveError.invalidCommander
        }
        try candidate.confirmInductionWorkshopBooking(quote: workshop, window: window)
      default:
        guard let id = current.workshopReference else { throw SaveError.invalidCommander }
        switch quote.action {
        case .pickupWorkshopUnit: try candidate.confirmInductionWorkshopPickup(id)
        case .serviceWorkshopUnit: try candidate.confirmInductionWorkshopService(id)
        case .receiveWorkshopUnit: try candidate.finishInductionWorkshop(id, kind: .returned)
        case .cancelWorkshopBooking:
          try candidate.finishInductionWorkshop(id, kind: .cancelledBeforePickup)
        case .cancelHeldWorkshopUnit: try candidate.confirmInductionWorkshopHeldCancellation(id)
        case .returnWorkshopUnit: try candidate.finishInductionWorkshop(id, kind: .cancelledHeld)
        default: throw SaveError.invalidCommander
        }
      }
    }
    self = candidate
  }

  func wayfarerInductionDetail() -> [String] {
    if (contractBoard.wayfarerInductionQuote?.action ?? contractBoard.selected?.wayfarerInduction)?
      .isWorkshopAction == true
    {
      return inductionWorkshopDetail
    }
    if (contractBoard.wayfarerInductionQuote?.action ?? contractBoard.selected?.wayfarerInduction)?
      .isClinicStockAction == true
    {
      return inductionClinicDetail
    }
    if (contractBoard.wayfarerInductionQuote?.action ?? contractBoard.selected?.wayfarerInduction)?
      .charterPolicy != nil
      || (contractBoard.wayfarerInductionQuote?.action ?? contractBoard.selected?.wayfarerInduction)
        == .allocateCharterCapacity
      || (contractBoard.wayfarerInductionQuote?.action ?? contractBoard.selected?.wayfarerInduction)?
        .capacityOperator != nil
    {
      return inductionCharterDetail
    }
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
      "The registered ark uses actual native aperture docking and its own custodian escrow for needed-hop fuel. Each real main station has one finite 100-LY custodian-service reserve shared by seed arks and the original rescue launch. Saving, revisiting or reopening never refills stock or funds; actual Lareria receiving and original key return need their separate Confirm review.",
      "Original escort terms: one custodian Haflinger, forty unique seed tonnes and six living crew, with its own finite 1000 CR fuel escrow. Its authored tank is 13 LY, drive 9 LY per hop and spool 12 seconds; your separate original vault key occupies one tonne.",
      "One initial reserve holds a distinct Haflinger, forty distinct seed tonnes, six distinct crew and a separate 1000 CR fuel issue. Only proved original-ark destruction and fresh Enlirin custodian consent can release it once. The same original key must still be aboard. Unused prior escrow returns to its custodian; no payment or progress is awarded.",
      "The destroyed hull, seed and crew remain lost. Station fuel stock stays depleted. After the single reserve is consumed, no further launch or new key is available without a separate real authored source.",
      "These stages pay nothing and grant no accreditation or clue. "
        + NativeWayfarerInduction.laterStages,
    ]
    lines += inductionCharterDetail
    if let status = inductionCrewLogStatus { lines.append(status) }
    if let status = inductionUtilitySourceStatus { lines.append(status) }
    if let state = inductionCrewLogChild?.savedNativeCrewLog {
      if let account = state.rescueFuel {
        lines.append(
          String(
            format:
              "Original rescue launch NPC fuel escrow: %.1f CR remaining / initial1000CR. Source SH029: 13LY tank, 9LY drive, 12s spool. This is separate from player cash and both seed-ark accounts.",
            Double(account.remainingCredits) / 10))
        lines.append(
          "Real native route hops use the same launch's retained drive/fuel after separate Cevilis escort review. The original launch uses native aperture docking and its own paid needed-hop fuel from the same persistent station reserve as seed arks. Enmadan receiving needs that same launch actually berthed with both original crew alive and its original recorder on your actual docked carrier. Confirm returns people, recorder and unused custodian funds together; no extra station stock or arrival fuel is granted."
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
    if let flight = inductionCrewLogChild?.savedNativeCrewLog?.flight {
      let route = flight.authorization.route.worldKeys.compactMap {
        try? Universe.originalWorlds.world(key: $0).name
      }
      lines.append("Original marked-launch route: " + route.joined(separator: " > "))
      lines.append(
        String(
          format:
            "Actual source fuel at escort consent: %.1fLY; full tank13LY, drive9LY/hop. Native departure alone spends fuel. The two original crew stay aboard their same marked launch.",
          flight.authorization.initialFuelLY))
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
