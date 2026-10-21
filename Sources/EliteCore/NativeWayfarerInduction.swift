import Foundation

struct NativeWayfarerInductionDefinition: Codable, Sendable, Equatable {
  let profile: String
  let flightAllowance: Double
  var valid: Bool { profile == "native-senn-clinic-v1" && flightAllowance == 1800 }
}

enum NativeInductionTradeEvidence: Codable, Sendable, Equatable {
  case sale(UUID)
  case delivery(UUID, String)

  var validShape: Bool {
    switch self {
    case .sale: true
    case .delivery(_, let hash): ScriptCompletionReceipt.validDigest(hash)
    }
  }

  static func first(in engine: borrowing ScriptEngineState, owner: UUID) -> Self? {
    if let sale = engine.firstNativeCommoditySale, sale.owner == owner, sale.valid {
      return .sale(sale.operation)
    }
    for id in engine.instances.keys.sorted(by: { $0.uuidString < $1.uuidString }) {
      if let hash = deliveryHash(id, engine: engine, owner: owner) { return .delivery(id, hash) }
    }
    return nil
  }

  func valid(in engine: borrowing ScriptEngineState, owner: UUID) -> Bool {
    switch self {
    case .sale(let operation):
      return engine.firstNativeCommoditySale.map {
        $0.owner == owner && $0.valid && $0.operation == operation
      } == true
    case .delivery(let id, let hash):
      return Self.deliveryHash(id, engine: engine, owner: owner) == hash
    }
  }

  @inline(never)
  private static func deliveryHash(
    _ id: UUID, engine: borrowing ScriptEngineState, owner: UUID
  ) -> String? {
    guard let state = engine.instances[id], state.outcome == .complete,
      state.contract?.settled == true, state.contract?.settlementOutcome == .complete,
      let receipt = state.completionReceipt, receipt.valid(for: state, engine: engine),
      receipt.causeKind == "dialogue.confirmed",
      receipt.cause?.nativeMainDock?.commanderOwner == owner
    else { return nil }
    if state.definition == OriginalSealedDispatch.stateID {
      guard state.contract?.offer.courier?.declaration == OriginalSealedDispatch.definition,
        let custody = state.courier, custody.terminal?.cause == .delivered,
        custody.valid(state: state, engine: engine)
      else { return nil }
    } else {
      guard
        [
          OriginalConsentedFreightSupply.stateID, "l337.contract/bonded-freight",
        ].contains(state.definition),
        let cargo = state.savedOwnedCargo, cargo.owner == owner,
        cargo.terminal?.cause == .delivered, cargo.valid(state: state, engine: engine)
      else { return nil }
    }
    return try? NativeFlightReception.hash(receipt)
  }
}

struct NativeInductionPermission: Codable, Sendable, Equatable {
  let mission: UUID
  let operation: UUID
  let owner: UUID
  let dock: NativeMainStationDockReceipt
  let trade: NativeInductionTradeEvidence
  let carrier: UUID
  let inventoryRevision: UInt64
  let physicalTime: Double
  let flightSeconds: Double
}

struct NativeInductionClinicCrate: Codable, Sendable, Equatable {
  let unit: UUID
  let coolingUnit: UUID
  let operation: UUID
  let dock: NativeMainStationDockReceipt
  let carrier: UUID
  let inventoryRevision: UInt64
  let physicalTime: Double
  let issuedFlightSeconds: Double
  let allowance: Double
  let deadline: Double

  func valid(permission: NativeInductionPermission) -> Bool {
    unit == NativeWayfarerInduction.clinicUnit(owner: permission.owner)
      && coolingUnit == ScriptIdentity.uuid("induction-sealed-cooling-v1:\(unit)")
      && dock.valid && dock.commanderOwner == permission.owner
      && dock.station.world == permission.owner
      && dock.station.system == NativeWayfarerInduction.clinic
      && dock.sequence > permission.dock.sequence
      && dock.actor.visit > permission.dock.actor.visit
      && physicalTime.isFinite && physicalTime >= permission.physicalTime
      && physicalTime <= 1e12
      && issuedFlightSeconds.isFinite && issuedFlightSeconds >= permission.flightSeconds
      && allowance == NativeWayfarerInduction.flightAllowance
      && deadline.isFinite && deadline <= 1e12
      && deadline == issuedFlightSeconds + allowance
      && operation
        == (try? NativeWayfarerInduction.pickupOperation(
          permission: permission.operation, dock: dock, carrier: carrier,
          revision: inventoryRevision, flightSeconds: issuedFlightSeconds))
  }

