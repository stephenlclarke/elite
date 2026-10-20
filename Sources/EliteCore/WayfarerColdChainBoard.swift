import Foundation

/// Only UI identities. Native stock and custody remain the transaction authority.
enum WayfarerColdChainBoardAction: Sendable, Equatable {
  case pickup(source: String, unit: UUID)
  case objective(UUID)
  case receive(UUID)
  case retryExpiry(UUID)
  case unavailable

  var instance: UUID? {
    switch self {
    case .objective(let id), .receive(let id), .retryExpiry(let id): return id
    default: return nil
    }
  }
  var key: String {
    switch self {
    case .pickup(let source, let unit): return source + "/" + unit.uuidString
    case .objective(let id): return id.uuidString + "/objective"
    case .receive(let id): return id.uuidString + "/receive"
    case .retryExpiry(let id): return id.uuidString + "/expiry"
    case .unavailable: return "unavailable"
    }
  }
}

struct WayfarerColdChainBoardRow: Sendable, Equatable {
  let digest: String
  let action: WayfarerColdChainBoardAction
  var key: String { "wayfarer/" + digest + "/" + action.key }
}

struct WayfarerColdChainBoardReview: Sendable {
  let row: WayfarerColdChainBoardRow
  let offer: WayfarerColdChainOffer?
  let epoch: UUID
  let dock: NativeMainStationDockReceipt?
  let revision: UInt64?
  let issues: [String]
  let reviewToken = UUID()
  var allowed: Bool { issues.isEmpty }
}

extension Game {
  mutating func prepareWayfarerColdChainBoard(failures: inout [String: String]) {
    for pack in scriptPacks {
      guard let terms = pack.manifest.coldChain,
        terms.source.galaxy == commander.galaxy, terms.source.system == commander.system
      else { continue }
      do { _ = try initializeWayfarerColdChainStock(packDigest: pack.digest) } catch {
        failures[pack.digest] = String(error.localizedDescription.prefix(512))
      }
    }
  }

  func wayfarerColdChainRows(failures: [String: String]) -> [ContractBoardRow] {
    guard dockedAtMainStation else { return [] }
    var rows: [ContractBoardRow] = []
    for pack in scriptPacks where pack.manifest.coldChain != nil {
      guard let terms = pack.manifest.coldChain else { continue }
      let source = commander.equipmentOwnerID.map {
        WayfarerColdChainStockSource.identity(owner: $0, terms: terms).uuidString
      }
      var action = WayfarerColdChainBoardAction.unavailable
      if let source, let stock = commander.scriptState.savedWayfarerColdChainStock?.sources[source],
        let unit = stock.units.values.filter({ $0.status == .available })
          .sorted(by: { $0.id.uuidString < $1.id.uuidString }).first
      {
        action = .pickup(source: source, unit: unit.id)
      }
      let row = WayfarerColdChainBoardRow(digest: pack.digest, action: action)
      let reason = failures[pack.digest] ?? wayfarerColdChainReview(row).issues.first
      rows.append(
        .init(
          board: row.key, offer: nil, title: pack.manifest.mission.title,
          reason: reason, coldChain: row))
    }
    for state in commander.scriptState.instances.values.sorted(by: {
      $0.id.uuidString < $1.id.uuidString
    }) {
      guard state.outcome == .active, let custody = state.savedWayfarerColdChain else { continue }
      let action: WayfarerColdChainBoardAction
      if state.suspension != nil,
        WayfarerColdChainSave.pendingExpiry(state, engine: commander.scriptState) != nil
      {
        action = .retryExpiry(state.id)
      } else {
        action = custody.objective == nil ? .objective(state.id) : .receive(state.id)
      }
      let row = WayfarerColdChainBoardRow(digest: state.digest, action: action)
      rows.append(
        .init(
          board: row.key, offer: nil,
          title: (custody.definition.isSeedTransfer
            ? "Seed-bank consignment: " : "Cold-chain sample: ")
            + (custody.objective == nil ? "verify arrival" : "receive and pay"),
          reason: wayfarerColdChainReview(row).issues.first, coldChain: row))
    }
    return rows
  }

