import Foundation

public enum FlightWorkTool: CaseIterable, Sendable, Equatable {
  case combatLaser, miningLaser, salvageCutter, empPirateBlaster

  public var label: String {
    switch self {
    case .combatLaser: FlightControlAuthority.Weapon.mainLaser.rawValue
    case .miningLaser: FlightControlAuthority.Weapon.miningLaser.rawValue
    case .salvageCutter: FlightControlAuthority.Weapon.salvageCutter.rawValue
    case .empPirateBlaster: FlightControlAuthority.Weapon.empBlaster.rawValue
    }
  }
}

extension Game {
  public mutating func selectFlightTool(_ tool: FlightWorkTool) {
    guard !docked, screen.isFlight else { return }
    interruptFlightTool()
    guard flushNativeSalvageWork() else { return }
    workGuidance?.manualToolOverride = true
    selectedFlightTool = tool
    let installed = flightToolIsFitted(tool)
    notify(installed ? "SELECTED " + tool.label.uppercased() : "FIT " + tool.label.uppercased())
  }

  mutating func cycleFlightTool() {
    let tools = fittedFlightTools
    guard !tools.isEmpty else {
      interruptFlightTool()
      notify("NO FITTED WEAPON")
      return
    }
    let next = tools.firstIndex(of: selectedFlightTool).map { ($0 + 1) % tools.count } ?? 0
    selectFlightTool(tools[next])
  }

  /// An unavailable selected utility never falls through to a combat weapon.
  mutating func fireSelectedFlightTool(delta: Double, nativeSalvagePublish: ScriptPublisher? = nil)
  {
    guard !workFireSuspended, !playerEMPDisabled else { return }
    if let work = workGuidance, !work.holding,
      !((selectedFlightTool == .combatLaser || selectedFlightTool == .empPirateBlaster)
        && work.manualToolOverride)
    {
      return
    }
    let priorEvent = dischargeAudio.events.last?.id
    switch selectedFlightTool {
    case .combatLaser:
      guard LaserMount.from(screen).flatMap(commander.laser(on:)).map({ $0 != .mining }) == true
      else { return }
      fireLaser()
    case .miningLaser: _ = fireMiningWorkTool()
    case .salvageCutter: _ = fireSalvageCutter(delta: delta, publish: nativeSalvagePublish)
    case .empPirateBlaster: _ = fireEMPPirateBlaster()
    }
    if dischargeAudio.events.last?.id != priorEvent,
      dischargeAudio.events.last?.tool == selectedFlightTool
    {
      selectedToolActivity = .init(
        tool: selectedFlightTool, physicalTime: commander.flightSimulation.physicalTime)
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
  mutating func fireSalvageCutter(delta: Double, publish: ScriptPublisher? = nil) -> Bool {
    let energyCost = delta * 2
    let heatCost = delta * 6
    guard !docked, screen == .front, delta.isFinite, delta > 0, delta <= 0.1,
      commander.performance.workTools?.contains(.salvageCutter) == true,
      commander.fittedEquipment(at: .utility(.salvageCutter)) != nil,
      energy.isFinite, laserHeat.isFinite, energy > energyCost,
      laserHeat + heatCost < 240,
      let context = gameplayContext(),
      let contact = try? nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 300,
        radius: 0, includePlayer: false),
      case .body(let id) = contact.hit.target,
      let body = bodies.first(where: { $0.id == id && $0.energy > 0 }),
      let physical = body.physical, physical.npc == nil, let metadata = physical.salvage,
      metadata.claimant == nil,
      [.wreck, .section].contains(metadata.category),
      physical.identity.system == context.system, physical.identity.visit == context.visit,
      let wreck = metadata.wreck, wreck.system == context.system,
      let profile = salvageProfile(for: body),
      salvageCuttingIsAllowed(body, metadata: metadata, context: context),
      physical.empSource == nil
        || (commander.fittedEquipment(at: .targetingSalvage) != nil
          && commander.fittedEquipment(at: .utility(.fuelScoops)) != nil)
    else { return false }
    let pose = modelPose(of: body)
    let impact = commander.flightSimulation.pose.systemPoint(contact.hit.point)
    // Work is tied to a real accessible section of the hit mesh, not the hull centre.
    guard
      let section = profile.sections.filter({ section in
        let identity = WreckSectionIdentity(wreck: wreck, section: section.index)
        let surface = pose.systemPoint(section.localPosition)
        let normal = pose.orientation.apply(section.normal)
        return !salvageSectionIsDepleted(identity)
          && (metadata.section == nil || metadata.section == identity)
          && metadata.workSurfaces.contains { $0.section == identity }
          && (surface - impact).length <= max(1, section.radius)
          && normal.dot(commander.flightSimulation.pose.position - surface) > 0
      }).min(by: {
        (pose.systemPoint($0.localPosition) - impact).length
          < (pose.systemPoint($1.localPosition) - impact).length
      })
    else { return false }

    var source = SalvageLootSource(
      roles: profile.sourceRoles, legalValue: physical.npc?.legal.value ?? 0,
      economy: currentSystem.economy, technology: currentSystem.technology,
      ownership: metadata.ownership, manifest: physical.npc?.ordinaryCargo)
    if let original = physical.empSource.flatMap({ commander.savedEMPState?.records[$0] }) {
      source.manifest = original.salvageCargo
      source = .init(
        roles: profile.sourceRoles, legalValue: original.salvageLegal.value,
        economy: currentSystem.economy, technology: currentSystem.technology,
        ownership: .abandoned, stolenProvenance: original.salvageLegal.value == 0,
        manifest: original.salvageCargo
      )
    }
    if usesNativeSalvageWork(section: .init(wreck: wreck, section: section.index), profile: profile)
    {
      return advanceNativeSalvageWork(
        body: body, section: section, source: source, delta: delta, publish: publish)
    }
    guard flushNativeSalvageWork() else { return false }
    var candidate = self
    guard let operation = candidate.commander.flightSimulation.allocateIncident() else {
      return false
    }
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
      candidate.dischargeAudio.record(.salvageCutter)
      if case .released = result { candidate.notify("SECTION RELEASED") }
      if case .destroyed = result { candidate.notify("SECTION EXHAUSTED") }
      self = candidate
      admitPendingSalvage()
      return true
    case .blocked, .capacityRefused, .alreadyDepleted: return false
    }
  }