  /// An absolute reading of the existing native flight clock, never a second ticking timer.
  func remaining(at flightSeconds: Double) throws -> Double {
    guard issuedFlightSeconds.isFinite, issuedFlightSeconds >= 0,
      allowance.isFinite, allowance > 0, deadline.isFinite, deadline <= 1e12,
      deadline == issuedFlightSeconds + allowance,
      flightSeconds.isFinite, flightSeconds >= issuedFlightSeconds, flightSeconds <= 1e12
    else {
      throw SaveError.invalidCommander
    }
    return max(0, deadline - flightSeconds)
  }
}

struct NativeInductionCrateLoss: Codable, Sendable, Equatable {
  let carrier: UUID
  let physicalTime: Double
  let facts: WayfarerColdChainPhysicalLoss
}

/// Immutable publication leaf: custody is replaced atomically with its one-tonne reservation.
final class NativeWayfarerInductionState: Codable, Sendable, Equatable {
  let permission: NativeInductionPermission
  let crate: NativeInductionClinicCrate?
  let loss: NativeInductionCrateLoss?
  let reception: NativeInductionClinicReception?
  let cassette: NativeInductionWorkshopCassette?
  let cassetteLoss: NativeInductionCrateLoss?
  let cassetteService: NativeInductionCassetteService?
  init(
    permission: NativeInductionPermission, crate: NativeInductionClinicCrate? = nil,
    loss: NativeInductionCrateLoss? = nil, reception: NativeInductionClinicReception? = nil,
    cassette: NativeInductionWorkshopCassette? = nil, cassetteLoss: NativeInductionCrateLoss? = nil,
    cassetteService: NativeInductionCassetteService? = nil
  ) {
    self.permission = permission
    self.crate = crate
    self.loss = loss
    self.reception = reception
    self.cassette = cassette
    self.cassetteLoss = cassetteLoss
    self.cassetteService = cassetteService
  }
  static func == (lhs: NativeWayfarerInductionState, rhs: NativeWayfarerInductionState) -> Bool {
    lhs.permission == rhs.permission && lhs.crate == rhs.crate && lhs.loss == rhs.loss
      && lhs.reception == rhs.reception && lhs.cassette == rhs.cassette
      && lhs.cassetteLoss == rhs.cassetteLoss && lhs.cassetteService == rhs.cassetteService
  }
  var valid: Bool {
    let p = permission
    guard p.mission == NativeWayfarerInduction.mission(owner: p.owner),
      p.dock.valid, p.dock.commanderOwner == p.owner, p.dock.station.world == p.owner,
      p.dock.station.system == NativeWayfarerInduction.source,
      p.physicalTime.isFinite, (0...1e12).contains(p.physicalTime),
      p.flightSeconds.isFinite, (0...1e12).contains(p.flightSeconds), p.trade.validShape,
      p.operation
        == (try? NativeWayfarerInduction.commissionOperation(
          mission: p.mission, owner: p.owner, dock: p.dock,
          carrier: p.carrier, revision: p.inventoryRevision))
    else { return false }
    if let crate {
      guard crate.valid(permission: p) else { return false }
      if let loss {
        guard loss.facts.valid, loss.physicalTime.isFinite,
          loss.physicalTime >= crate.physicalTime, loss.physicalTime <= 1e12,
          loss.facts.visit >= crate.dock.actor.visit,
          loss.facts.context.flightSeconds >= crate.issuedFlightSeconds
        else { return false }
      }
    } else if loss != nil {
      return false
    }
    return continuationValid
  }
  var payloads: [String: Int] {
    if cassette != nil && cassetteLoss == nil && cassetteService == nil {
      return [NativeWayfarerInduction.cassettePayload: 1]
    }
    return crate != nil && loss == nil && reception == nil
      ? [NativeWayfarerInduction.payload: 1] : [:]
  }

  func collecting(_ original: NativeInductionClinicCrate, freeTonnes: Int) throws -> Self {
    guard valid, crate == nil, loss == nil, freeTonnes >= 1 else {
      throw SaveError.invalidCommander
    }
    let next = Self(permission: permission, crate: original)
    guard next.valid else { throw SaveError.invalidCommander }
    return next
  }

  func losing(_ fact: NativeInductionCrateLoss) throws -> Self {
    guard valid, !payloads.isEmpty else { throw SaveError.invalidCommander }
    let next: Self
    if cassette != nil {
      next = Self(
        permission: permission, crate: crate, reception: reception, cassette: cassette,
        cassetteLoss: fact)
    } else {
      next = Self(permission: permission, crate: crate, loss: fact)
    }
    guard next.valid else { throw SaveError.invalidCommander }
    return next
  }
}