  func wayfarerColdChainReview(_ row: WayfarerColdChainBoardRow) -> WayfarerColdChainBoardReview {
    var issues: [String] = []
    var offer: WayfarerColdChainOffer?
    let dock = commander.nativeStations?.currentMainDock
    if !scriptDurabilityAvailable { issues.append("Choose a writable commander save first.") }
    do {
      guard let pack = scriptPacks.first(where: { $0.digest == row.digest }),
        let terms = pack.manifest.coldChain, scriptUnavailable(pack) == nil
      else {
        throw MissionPackError("Restore the original native cold-chain provider.")
      }
      guard terms.hazardTier == 0 else {
        throw MissionPackError("Advanced or hazardous services require verified accreditation.")
      }
      switch row.action {
      case .pickup(let source, let unit):
        guard
          commander.scriptState.savedWayfarerColdChainStock?.sources[source]?.digest == row.digest
        else {
          throw MissionPackError("Original source terms changed; restore the exact provider.")
        }
        let current = try wayfarerColdChainQuote(sourceID: source)
        guard current.stockUnit == unit else {
          throw MissionPackError(
            "Original available stock changed. Review the current consignment.")
        }
        offer = current
        guard let occupied = commander.checkedCargoTonnes,
          terms.tonnes <= commander.standardCargoCapacity,
          occupied <= commander.standardCargoCapacity - terms.tonnes,
          commander.scriptState.instances.count < 128
        else {
          throw MissionPackError(
            "\(terms.tonnes) actual free cargo tonnes and mission space are required.")
        }
      case .objective(let id), .receive(let id):
        guard let state = commander.scriptState.instances[id], state.digest == row.digest,
          state.outcome == .active, state.suspension == nil,
          let custody = state.savedWayfarerColdChain,
          let pack = scriptPacks.first(where: { $0.digest == row.digest }),
          pack.manifest.coldChain == custody.definition, scriptUnavailable(pack) == nil,
          !paused, docked, nativeMainStationDockEvidenceIsCurrent,
          let dock, dock.commanderOwner == custody.owner,
          commander.scriptState.stationResources[dock.station.key]?.destroyed != true
        else {
          throw MissionPackError("Restore the original service at its actual living station.")
        }
        guard try wayfarerColdChainDisplayRemaining(id) > 0 else {
          throw MissionPackError("The original sample integrity budget is exhausted.")
        }
        if case .objective = row.action {
          guard custody.objective == nil, custody.definition.objective.matches(dock.station),
            dock.sequence > custody.issue.dock.sequence
          else {
            throw MissionPackError("Bring this sample to its declared objective after pickup.")
          }
        } else {
          guard let objective = custody.objective,
            custody.definition.receiver.matches(dock.station),
            dock.sequence >= objective.dock.sequence,
            commander.credits <= 4_294_967_295 - custody.definition.rewardNative
          else {
            throw MissionPackError("Verify the objective, then use the actual named receiver.")
          }
        }
      case .retryExpiry(let id):
        guard let state = commander.scriptState.instances[id], state.digest == row.digest,
          state.suspension != nil,
          WayfarerColdChainSave.pendingExpiry(state, engine: commander.scriptState) != nil
        else { throw MissionPackError("No original suspended expiry remains to record.") }
      case .unavailable:
        if let terms = scriptPacks.first(where: { $0.digest == row.digest })?.manifest.coldChain {
          if terms.source.galaxy != commander.galaxy || terms.source.system != commander.system {
            throw MissionPackError(
              "Collect at "
                + Universe.systemsIncludingPlugh(
                  number: terms.source.galaxy)[terms.source.system].name + " main orbital station.")
          }
        }
        throw MissionPackError(
          terms.isSeedTransfer
            ? "No original seed consignment remains available at this source."
            : "No original medical sample remains available at this source.")
      }
    } catch { issues.append(String(error.localizedDescription.prefix(512))) }
    return .init(
      row: row, offer: offer, epoch: ecmControl.epoch, dock: dock,
      revision: row.action.instance.flatMap { commander.scriptState.instances[$0]?.revision },
      issues: issues)
  }