  mutating func admitPendingSalvage() {
    admitPendingNativeSalvage()
    guard let context = gameplayContext() else { return }
    let requests = commander.salvageLedger.spawnRequests(context: context)
    let receipts = admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit, revision: context.revision,
        batches: [.init(requests: requests, atomic: false)], intents: []))
    commander.salvageLedger.acknowledge(receipts: receipts)
  }

  @discardableResult
  mutating func persistSalvagePoses(cold: Bool = true) -> Bool {
    cold ? persistSalvagePosesCold() : persistSalvagePosesInPlace(cold: false)
  }

  /// Cold validation may fail after another body was observed. Keep the complete
  /// previous source state and hot session until every observation can be retained.
  private mutating func persistSalvagePosesCold() -> Bool {
    let original = commander
    let work = nativeSalvageWork
    let wreckMotion = nativeSalvageWreckMotion
    let lotMotion = nativeSalvageMotion
    guard persistSalvagePosesInPlace(cold: true) else {
      commander = original
      nativeSalvageWork = work
      nativeSalvageWreckMotion = wreckMotion
      nativeSalvageMotion = lotMotion
      return false
    }
    return true
  }

  @inline(never)
  private mutating func persistSalvagePosesInPlace(cold: Bool) -> Bool {
    guard persistEMPState() else { return false }
    return persistSalvagePosesAfterEMP(cold: cold)
  }

  /// Salvage observation temporaries are entered only after EMP persistence has returned.
  @inline(never)
  private mutating func persistSalvagePosesAfterEMP(cold: Bool) -> Bool {
    var ledger = commander.salvageLedger
    for body in bodies {
      guard let physical = body.physical else { continue }
      if let payload = physical.payload, case .salvage(let lot) = payload {
        if commander.alienStorageState?.current.salvage.sections.contains(lot.section) == true {
          guard observeNativeSalvageMotion(body) else { return false }
          continue
        }
        if body.energy <= 0 { continue }
        let position = commander.flightSimulation.pose.systemPoint(body.position)
        guard physical.identity.system == systemIdentity,
          physical.identity.visit == commander.flightSimulation.visit,
          lot.section.wreck.system == systemIdentity,
          ledger.boundActor(for: lot) == physical.identity,
          position.finite, position.length.isFinite,
          physical.velocity.finite, physical.velocity.length.isFinite, body.energy.isFinite
        else { return false }
        ledger.updateLot(lot, position: position, velocity: physical.velocity)
      }
      if let metadata = physical.salvage, let wreck = metadata.wreck,
        [.wreck, .section].contains(metadata.category)
      {
        if commander.alienStorageState?.current.salvage.native.wrecks[wreck] != nil {
          guard observeNativeSalvageWreck(body) else { return false }
          continue
        }
        if body.energy <= 0 { continue }
        guard physical.identity.system == systemIdentity,
          physical.identity.visit == commander.flightSimulation.visit,
          wreck.system == systemIdentity,
          ledger.updateWreck(
            identity: wreck,
            motion: .init(
              pose: modelPose(of: body), velocity: physical.velocity,
              angularVelocity: physical.angularVelocity, energy: body.energy))
        else { return false }
      }
    }
    if ledger != commander.salvageLedger { commander.salvageLedger = ledger }
    return !cold
      || (flushNativeSalvageWork() && flushNativeSalvageWrecks() && flushNativeSalvageMotion())
  }
}
