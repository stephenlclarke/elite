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
    } else if let metadata = recoverableMetadata(for: body, context: context) {
      kind = .recoverable(metadata, payload: physical.payload)
      let half = collectibleHalfExtents(body)
      compatible =
        half.map {
          $0.finite && $0.x > 0 && $0.y > 0 && $0.z > 0
            && $0.x <= 16 && $0.y <= 16 && $0.z <= 16
        } ?? false
    } else if body.hull.isTargetShip {
      kind = .ship
    } else {
      return nil
    }
    return .init(
      identity: physical.identity, kind: kind, isLive: true,
      frontVisible: frontVisible, distance: body.position.length,
      singleScoopCompatible: compatible)
  }

  func recoverableMetadata(for body: SpaceBody, context: EncounterContext) -> SalvageTargetMetadata?
  {
    guard let physical = body.physical else { return nil }
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
        available =
          commander.salvageLedger.boundActor(for: lot) == physical.identity
          && commander.salvageLedger.pendingLots.contains { $0.identity == lot }
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
    let protected =
      context.protection.protectedActors.contains(physical.identity)
      || physical.payload.map(context.protection.protectedPayloads.contains) == true
      || (physical.npc != nil && [.wreck, .section].contains(metadata.category))
    guard protected else { return metadata }
    return .init(
      category: metadata.category, ownership: .missionProtected, claimant: metadata.claimant,
      wreck: metadata.wreck, section: metadata.section, lot: metadata.lot,
      bounds: metadata.bounds, workSurfaces: metadata.workSurfaces)
  }

  func collectibleHalfExtents(_ body: SpaceBody) -> Vector3? {
    if let payload = body.physical?.payload, case .salvage(let lot) = payload {
      return commander.salvageLedger.pendingLots.first { $0.identity == lot }?.halfExtents
    }
    let mesh = gameplayMesh(for: body)
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