  mutating func confirmWayfarerColdChainBoard(_ review: WayfarerColdChainBoardReview) throws {
    let current = wayfarerColdChainReview(review.row)
    guard review.allowed, current.allowed, review.epoch == current.epoch,
      review.dock == current.dock, review.revision == current.revision,
      review.offer?.id == current.offer?.id
    else { throw MissionPackError("The service context changed. Review the current native terms.") }
    // Native operations may throw after staging a receipt. Only this complete candidate escapes.
    var candidate = self
    try candidate.performWayfarerColdChainBoard(review)
    self = candidate
  }

  private mutating func performWayfarerColdChainBoard(_ review: WayfarerColdChainBoardReview) throws
  {
    switch review.row.action {
    case .pickup(let source, _):
      guard let offer = review.offer else { throw SaveError.invalidCommander }
      let id = try pickUpWayfarerColdChain(sourceID: source, quotedOfferID: offer.id)
      let seed =
        commander.scriptState.instances[id]?.savedWayfarerColdChain?.definition.isSeedTransfer
        == true
      notify(
        seed
          ? "SOURCE CUSTODIAN RELEASED ORIGINAL SEED LOT - FLIGHT INTEGRITY CLOCK STARTED"
          : "ORIGINAL SEALED SAMPLE ABOARD - FLIGHT INTEGRITY CLOCK STARTED")
    case .objective(let id):
      try confirmWayfarerColdChainObjective(id)
      let seed =
        commander.scriptState.instances[id]?.savedWayfarerColdChain?.definition.isSeedTransfer
        == true
      notify(
        seed
          ? "ORIGINAL SEED LOT ARRIVAL VERIFIED - CONFIRM RECEIVING CUSTODIAN"
          : "ORIGINAL SAMPLE ARRIVAL VERIFIED - CONFIRM RECEIVING HANDOFF")
    case .receive(let id):
      guard let custody = commander.scriptState.instances[id]?.savedWayfarerColdChain else {
        throw SaveError.invalidCommander
      }
      let family = custody.definition.instanceDefinition
      let first =
        commander.scriptState.savedClueJournal?.awards[
          family] == nil
      try receiveWayfarerColdChain(id)
      if first,
        commander.scriptState.savedClueJournal?.awards[
          family] != nil
      {
        notify(
          "SENN: This service is received and paid. Its older curved signature is copied to your journal; later work keeps the same clue rather than replacing another family."
        )
      } else {
        notify(
          custody.definition.isSeedTransfer
            ? "RECEIVING CUSTODIAN ACCEPTED ORIGINAL SEED LOT - QUOTED PAYMENT RECORDED"
            : "ORIGINAL SAMPLE RECEIVED - QUOTED PAYMENT RECORDED")
      }
    case .retryExpiry(let id):
      let seed =
        commander.scriptState.instances[id]?.savedWayfarerColdChain?.definition.isSeedTransfer
        == true
      try retryWayfarerColdChainExpiry(id)
      notify(
        seed
          ? "ORIGINAL SEED LOT SPOILAGE RECORDED - NO PAYMENT OR REPLACEMENT STOCK"
          : "ORIGINAL SAMPLE SPOILAGE RECORDED - NO PAYMENT OR REPLACEMENT STOCK")
    case .unavailable: throw MissionPackError("This service is unavailable.")
    }
  }

  // Presentation observes the existing immutable native integrity descriptor. Revalidating
  // the entire retained save under every row/page read exhausts the ordinary key stack.
  // Confirm still enters the unchanged native command and its full claim validation.
  private func wayfarerColdChainDisplayRemaining(_ id: UUID) throws -> Double {
    guard let state = commander.scriptState.instances[id],
      let custody = state.savedWayfarerColdChain,
      state.definition == custody.definition.instanceDefinition,
      custody.owner == commander.equipmentOwnerID
    else { throw SaveError.invalidCommander }
    if state.outcome != .active { return custody.integrity.remaining }
    if commander.scriptState.clock(.flight) >= custody.timer.due { return 0 }
    guard state.timers[custody.timer.id] == custody.timer else { throw SaveError.invalidCommander }
    return try custody.integrity.observing(
      .init(
        binding: custody.integrity.binding, timer: custody.timer, context: scriptEventContext(state)
      )
    ).remaining
  }