enum NativeWayfarerInduction {
  static let stateID = "l337.wayfarer-exchange/wayfarer-exchange"
  static let version = "1.0.0"
  static let capability = "native-wayfarer-induction-v1"
  static let digest = "c2ceb22cf13d84d2c2800729d0ef9d602f66b0a0c5e4ff82147deb466a649f9c"
  static let commissionTarget = "senn-network-commission"
  static let clinicTarget = "renas-clinic-coldcrate"
  static let clinicItem = "clinic-cold-crate"
  static let payload = "induction-clinic-cold-crate"
  static let flightAllowance = 1800.0
  static let source = SystemIdentity(galaxy: 0, system: 7)
  static let clinic = SystemIdentity(galaxy: 0, system: 185)
  static let receiver = SystemIdentity(galaxy: 0, system: 164)
  static let laterStages =
    "Stages 6-14, the consented vault-key loan and accreditation are not yet available."
  static func mission(owner: UUID) -> UUID {
    ScriptIdentity.uuid("wayfarer-induction-v1:\(owner)")
  }
  static func clinicUnit(owner: UUID) -> UUID {
    ScriptIdentity.uuid("induction-original-clinic-stock-v1:\(clinicItem):\(owner):0:185:0")
  }
  static func commissionOperation(
    mission: UUID, owner: UUID, dock: NativeMainStationDockReceipt,
    carrier: UUID, revision: UInt64
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "induction-commission-v1:\(commissionTarget):\(mission):\(owner):\(try NativeFlightReception.hash(dock)):\(carrier):\(revision)"
    )
  }
  static func pickupOperation(
    permission: UUID, dock: NativeMainStationDockReceipt,
    carrier: UUID, revision: UInt64, flightSeconds: Double
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "induction-pickup-v1:\(clinicTarget):\(permission):\(try NativeFlightReception.hash(dock)):\(carrier):\(revision):\(flightSeconds.bitPattern)"
    )
  }
}

extension Game {
  var wayfarerInductionMission: ScriptInstance? {
    commander.scriptState.instances.values.first {
      $0.definition == NativeWayfarerInduction.stateID
    }
  }
  var wayfarerInductionPack: ScriptPack? {
    scriptPacks.first {
      $0.manifest.stateID == NativeWayfarerInduction.stateID
        && $0.digest == NativeWayfarerInduction.digest
        && $0.manifest.wayfarerInduction?.valid == true
    }
  }
}

extension ScriptPackLibrary {
  static func validateWayfarerInduction(_ manifest: ScriptManifest) throws {
    guard let definition = manifest.wayfarerInduction else {
      guard manifest.stateID != NativeWayfarerInduction.stateID,
        !manifest.capabilities.contains(NativeWayfarerInduction.capability)
      else { throw MissionPackError("Exchange induction requires its closed native declaration.") }
      return
    }
    guard definition.valid, manifest.stateID == NativeWayfarerInduction.stateID,
      manifest.version == NativeWayfarerInduction.version, manifest.mission.milestones.count == 14,
      Set(manifest.capabilities)
        == Set([
          "script-lua-v1", "story-v2", "durable-commands-v2", NativeWayfarerInduction.capability,
        ]),
      manifest.handlers.count == 1, manifest.handlers.first?.event == "mission.accepted",
      manifest.board == nil, manifest.trial == nil, manifest.providerContract == nil,
      manifest.glassMeridian == nil, manifest.flightReception == nil, manifest.fieldRelief == nil,
      manifest.measuredExtraction == nil, manifest.recordRecovery == nil,
      manifest.identifiedSalvage == nil, manifest.originalRescue == nil,
      manifest.orbitalEvacuation == nil, manifest.stationJourney == nil,
      manifest.orbitalOutlook == nil, manifest.originalSurvey == nil,
      manifest.courier == nil, manifest.procurement == nil, manifest.freight == nil,
      manifest.coldChain == nil, manifest.repairLoop == nil, manifest.pledge == nil,
      (manifest.dependencies ?? []).isEmpty, (manifest.dialogs ?? []).isEmpty,
      (manifest.equipment ?? []).isEmpty, (manifest.passengerParties ?? []).isEmpty,
      (manifest.children ?? []).isEmpty, (manifest.collections ?? []).isEmpty,
      (manifest.worldJobs ?? []).isEmpty, (manifest.loans ?? []).isEmpty,
      (manifest.books ?? []).isEmpty, (manifest.models ?? []).isEmpty,
      (manifest.modules ?? []).isEmpty, (manifest.npcs ?? []).isEmpty,
      (manifest.encounters ?? []).isEmpty,
      (manifest.receiptRequirements ?? []).isEmpty, (manifest.answerRequirements ?? []).isEmpty,
      (manifest.mission.requiredBooks ?? []).isEmpty,
      (manifest.mission.requiredPassengerParties ?? []).isEmpty,
      (manifest.mission.requiredCollections ?? []).isEmpty,
      (manifest.mission.requiredChoiceGroups ?? []).isEmpty,
      (manifest.mission.requiredDestructionEncounters ?? []).isEmpty,
      (manifest.mission.requiredEquipmentReturns ?? []).isEmpty
    else {
      throw MissionPackError("Invalid closed Exchange opening or unearned later-stage authority.")
    }
  }
}
