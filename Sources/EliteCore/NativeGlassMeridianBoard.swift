import Foundation

enum NativeGlassMeridianAction: String, Sendable {
  case accept, progress
  var key: String { NativeGlassMeridian.stateID + "/" + rawValue }
  var title: String {
    self == .accept
      ? "Venn / review Glass Meridian commission" : "Venn / current lane investigation"
  }
}
struct NativeGlassMeridianReview: Sendable {
  let action: NativeGlassMeridianAction
  let dock: NativeMainStationDockReceipt?
  let carrier: UUID?
  let inventoryRevision: UInt64?
  let epoch: UUID
  let issues: [String]
  let reviewToken = UUID()
  var allowed: Bool { action == .accept && issues.isEmpty }
}

extension Game {
  var glassMeridianRows: [ContractBoardRow] {
    guard glassMeridianPack != nil else { return [] }
    let action: NativeGlassMeridianAction = glassMeridianMission == nil ? .accept : .progress
    guard action != .accept || contractStation == NativeGlassMeridian.source else { return [] }
    return [
      .init(
        board: action.key, offer: nil, title: action.title,
        reason: glassMeridianReview(action).issues.first, glassMeridian: action)
    ]
  }
  func glassMeridianReview(_ action: NativeGlassMeridianAction) -> NativeGlassMeridianReview {
    if action == .progress {
      return .init(
        action: action, dock: commander.nativeStations?.currentMainDock,
        carrier: commander.hullInstanceID,
        inventoryRevision: commander.equipmentInventory?.revision,
        epoch: nativeStationRuntimeEpoch, issues: [])
    }
    var issues: [String] = []
    if paused { issues.append("Resume before confirming the commission.") }
    if !nativeMainStationDockEvidenceIsCurrent || contractStation != NativeGlassMeridian.source {
      issues.append("Use Captain Venn's actual Avenor main orbital berth.")
    }
    if !scriptDurabilityAvailable { issues.append("Choose a writable commander save first.") }
    if glassMeridianPack == nil { issues.append("Restore the approved Glass Meridian opening.") }
    if action == .accept {
      if glassMeridianMission != nil {
        issues.append("This commander already has the investigation.")
      }
      if commander.scriptState.instances.count >= 128 {
        issues.append("The mission record capacity is full.")
      }
      let visited = commander.nativeStations?.mainStations ?? []
      if Set(visited.map(\.system)).count < 3 {
        issues.append("Visit three different actual systems before accepting.")
      }
      if NativeGlassMeridian.identifiedShips(commander.scriptState.savedFleetDiscovery).count < 2 {
        issues.append(
          "Identify two real catalogue ship types with fitted Identification targeting.")
      }
      if commander.hullInstanceID == nil || commander.equipmentInventory == nil {
        issues.append("The actual owned carrier and fitting must be available.")
      }
    }
    return .init(
      action: action, dock: commander.nativeStations?.currentMainDock,
      carrier: commander.hullInstanceID, inventoryRevision: commander.equipmentInventory?.revision,
      epoch: nativeStationRuntimeEpoch, issues: issues)
  }

  mutating func confirmGlassMeridian(_ quote: NativeGlassMeridianReview) throws {
    let current = glassMeridianReview(quote.action)
    guard quote.allowed, current.allowed, quote.dock == current.dock,
      quote.carrier == current.carrier, quote.inventoryRevision == current.inventoryRevision,
      quote.epoch == current.epoch, let pack = glassMeridianPack,
      let owner = commander.equipmentOwnerID, let dock = current.dock,
      let hull = current.carrier, let revision = current.inventoryRevision,
      let inventory = try? commander.purchaseSnapshot(),
      let discovery = commander.scriptState.savedFleetDiscovery
    else {
      throw MissionPackError("The commission, actual berth or fitting changed; review again.")
    }
    let visited = commander.nativeStations?.mainStations ?? []
    let identified = NativeGlassMeridian.identifiedShips(discovery)
    guard NativeGlassMeridian.qualified(visited: visited, identified: identified, owner: owner),
      discovery.owner == owner
    else { throw SaveError.invalidCommander }
    let missionID = ScriptIdentity.uuid("glass-meridian-commission-v1:\(owner)")
    var candidate = self
    var mission = ScriptInstance(
      id: missionID, definition: NativeGlassMeridian.stateID,
      version: NativeGlassMeridian.version, digest: pack.digest)
    mission.savedGlassMeridian = .init(
      permission: .init(
        mission: missionID,
        operation: try NativeGlassMeridian.operation(mission: missionID, owner: owner, dock: dock),
        owner: owner, dock: dock, carrier: hull, inventoryRevision: revision, fit: inventory.items,
        visited: visited.sorted { $0.key < $1.key }, identified: identified,
        physicalTime: commander.flightSimulation.physicalTime))
    mission.milestones = [0]
    candidate.commander.scriptState.instances[missionID] = mission
    candidate.emitScriptEvent("mission.accepted", only: missionID)
    candidate.notify("VENN COMMISSION ACCEPTED - READ BOTH RENAS CLOCKS")
    self = candidate
  }

  func glassMeridianDetail() -> [String] {
    var lines = [
      "VENN: Three crews nearly died without either pilot making a navigation error.",
      "I need measurements, not a convenient suspect. Your survey data occupies no cargo hold.",
      "At Renas, select sedan-clock-a or sedan-clock-b; either order is valid.",
      "Use a fitted targeting computer in front view, within 2 degrees and 250-1500 surface units.",
      "Keep clear nearest-hit sight for 12 continuous native seconds. Pause freezes the reading.",
      "Completed target readings survive saves. Interrupted or loaded unfinished dwell restarts.",
      "After both clocks, travel to Navidor to recover the original flight recorder. No payment or final clue is available.",
    ]
    if let state = glassMeridianMission?.savedGlassMeridian {
      for ordinal in 0..<2 {
        let done = state.readings.contains { $0.reading.ordinal == ordinal }
        lines.append(NativeGlassMeridian.targets[ordinal] + (done ? ": verified" : ": unread"))
      }
      if state.readings.count == 2 {
        lines.append("Navidor: disabled Harrier, 25km above the planet surface toward the star.")
        lines.append(
          "The original recorder is detached 80m to the Harrier's right; fitted Fuel Scoops recover it on a slow, centred underside approach."
        )
        lines.append(
          "It occupies 8kg protected cargo, combined with actual stored mass before tonne rounding."
        )
        lines.append(
          "Destruction or loss of the original ends this attempt; changing visits never replaces it."
        )
        if state.surveyor?.loss != nil {
          lines.append("Original recorder lost: this attempt has failed.")
        } else if state.surveyor?.held == true {
          lines.append("Original recorder aboard. Stage four audit remains unavailable.")
        } else {
          lines.append(NativeGlassMeridian.laterStages)
        }
      }
    }
    lines += (contractBoard.glassMeridianQuote ?? glassMeridianReview(.accept)).issues
    return lines
  }
}
