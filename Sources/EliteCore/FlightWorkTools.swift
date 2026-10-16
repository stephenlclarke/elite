import Foundation

public enum FlightWorkTool: CaseIterable, Sendable, Equatable {
  case combatLaser, miningLaser, salvageCutter

  public var label: String {
    switch self {
    case .combatLaser: "Combat laser"
    case .miningLaser: "Mining laser"
    case .salvageCutter: "Salvage cutter"
    }
  }
}

extension Game {
  public mutating func selectFlightTool(_ tool: FlightWorkTool) {
    guard !docked, screen.isFlight else { return }
    selectedFlightTool = tool
    let installed: Bool
    switch tool {
    case .combatLaser: installed = LaserMount.from(screen).flatMap(commander.laser(on:)) != nil
    case .miningLaser:
      installed = commander.hasMiningWorkTool || commander.laser(on: .front) == .mining
    case .salvageCutter:
      installed =
        commander.performance.workTools?.contains(.salvageCutter) == true
        && commander.fittedEquipment(at: .utility(.salvageCutter)) != nil
    }
    notify(installed ? "SELECTED " + tool.label.uppercased() : "FIT " + tool.label.uppercased())
  }

  mutating func cycleFlightTool() {
    let tools = FlightWorkTool.allCases
    let index = tools.firstIndex(of: selectedFlightTool) ?? 0
    selectFlightTool(tools[(index + 1) % tools.count])
  }

  /// An unavailable selected utility never falls through to a combat weapon.
  mutating func fireSelectedFlightTool(delta: Double) {
    switch selectedFlightTool {
    case .combatLaser: fireLaser()
    case .miningLaser: _ = fireMiningWorkTool()
    case .salvageCutter: _ = fireSalvageCutter(delta: delta)
    }
  }

  /// Match the rendered mesh's model transform, including its visible rotation.
  func modelPose(of body: SpaceBody) -> ShipPose {
    let player = commander.flightSimulation.pose
    var basis = Basis3()
    basis.x = player.orientation.apply(body.modelVector(.init(1, 0, 0)))
    basis.y = player.orientation.apply(body.modelVector(.init(0, 1, 0)))
    basis.z = player.orientation.apply(body.modelVector(.init(0, 0, 1)))
    return .init(position: player.systemPoint(body.position), orientation: basis)
  }

  /// Native project costs, separate from the four combat laser installations.
  @discardableResult
  mutating func fireSalvageCutter(delta: Double) -> Bool {
    let energyCost = delta * 2
    let heatCost = delta * 6
    guard !docked, screen == .front, delta.isFinite, delta > 0, delta <= 0.1,
      commander.performance.workTools?.contains(.salvageCutter) == true,
      commander.fittedEquipment(at: .utility(.salvageCutter)) != nil,
      energy.isFinite, laserHeat.isFinite, energy > energyCost,
      laserHeat + heatCost < 240,
      let context = gameplayContext(),
      let hit = GameplayRaycast.nearest(
        origin: .init(0, 0, 0), direction: .init(0, 0, 1), maxDistance: 300,
        bodies: bodies.filter { $0.energy > 0 }, celestials: celestials,
        meshOverrides: gameplayMeshOverrides),
      case .body(let id) = hit.target,
      let body = bodies.first(where: { $0.id == id && $0.energy > 0 }),
      let physical = body.physical, physical.npc == nil, let metadata = physical.salvage,
      metadata.claimant == nil,
      [.wreck, .section].contains(metadata.category),
      physical.identity.system == context.system, physical.identity.visit == context.visit,
      let wreck = metadata.wreck, wreck.system == context.system,
      let catalogue = physical.catalogueShipID,
      let profile = SalvageCatalogue.profile(catalogueShipID: catalogue),
      SalvageCatalogue.eligibility(
        catalogueShipID: catalogue, ownership: metadata.ownership,
        activeStation: body.id == 0 && body.hull == .station,
        missionProtected: context.protection.protectedActors.contains(physical.identity))
        == .allowed
    else { return false }
    let pose = modelPose(of: body)
    let impact = commander.flightSimulation.pose.systemPoint(hit.point)
    // Work is tied to a real accessible section of the hit mesh, not the hull centre.
    guard
      let section = profile.sections.filter({ section in
        let identity = WreckSectionIdentity(wreck: wreck, section: section.index)
        let surface = pose.systemPoint(section.localPosition)
        let normal = pose.orientation.apply(section.normal)
        return !commander.salvageLedger.isDepleted(identity)
          && (metadata.section == nil || metadata.section == identity)
          && metadata.workSurfaces.contains { $0.section == identity }
          && (surface - impact).length <= max(1, section.radius)
          && normal.dot(commander.flightSimulation.pose.position - surface) > 0
      }).min(by: {
        (pose.systemPoint($0.localPosition) - impact).length
          < (pose.systemPoint($1.localPosition) - impact).length
      })
    else { return false }

    var candidate = self
    guard let operation = candidate.commander.flightSimulation.allocateIncident() else {
      return false
    }
    let source = SalvageLootSource(
      roles: profile.sourceRoles, legalValue: physical.npc?.legal.value ?? 0,
      economy: currentSystem.economy, technology: currentSystem.technology,
      ownership: metadata.ownership, manifest: physical.npc?.ordinaryCargo)
    let result = candidate.commander.salvageLedger.advance(
      wreck: wreck, section: section, pose: pose,
      velocity: physical.velocity, angularVelocity: physical.angularVelocity,
      tool: .cutter, elapsed: delta, operation: operation,
      conditions: .init(
        toolInstalled: true, inRange: true, aligned: true, lineOfSight: true,
        resourcesAvailable: true, ownershipAuthorized: true), source: source)
    switch result {
    case .progress, .released, .destroyed:
      candidate.energy -= energyCost
      candidate.laserHeat += heatCost
      candidate.laserFlash = 0.08
      if case .released = result { candidate.notify("SECTION RELEASED") }
      if case .destroyed = result { candidate.notify("SECTION EXHAUSTED") }
      self = candidate
      admitPendingSalvage()
      return true
    case .blocked, .capacityRefused, .alreadyDepleted: return false
    }
  }

  mutating func admitPendingSalvage() {
    guard let context = gameplayContext() else { return }
    let requests = commander.salvageLedger.spawnRequests(context: context)
    let receipts = admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit, revision: context.revision,
        batches: [.init(requests: requests, atomic: false)], intents: []))
    commander.salvageLedger.acknowledge(receipts: receipts)
  }

  mutating func persistSalvagePoses() {
    for body in bodies {
      guard let physical = body.physical else { continue }
      if let payload = physical.payload, case .salvage(let lot) = payload {
        commander.salvageLedger.updateLot(
          lot, position: commander.flightSimulation.pose.systemPoint(body.position),
          velocity: physical.velocity)
      }
      if let metadata = physical.salvage, let wreck = metadata.wreck,
        [.wreck, .section].contains(metadata.category)
      {
        _ = commander.salvageLedger.updateWreck(
          identity: wreck,
          motion: .init(
            pose: modelPose(of: body), velocity: physical.velocity,
            angularVelocity: physical.angularVelocity))
      }
    }
  }
}
