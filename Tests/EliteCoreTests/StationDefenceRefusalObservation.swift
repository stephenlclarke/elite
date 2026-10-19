import Foundation

@testable import EliteCore

/// One opt-in observation of the two actual CI566 refusals; never simulation authority.
enum StationDefenceRefusalObservation {
  private static let outputLock = NSLock()
  static var enabled: Bool {
    ProcessInfo.processInfo.environment["ELITE_NATIVE_DEFENCE_REFUSAL_OBSERVATION"] == "1"
  }

  static func enable(_ game: inout Game) {
    guard enabled else { return }
    if game.gameplayCombatTrace == nil { game.gameplayCombatTrace = .init() }
  }

  static func emit(
    _ game: borrowing Game, phase: String,
    facts: ScriptProcurementPreflightFacts? = nil,
    budget: ScriptProcurementPilotBudget? = nil
  ) {
    guard enabled, let snapshot = game.stationDefenceDiagnosticSnapshot() else { return }
    var values = snapshot.scalars
    values["phaseLabel"] = phase
    values["dockedPausedScreen"] = "\(game.docked),\(game.paused),\(game.screen)"
    values["stationAutoActive"] = String(game.stationAutoDockingActive)
    values["commanderValid"] = String(game.commander.valid)
    values["selectedTool"] = String(describing: game.selectedFlightTool)
    values["jumpWorkBrakingPending"] =
      "\(game.jumpCountdown != nil),\(game.workGuidance != nil),\(game.workBraking != nil),\(game.pendingNativeStationDock != nil)"
    values["targetingDockingManual"] =
      "\(game.targetingEnabled),\(game.commander.hasAutomaticDocking),\(game.autoPilot.manualEngagement)"
    values["missileArmedUnlimitedWeaponLock"] =
      "\(game.missileArmed),\(game.commander.unlimitedMissiles),\(game.weaponsTargetID.map(String.init) ?? "nil")"
    values["missileTarget"] = game.stationAutoMissileTarget().map { String($0.id) } ?? "nil"
    let context = game.gameplayContext()
    values["contextSystemVisitRevisionTime"] =
      context.map {
        "\($0.system),\($0.visit),\($0.revision),\($0.physicalTime)"
      } ?? "nil"
    var stationRanges: [String] = []
    for station in game.bodies.filter({ $0.hull == .station }).prefix(8) {
      let current = game.nativeStationBodyIsCurrent(station)
      stationRanges.append(
        "\(station.id):\(station.position.length):\(station.nativeStationIdentity != nil):\(current)"
      )
    }
    values["stationRanges"] = stationRanges.joined(separator: ";")
    if let target = game.bodies.first(where: { $0.hostile }) {
      let muzzle = Vector3(0, 0, 24)
      let offset = target.position - muzzle
      for (label, origin, direction, range) in [
        ("front", Vector3(0, 0, 0), Vector3(0, 0, 1), 6000.0),
        (
          "muzzle", Vector3(0, 0, 0), Vector3(0, 0, 1),
          24 + OrdnanceProfile.standardMissile.speed * 0.1
        ),
        ("homing", muzzle, offset.unit, offset.length),
      ] {
        do {
          if let contact = try game.nearestMissionCollision(
            from: origin, direction: direction, range: range, radius: 0,
            excludingBodyIDs: [], includePlayer: false)
          {
            values["contact_" + label] =
              "\(contact.hit.target),\(contact.hit.distance),body:\(contact.selectedTargetBody?.id ?? -1)"
          } else {
            values["contact_" + label] = "nil"
          }
        } catch { values["contact_" + label] = "error:\(error)" }
      }
    }
    var count = 0
    for body in game.bodies where body.hostile || body.physical?.ordnance != nil {
      guard count < 8 else { break }
      count += 1
      let prefix = "body_\(body.id)_"
      values[prefix + "positionEnergy"] =
        "\(body.position.x),\(body.position.y),\(body.position.z),\(body.energy)"
      values[prefix + "identityCatalogue"] =
        "\(String(describing: body.physical?.identity)),\(body.physical?.catalogueShipID ?? "nil")"
      values[prefix + "npc"] =
        "\(String(describing: body.physical?.npc?.role)),\(String(describing: body.physical?.npc?.intention)),\(body.physical?.npc?.legal.value ?? -1),\(body.physical?.npc?.resources?.valid ?? false)"
      values[prefix + "EMPSourceSalvageScriptProtected"] =
        "\(game.isEMPDisabled(body)),\(body.physical?.empSource != nil),\(body.physical?.salvage != nil),\(body.scriptNPC != nil),\(!body.gameplayProtectionReasons.isEmpty)"
      values[prefix + "ordnance"] =
        "\(body.enemyMissile),\(String(describing: body.physical?.ordnance?.target)),\(String(describing: body.physical?.ordnance?.termination))"
      if let context, let physical = body.physical {
        let actors = context.actors.filter { $0.identity == physical.identity }
        values[prefix + "joinLaw"] =
          "\(actors.count),\(actors.first?.npc == physical.npc),\(actors.first?.energy == body.energy),\(game.commander.crimeLedger.permitsAutonomousDefence(owner: context.player.identity, victim: physical.identity, context: context))"
      }
    }
    if let facts {
      values["factsValidLivePausedAutomatic"] =
        "\(facts.valid),\(facts.live),\(facts.paused),\(facts.automaticEngaged)"
      values["factsIdentityThreat"] =
        "\(String(describing: facts.identity)),\(String(describing: facts.threat))"
      values["factsLegalZoneHitCombatFrontHeat"] =
        "\(facts.legal),\(facts.outsideNoFireZones),\(facts.exactForwardHit),\(facts.combatLaser),\(facts.frontLaser),\(facts.pulseHeatBlocked)"
      values["factsRequestedAction"] = String(describing: facts.requestedAction(steps: 0))
      values["policyRequestsFallback"] = String(
        ScriptProcurementMissilePolicy.requestsFallback(
          facts, steps: 0, pulse: game.commander.laser(on: .front) == .pulse,
          heat: game.laserHeat, cooldown: game.missileCooldown, rounds: game.commander.missiles,
          unlimited: game.commander.unlimitedMissiles, ownMissile: false))
    }
    if let budget {
      values["budgetStepsTabsToolsAttemptsOriginals"] =
        "\(budget.steps),\(budget.tabs),\(budget.tools),\(budget.missileDefence.attempted.count),\(budget.missileDefence.originals?.count ?? -1)"
    }
    // Strings keep nonfinite values representable. Bound each record independently.
    let bounded = values.mapValues { String($0.prefix(768)) }
    guard let data = try? JSONSerialization.data(withJSONObject: bounded, options: [.sortedKeys]),
      data.count <= 32768
    else { return }
    var record = Data("NATIVE_DEFENCE_REFUSAL_OBSERVATION ".utf8)
    record.append(data)
    record.append(Data("\n".utf8))
    outputLock.lock()
    defer { outputLock.unlock() }
    FileHandle.standardError.write(record)
  }
}