  var wayfarerColdChainDetail: [String] {
    guard let row = contractBoard.selected?.coldChain,
      let terms = scriptPacks.first(where: { $0.digest == row.digest })?.manifest.coldChain
    else { return ["Restore the original cold-chain pack to review this service."] }
    let systems = Universe.systemsIncludingPlugh(number: terms.source.galaxy)
    var lines = [
      terms.hazardTier == 0
        ? (terms.isSeedTransfer
          ? "Seed-bank transfer - ordinary variant; no accreditation required."
          : "Cold-chain clinic service - ordinary variant; no accreditation required.")
        : "Cold-chain clinic service - verified accreditation required for this variant.",
      "Source: " + systems[terms.source.system].name + " main orbital station.",
      "Objective: " + systems[terms.objective.system].name + " main orbital station.",
      "Receiver: " + systems[terms.receiver.system].name + " main orbital station.",
      "Route: " + terms.route.map { systems[$0].name }.joined(separator: " -> "),
      "Protected \(terms.isSeedTransfer ? "seed consignment" : "sample"): \(terms.tonnes)t; passenger berths: 0. Original source stock only.",
      String(
        format: "Payment at reception: %.1f CR; declared hazard tier %d.",
        Double(terms.rewardNative) / 10, terms.hazardTier),
      String(
        format: "Integrity budget after pickup: %.0f armed-flight seconds (%.0f minutes).",
        terms.flightAllowance, terms.flightAllowance / 60),
      "Pause stops flight time. Save/load preserves the original deadline.",
      "Confirm pickup, verify actual objective arrival, then Confirm the named receiver.",
      terms.isSeedTransfer
        ? "Back/Esc changes nothing. Failed/lost seed lots pay nothing and never replenish stock."
        : "Back/Esc changes nothing. Failed/lost samples pay nothing and never replenish stock.",
    ]
    if terms.isSeedTransfer {
      if let source = terms.sourceCustodian, let receiver = terms.receiverCustodian {
        lines += [
          "Source seed-bank custodian: " + source.name + " (" + source.id + ").",
          "Receiving seed-bank custodian: " + receiver.name + " (" + receiver.id + ").",
          "Confirm source release, verify arrival, then Confirm this distinct receiving custodian's acceptance.",
          "Custody is an actual institutional handoff; no passenger berth or living-person claim.",
          "The 2700-second allowance is explicitly authored, not a measured journey bound.",
        ]
      }
    }
    if terms.isSeedTransfer, let id = row.action.instance,
      commander.scriptState.instances[id]?.savedWayfarerColdChain?.seedTransfer != nil
    {
      lines.append("Native source-custodian release recorded for this original seed lot.")
    }
    if let id = row.action.instance, let remaining = try? wayfarerColdChainDisplayRemaining(id) {
      lines.append(
        String(
          format: terms.isSeedTransfer
            ? "Original seed-lot integrity remaining: %.1f flight seconds."
            : "Original sample integrity remaining: %.1f flight seconds.", remaining))
    }
    if case .pickup(let source, _) = row.action,
      let stock = commander.scriptState.savedWayfarerColdChainStock?.sources[source]
    {
      lines.append(
        "Available original \(terms.isSeedTransfer ? "seed lots" : "samples"): \(stock.units.values.filter { $0.status == .available }.count). No replenishment."
      )
    }
    if case .retryExpiry = row.action {
      lines.append(
        "Confirm retries recording the same original expiry; it does not replace the sample.")
    }
    lines +=
      contractBoard.coldChainQuote?.issues ?? (contractBoard.selected?.reason.map { [$0] } ?? [])
    return lines
  }

  var wayfarerColdChainPageFacts: [String] {
    guard contractBoard.rows.contains(where: { $0.coldChain != nil }) else { return [] }
    var fields = [
      ecmControl.epoch.uuidString,
      String(commander.nativeStations?.currentMainDock?.sequence ?? 0),
    ]
    for row in contractBoard.rows {
      guard let cold = row.coldChain else { continue }
      fields += [cold.key, row.reason ?? ""]
      if let id = cold.action.instance, let state = commander.scriptState.instances[id] {
        fields += [
          String(state.revision), state.outcome.rawValue,
          String((try? wayfarerColdChainDisplayRemaining(id)) ?? 0),
        ]
      }
    }
    return fields
  }
}
