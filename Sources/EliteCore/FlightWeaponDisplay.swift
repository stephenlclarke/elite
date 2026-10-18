import Foundation

/// A read-only projection of the selected tool. Native emission still performs its own transaction.
public struct FlightWeaponDisplay: Sendable, Equatable {
  public let weapon: String
  public let status: String
  public var text: String { "WEAPON: " + weapon + " / " + status }
}

extension Game {
  public var flightWeaponDisplay: FlightWeaponDisplay {
    let weapon = fittedFlightTools.isEmpty ? "NONE" : selectedFlightTool.label.uppercased()
    return .init(weapon: weapon, status: selectedWeaponStatus)
  }

  private var selectedWeaponStatus: String {
    guard !fittedFlightTools.isEmpty else { return "NOT FITTED" }
    guard flightToolIsFitted(selectedFlightTool) else { return "NOT FITTED" }
    guard !docked else { return "BLOCKED: DOCKED" }
    guard !paused else { return "BLOCKED: PAUSED" }
    guard !playerEMPDisabled else { return "BLOCKED: NO POWER" }
    if selectedFlightTool == .combatLaser {
      guard let mount = LaserMount.from(screen), let laser = commander.laser(on: mount),
        laser != .mining
      else { return "NOT FITTED IN VIEW" }
    } else if screen != .front {
      return "BLOCKED: FRONT VIEW"
    }
    if let work = workGuidance, !work.holding,
      !((selectedFlightTool == .combatLaser || selectedFlightTool == .empPirateBlaster)
        && work.manualToolOverride)
    {
      return "WAITING FOR HOLD"
    }
    if workFireSuspended { return "BLOCKED: FRESH RETURN" }
    if selectedFlightTool == .empPirateBlaster, let charge = commander.savedEMPCharge {
      switch charge.phase {
      case .charging:
        let elapsed = max(0, min(10, commander.flightSimulation.physicalTime - charge.startedAt))
        return "CHARGING " + String(format: "%.1F/10S", elapsed)
      case .cancelled: return "BLOCKED: RELEASE RETURN"
      case .released:
        if fireCooldown <= 0 { return "BLOCKED: RELEASE RETURN" }
      }
    }
    let resourceBlock = selectedWeaponResourceBlock
    if let resourceBlock { return resourceBlock }
    if let activity = selectedToolActivity, activity.tool == selectedFlightTool,
      flightTrigger.held,
      commander.flightSimulation.physicalTime - activity.physicalTime <= 0.15
    {
      switch selectedFlightTool {
      case .combatLaser, .empPirateBlaster: return "FIRING"
      case .miningLaser: return "MINING"
      case .salvageCutter: return "CUTTING"
      }
    }
    if selectedFlightTool != .salvageCutter && fireCooldown > 0 {
      return "COOLDOWN " + String(format: "%.1FS", fireCooldown)
    }
    return selectedWeaponTargetBlock ?? "READY"
  }

  private var selectedWeaponResourceBlock: String? {
    guard energy.isFinite, laserHeat.isFinite, fireCooldown.isFinite else {
      return "BLOCKED: RESOURCES"
    }
    switch selectedFlightTool {
    case .combatLaser:
      if laserHeat >= 240 { return "OVERHEATED" }
      if energy <= Self.combatLaserEnergyCost { return "NO ENERGY" }
    case .miningLaser:
      if laserHeat > 230 { return "OVERHEATED" }
      if energy <= 1 { return "NO ENERGY" }
    case .salvageCutter:
      if laserHeat + 0.6 >= 240 { return "OVERHEATED" }
      if energy <= 0.2 { return "NO ENERGY" }
    case .empPirateBlaster:
      guard let profile = try? EMPPulseProfile.resolve(for: commander) else {
        return "BLOCKED: EQUIPMENT"
      }
      if laserHeat + profile.heatCost >= 240 { return "OVERHEATED" }
      if (commander.savedPlayerElectrical?.remaining ?? commander.performance.energy)
        <= profile.energyCost
      {
        return "NO ENERGY"
      }
    }
    return nil
  }

