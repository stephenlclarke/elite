import Foundation

extension WorkTargetFilter {
  public var label: String {
    switch self {
    case .all: "All"
    case .ships: "Ships"
    case .mining: "Mining"
    case .salvage: "Salvage"
    }
  }
  var next: Self {
    switch self {
    case .ships: .mining
    case .mining: .salvage
    case .salvage: .all
    case .all: .ships
    }
  }
}

extension Game {
  var workTargetCapabilities: WorkTargetCapabilities {
    func installed(_ name: String, slot: ComponentFittingSlot) -> Bool {
      commander.fittedEquipment(at: slot) != nil
        || (commander.equipmentInventory == nil && commander.equipment.contains(name))
    }
    return .init(
      core: commander.targetingTier,
      miningModule: installed("Targeting: Mining Module", slot: .targetingMining),
      salvageModule: installed("Targeting: Salvage Module", slot: .targetingSalvage),
      fuelScoops: commander.equipment.contains("Fuel Scoops"))
  }

  func workTargetCandidate(
    for body: SpaceBody, context: EncounterContext, frontVisible: Bool
  ) -> WorkTargetCandidate? {
    guard let physical = body.physical, body.energy.isFinite, body.energy > 0,
      body.position.finite, body.position.length.isFinite,
      modelPose(of: body).orientation.validRotation
    else { return nil }
    let kind: WorkTargetKind
    var compatible = false
    if body.hull == .station {
      kind = .activeStation
    } else if isCapitalHoldVessel(body), physical.salvage == nil {
      kind = .capitalShip
    } else if let metadata = recoverableMetadata(for: body, context: context) {
      kind = .recoverable(metadata, payload: physical.payload)
      compatible = automaticScoopShapeCompatible(body, context: context)
    } else if body.hull.isTargetShip {
      kind = .ship
    } else {
      return nil
    }
    return .init(
      identity: physical.identity, kind: kind, isLive: true,
      frontVisible: frontVisible, distance: body.position.length,
      singleScoopCompatible: compatible,
      nativePod: nativePodFacts(body, context: context),
      nativeCrewCapture: nativeCrewCaptureAvailable(body, context: context)
        && freeNativePeopleTonnes > 0,
      originalRescue: originalRescueFacts(body, context: context),
      measuredExtraction: measuredExtractionFacts(body, context: context),
      recordRecovery: recordRecoveryFacts(body, context: context),
      inductionCrewLog: inductionCrewLogFacts(body),
      identifiedSalvage: identifiedSalvageFacts(body, context: context))
  }

  func isCapitalHoldVessel(_ body: SpaceBody) -> Bool {
    guard body.hull != .station, let id = body.physical?.catalogueShipID,
      let ship = ShipCatalogue.ship(id)
    else { return false }
    return ship.catalogue.isCapital && ship.catalogue.capitalSubtype == .vessel
  }

  /// Geometry for guidance only. This never installs salvage authority on a live actor.
  /// Cutter permission continues to require physical.salvage and native custody joins.
  func holdSurfaceMetadata(for body: SpaceBody, context: EncounterContext)
    -> SalvageTargetMetadata?
  {
    if let metadata = recoverableMetadata(for: body, context: context) { return metadata }
    guard isCapitalHoldVessel(body) else { return nil }
    return .init(
      category: .wreck, ownership: .occupied, claimant: nil,
      wreck: nil, section: nil, lot: nil,
      bounds: .init(
        center: .init(0, 0, 0),
        radius: gameplayMesh(for: body).vertices.map(\.length).max() ?? 0), workSurfaces: [])
  }

