import Foundation

/// Presentation identities never replace a live native operation quote.
enum WayfarerRepairLoopBoardAction: Sendable, Equatable {
  case pickup(source: String, unit: UUID)
  case service(UUID)
  case receive(UUID)
  case unavailable

  var instance: UUID? {
    switch self {
    case .service(let id), .receive(let id): return id
    default: return nil
    }
  }
  var key: String {
    switch self {
    case .pickup(let source, let unit): return source + "/" + unit.uuidString
    case .service(let id): return id.uuidString + "/service"
    case .receive(let id): return id.uuidString + "/return"
    case .unavailable: return "unavailable"
    }
  }
}

struct WayfarerRepairLoopBoardRow: Sendable, Equatable {
  let digest: String
  let action: WayfarerRepairLoopBoardAction
  var key: String { "repair-loop/" + digest + "/" + action.key }
}

struct WayfarerRepairLoopBoardReview: Sendable {
  let row: WayfarerRepairLoopBoardRow
  let offer: WayfarerRepairLoopOffer?
  let operation: WayfarerRepairLoopStageQuote?
  let epoch: UUID
  let dock: NativeMainStationDockReceipt?
  let issues: [String]
  let reviewToken = UUID()
  var allowed: Bool { issues.isEmpty }
}

extension Game {
  mutating func prepareWayfarerRepairLoopBoard(failures: inout [String: String]) {
    for pack in scriptPacks {
      guard let terms = pack.manifest.repairLoop,
        terms.source.galaxy == commander.galaxy, terms.source.system == commander.system
      else { continue }
      do { _ = try initializeWayfarerRepairLoopStock(packDigest: pack.digest) } catch {
        failures[pack.digest] = String(error.localizedDescription.prefix(512))
      }
    }
  }

  func wayfarerRepairLoopRows(failures: [String: String]) -> [ContractBoardRow] {
    guard dockedAtMainStation else { return [] }
    var rows: [ContractBoardRow] = []
    for pack in scriptPacks {
      guard let terms = pack.manifest.repairLoop else { continue }
      let source = commander.equipmentOwnerID.map {
        WayfarerRepairLoopStockSource.identity(owner: $0, terms: terms).uuidString
      }
      var action = WayfarerRepairLoopBoardAction.unavailable
      if let source,
        let stock = commander.scriptState.savedWayfarerRepairLoopStock?.sources[source],
        let unit = stock.units.values.filter({ $0.status == .available })
          .sorted(by: { $0.id.uuidString < $1.id.uuidString }).first
      {
        action = .pickup(source: source, unit: unit.id)
      }
      let row = WayfarerRepairLoopBoardRow(digest: pack.digest, action: action)
      rows.append(
        .init(
          board: row.key, offer: nil, title: pack.manifest.mission.title,
          reason: failures[pack.digest] ?? wayfarerRepairLoopReview(row).issues.first,
          repairLoop: row))
    }
    for state in commander.scriptState.instances.values.sorted(by: {
      $0.id.uuidString < $1.id.uuidString
    }) {
      guard state.outcome == .active, let custody = state.savedWayfarerRepairLoop else { continue }
      let row = WayfarerRepairLoopBoardRow(
        digest: state.digest,
        action: custody.service == nil ? .service(state.id) : .receive(state.id))
      rows.append(
        .init(
          board: row.key, offer: nil,
          title: custody.service == nil
            ? "Repair loop: service original unit" : "Repair loop: return to owner",
          reason: wayfarerRepairLoopReview(row).issues.first, repairLoop: row))
    }
    return rows
  }

  func wayfarerRepairLoopReview(_ row: WayfarerRepairLoopBoardRow) -> WayfarerRepairLoopBoardReview
  {
    var issues: [String] = []
    var offer: WayfarerRepairLoopOffer?
    var operation: WayfarerRepairLoopStageQuote?
    do {
      guard scriptDurabilityAvailable else {
        throw MissionPackError("Choose a writable commander save first.")
      }
      guard let pack = scriptPacks.first(where: { $0.digest == row.digest }),
        let terms = pack.manifest.repairLoop, scriptUnavailable(pack) == nil
      else { throw MissionPackError("Restore the original repair-loop provider.") }
      switch row.action {
      case .pickup(let source, let unit):
        guard
          commander.scriptState.savedWayfarerRepairLoopStock?.sources[source]?.digest == row.digest
        else {
          throw MissionPackError("Original source terms changed; restore the exact provider.")
        }
        let current = try wayfarerRepairLoopQuote(sourceID: source)
        guard current.stockUnit == unit else {
          throw MissionPackError("Original stock changed. Review the current failed unit.")
        }
        offer = current
      case .service(let id), .receive(let id):
        guard let state = commander.scriptState.instances[id], state.digest == row.digest,
          state.outcome == .active, state.savedWayfarerRepairLoop?.definition == terms
        else { throw MissionPackError("Restore this original unit and its exact native service.") }
        operation = try wayfarerRepairLoopStageQuote(id, returning: row.action == .receive(id))
      case .unavailable:
        if terms.source.galaxy != commander.galaxy || terms.source.system != commander.system {
          throw MissionPackError(
            "Collect at Cedamar main orbital station; return to the same owner.")
        }
        throw MissionPackError(
          "No original failed unit remains available. This batch never replenishes.")
      }
    } catch { issues.append(String(error.localizedDescription.prefix(512))) }
    return .init(
      row: row, offer: offer, operation: operation, epoch: ecmControl.epoch,
      dock: commander.nativeStations?.currentMainDock, issues: issues)
  }