  private var selectedWeaponTargetBlock: String? {
    if selectedFlightTool == .combatLaser { return nil }
    let range: Double
    switch selectedFlightTool {
    case .miningLaser: range = 6000
    case .salvageCutter: range = 300
    case .empPirateBlaster:
      guard let profile = try? EMPPulseProfile.resolve(for: commander) else {
        return "BLOCKED: EQUIPMENT"
      }
      range = profile.range
    case .combatLaser: return nil
    }
    guard
      let contact = try? nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1), range: range,
        radius: 0, includePlayer: false),
      case .body(let id) = contact.hit.target,
      let body = bodies.first(where: { $0.id == id && $0.energy > 0 })
    else { return "BLOCKED: NO WORK RAY" }
    switch selectedFlightTool {
    case .miningLaser:
      guard body.hull == .asteroid, let physical = body.physical, let rockID = physical.rock,
        physical.identity.system == systemIdentity,
        physical.identity.visit == commander.flightSimulation.visit,
        rockID.system == systemIdentity,
        let rock = miningFields.lazy.flatMap(\.rocks).first(where: { $0.identity == rockID })
      else { return "BLOCKED: NOT A ROCK" }
      guard rock.energy.isFinite, rock.energy > 0,
        commander.miningLedger.remainingEnergy(for: rock).isFinite,
        commander.miningLedger.remainingEnergy(for: rock) > 0
      else { return "BLOCKED: DEPLETED" }
      return commander.miningLedger.canAdmitMiningHit(rock: rock, damage: LaserKind.mining.damage)
        ? nil : "BLOCKED: ORE STORAGE"
    case .empPirateBlaster:
      return commander.valid && empPulseEligible(body) ? nil : "BLOCKED: EMP TARGET"
    case .salvageCutter:
      return cutterTargetBlock(body, impact: contact.hit.point)
    case .combatLaser: return nil
    }
  }

  private func cutterTargetBlock(_ body: SpaceBody, impact: Vector3) -> String? {
    guard let context = gameplayContext(), let physical = body.physical,
      let metadata = physical.salvage,
      [.wreck, .section].contains(metadata.category),
      physical.identity.system == context.system, physical.identity.visit == context.visit,
      let wreck = metadata.wreck, wreck.system == context.system
    else { return "BLOCKED: NOT SALVAGE" }
    if physical.npc != nil { return "BLOCKED: OCCUPIED" }
    if metadata.claimant != nil { return "BLOCKED: CLAIMED" }
    guard salvageCuttingIsAllowed(body, metadata: metadata, context: context) else {
      return "BLOCKED: PROTECTED"
    }
    if physical.empSource != nil,
      commander.fittedEquipment(at: .targetingSalvage) == nil
        || commander.fittedEquipment(at: .utility(.fuelScoops)) == nil
    {
      return "BLOCKED: FIT MODULE/SCOOPS"
    }
    if let hot = nativeSalvageWork, !nativeSalvageHotWorkIsCurrent(hot) {
      return "BLOCKED: WORK AUTHORITY"
    }
    guard let profile = salvageProfile(for: body) else { return "BLOCKED: NO PROFILE" }
    let pose = modelPose(of: body)
    let point = commander.flightSimulation.pose.systemPoint(impact)
    let accessible = profile.sections.contains { section in
      let identity = WreckSectionIdentity(wreck: wreck, section: section.index)
      let surface = pose.systemPoint(section.localPosition)
      return !salvageSectionIsDepleted(identity)
        && (metadata.section == nil || metadata.section == identity)
        && metadata.workSurfaces.contains { $0.section == identity }
        && (surface - point).length <= max(1, section.radius)
        && pose.orientation.apply(section.normal).dot(
          commander.flightSimulation.pose.position - surface) > 0
    }
    return accessible ? nil : "BLOCKED: NO LIVE SURFACE"
  }
}