  func recoverableMetadata(for body: SpaceBody, context: EncounterContext) -> SalvageTargetMetadata?
  {
    guard nativePracticeReservation(body) == nil else { return nil }
    guard let physical = body.physical else { return nil }
    if let payload = physical.payload, measuredPayloadIsAllocated(payload),
      commander.miningLedger.boundActor(for: payload) == physical.identity
    {
      return .init(
        category: .cargo, ownership: .missionProtected, claimant: nil,
        wreck: nil, section: nil, lot: nil,
        bounds: .init(
          center: .init(0, 0, 0), radius: gameplayMesh(for: body).vertices.map(\.length).max() ?? 0),
        workSurfaces: [])
    }
    if let original = inductionCrewLogMetadata(body) { return original }
    if let original = recordRecoveryMetadata(body, context: context) { return original }
    if let original = identifiedSalvageMetadata(body, context: context) { return original }
    if let original = originalRescueMetadata(body, context: context) { return original }
    var result: SalvageTargetMetadata?
    if let supplied = physical.salvage {
      result = supplied
    } else if let rock = physical.rock,
      let record = miningFields.lazy.flatMap(\.rocks).first(where: { $0.identity == rock })
    {
      result = .init(
        category: .rock, ownership: .abandoned, claimant: nil, wreck: nil, section: nil, lot: nil,
        bounds: .init(center: .init(0, 0, 0), radius: record.radius), workSurfaces: [])
    } else if let payload = physical.payload {
      let available: Bool
      switch payload {
      case .ore:
        available =
          commander.miningLedger.boundActor(for: payload) == physical.identity
          && commander.miningLedger.pendingPayloads.contains { $0.identity == payload }
      case .wreck:
        available =
          commander.cargoDebrisLedger.boundActor(for: payload) == physical.identity
          && commander.cargoDebrisLedger.pendingPayloads.contains { $0.identity == payload }
      case .salvage(let lot):
        available = currentSalvageLot(for: body)?.identity == lot
      case .mission: available = true
      }
      guard available else { return nil }
      result = .init(
        category: .cargo, ownership: .abandoned, claimant: nil, wreck: nil, section: nil, lot: nil,
        bounds: .init(
          center: .init(0, 0, 0), radius: gameplayMesh(for: body).vertices.map(\.length).max() ?? 0),
        workSurfaces: [])
    } else if body.hull == .cargo || (body.hull == .thargon && !body.hostile) {
      result = .init(
        category: body.hull == .thargon ? .disabledDrone : .cargo,
        ownership: .abandoned, claimant: nil, wreck: nil, section: nil, lot: nil,
        bounds: .init(
          center: .init(0, 0, 0), radius: gameplayMesh(for: body).vertices.map(\.length).max() ?? 0),
        workSurfaces: [])
    }
    guard let metadata = result else { return nil }
    let occupiedEMP =
      isEMPDisabled(body)
      && physical.empSource.flatMap { commander.savedEMPState?.records[$0]?.crewAboard }.map {
        $0 > 0
      } == true
    let protected =
      context.protection.protectedActors.contains(physical.identity)
      || physical.payload.map(context.protection.protectedPayloads.contains) == true
      || (physical.npc != nil && [.wreck, .section].contains(metadata.category) && !occupiedEMP)
    guard protected else { return metadata }
    return .init(
      category: metadata.category, ownership: .missionProtected, claimant: metadata.claimant,
      wreck: metadata.wreck, section: metadata.section, lot: metadata.lot,
      bounds: metadata.bounds, workSurfaces: metadata.workSurfaces)
  }

  /// Original ordinary canisters keep their existing capture contract. The exception is
  /// limited to actual current-bound native ore/debris; salvage retains its 16-unit aperture.
  func automaticScoopShapeCompatible(_ body: SpaceBody, context: EncounterContext) -> Bool {
    guard let actual = recordRecoveryCompatibleMesh(body, context: context) else { return false }
    let native = Mesh.hull(.cargo)
    if body.hull == .cargo, let physical = body.physical,
      physical.identity.system == context.system, physical.identity.visit == context.visit,
      physical.catalogueShipID == nil, physical.npc == nil, physical.ordnance == nil,
      physical.rock == nil, actual.vertices == native.vertices, actual.faces == native.faces,
      let payload = physical.payload
    {
      switch payload {
      case .ore(let source, _):
        if source.system == context.system,
          commander.miningLedger.boundActor(for: payload) == physical.identity,
          commander.miningLedger.pendingPayloads.contains(where: {
            $0.identity == payload && $0.amount.valid
          })
        {
          return true
        }
      case .wreck(let source, _):
        if source.system == context.system,
          commander.cargoDebrisLedger.boundActor(for: payload) == physical.identity,
          commander.cargoDebrisLedger.pendingPayloads.contains(where: {
            $0.identity == payload && $0.amount.valid
          })
        {
          return true
        }
      case .salvage, .mission: break
      }
    }
    guard let half = collectibleHalfExtents(body, context: context) else { return false }
    return half.finite && half.x > 0 && half.y > 0 && half.z > 0
      && half.x <= 16 && half.y <= 16 && half.z <= 16
  }

  func collectibleHalfExtents(_ body: SpaceBody, context: EncounterContext) -> Vector3? {
    if let payload = body.physical?.payload, case .salvage = payload {
      return currentSalvageLot(for: body)?.halfExtents
    }
    guard let mesh = recordRecoveryCompatibleMesh(body, context: context) else { return nil }
    guard !mesh.vertices.isEmpty else { return nil }
    return .init(
      mesh.vertices.map { abs($0.x) }.max()!, mesh.vertices.map { abs($0.y) }.max()!,
      mesh.vertices.map { abs($0.z) }.max()!)
  }

  mutating func cycleWorkTargetFilter() {
    guard !docked, screen.isFlight else { return }
    cancelAutoTarget()
    workTargetFilter = workTargetFilter.next
    notify("TARGET FILTER: " + workTargetFilter.label.uppercased())
  }

  func workRefusalMessage(_ refusal: WorkTargetRefusal) -> String {
    switch refusal {
    case .fullPeopleHold: "NO REAL HOLD SPACE FOR PEOPLE"
    case .missingCore: "FIT A TARGETING COMPUTER"
    case .missingModule(.mining): "FIT A MINING TARGETING MODULE"
    case .missingModule(.salvage): "FIT A SALVAGE TARGETING MODULE"
    case .missingFuelScoops: "FIT FUEL SCOOPS"
    case .notScoopCompatible: "ITEM TOO LARGE FOR SCOOPS"
    case .protectedTarget, .occupiedPod: "TARGET IS PROTECTED"
    case .dockingCoreRequired: "DOCKING TARGETING TIER REQUIRED FOR STATIONS"
    case .frontVisibilityRequired: "TARGET MUST BE VISIBLE AHEAD"
    case .notLive, .wrongContext, .invalidDistance: "TARGET UNAVAILABLE"
    }
  }
}