  mutating func confirmWayfarerRepairLoopBoard(_ review: WayfarerRepairLoopBoardReview) throws {
    let current = wayfarerRepairLoopReview(review.row)
    guard review.allowed, current.allowed, review.epoch == current.epoch,
      review.dock == current.dock, review.offer?.id == current.offer?.id,
      review.operation?.id == current.operation?.id
    else { throw MissionPackError("The service context changed. Review the current native terms.") }
    var candidate = self
    try candidate.performWayfarerRepairLoopBoard(review)
    self = candidate
  }

  private mutating func performWayfarerRepairLoopBoard(_ review: WayfarerRepairLoopBoardReview)
    throws
  {
    switch review.row.action {
    case .pickup(let source, _):
      guard let offer = review.offer else { throw SaveError.invalidCommander }
      _ = try pickUpWayfarerRepairLoop(sourceID: source, quotedOfferID: offer.id)
      notify("ORIGINAL FAILED UNIT ABOARD - TRANSPORT ONLY - CELALEN WORKSHOP")
    case .service(let id):
      guard let operation = review.operation else { throw SaveError.invalidCommander }
      try serviceWayfarerRepairLoop(id, quotedOperationID: operation.id)
      notify("ORIGINAL UNIT REPAIRED - RETURN SAME SERIAL TO CEDAMAR OWNER")
    case .receive(let id):
      guard let operation = review.operation else { throw SaveError.invalidCommander }
      let first =
        commander.scriptState.savedClueJournal?.awards[WayfarerRepairLoopDefinition.stateID] == nil
      try returnWayfarerRepairLoop(id, quotedOperationID: operation.id)
      if first,
        commander.scriptState.savedClueJournal?.awards[WayfarerRepairLoopDefinition.stateID] != nil
      {
        notify(
          "SENN: This service is received and paid. Its older curved signature is copied to your journal; later work keeps the same clue rather than replacing another family."
        )
      } else {
        notify("ORIGINAL SERVICED UNIT RETURNED - 610 CR PAYMENT RECORDED")
      }
    case .unavailable: throw MissionPackError("This service is unavailable.")
    }
  }

  var wayfarerRepairLoopDetail: [String] {
    guard let row = contractBoard.selected?.repairLoop,
      let terms = scriptPacks.first(where: { $0.digest == row.digest })?.manifest.repairLoop
    else { return ["Restore the original repair-loop provider."] }
    let systems = Universe.systemsIncludingPlugh(number: terms.source.galaxy)
    var lines = [
      "Closed repair exchange - ordinary H0; no accreditation required.",
      "Original owner/source: Cedamar main orbital station.",
      "Registered workshop: Celalen main orbital station.",
      "Receiver: the SAME original Cedamar owner.",
      "Route: " + terms.route.map { systems[$0].name }.joined(separator: " -> "),
      "Protected unit: 2t; passenger berths: 0. Source-owned transport-only loan.",
      "Payment on original-owner return: 610.0 CR (430 + 90 per leg, two legs, H0).",
      "No deposit, workshop fee or deadline. Current fitted hold and fuel govern admission.",
      "Confirm pickup, Confirm actual repair at Celalen, then Confirm original-owner return.",
      "Repair changes the same failed unit; its native service receipt is required for return.",
      "No fitting, sale, release or personal use of this original unit, even after repair.",
      "Back/Esc changes nothing. Lost units pay nothing. Six original units; no replenishment.",
    ]
    if let offer = contractBoard.repairLoopQuote?.offer {
      lines.append("Original serial: " + offer.serial.uuidString + " / failed open relay.")
    }
    if let id = row.action.instance, let diagnosis = try? wayfarerRepairLoopDiagnostic(id) {
      lines.append(diagnosis)
    }
    if case .pickup(let source, _) = row.action,
      let stock = commander.scriptState.savedWayfarerRepairLoopStock?.sources[source]
    {
      lines.append(
        "Available original failed units: \(stock.units.values.filter { $0.status == .available }.count)."
      )
    }
    lines +=
      contractBoard.repairLoopQuote?.issues ?? (contractBoard.selected?.reason.map { [$0] } ?? [])
    return lines
  }

  var wayfarerRepairLoopPageFacts: [String] {
    guard contractBoard.rows.contains(where: { $0.repairLoop != nil }) else { return [] }
    var fields = [
      ecmControl.epoch.uuidString,
      String(commander.nativeStations?.currentMainDock?.sequence ?? 0),
      String(commander.equipmentInventory?.revision ?? 0),
    ]
    for row in contractBoard.rows {
      guard let repair = row.repairLoop else { continue }
      fields += [repair.key, row.reason ?? ""]
      if let id = repair.action.instance, let state = commander.scriptState.instances[id] {
        fields += [
          String(state.revision), state.outcome.rawValue,
          (try? wayfarerRepairLoopDiagnostic(id)) ?? "unavailable",
        ]
      }
    }
    return fields
  }
}
