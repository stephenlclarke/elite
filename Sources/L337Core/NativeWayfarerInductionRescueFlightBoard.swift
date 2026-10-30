import Foundation

extension Game {
  func inductionRescueFlightIssues() -> [String] {
    guard let parent = wayfarerInductionMission?.savedWayfarerInduction,
      parent.crewLog != nil, parent.crewLogLoss == nil,
      let child = inductionCrewLogChild, child.suspension == nil,
      let state = child.savedNativeCrewLog, state.flight == nil,
      state.rescueFuel != nil, state.livingCrew.count == 2,
      let actor = child.ownedEncounters[NativeInductionCrewLogPack.encounter]?.actors["launch"],
      actor.presence != .destroyed, actor.body.energy > 0,
      actor.body.scriptNPC?.components["drive"]?.energy ?? 0 > 0,
      let source = try? NativeInductionCrewLogSource(parent: parent),
      let fit = actor.body.scriptNPC?.fit, source.matchesFit(fit, recorder: false),
      NativeInductionCrewLogSave.validateClaims(commander)
    else {
      return [
        "The same original living powered launch, held recorder and funded source are required."
      ]
    }
    guard
      (try? NativeRescueRoutePlan(source: source, escortReachLY: commander.fullTankJumpDistance))
        != nil
    else {
      return [
        "No actual original-world route fits both the launch and your full-tank navigation reach."
      ]
    }
    return []
  }

  mutating func confirmInductionRescueFlight(
    dock: NativeMainStationDockReceipt,
    carrier: UUID, revision: UInt64
  ) throws {
    guard inductionRescueFlightIssues().isEmpty, nativeMainStationDockEvidenceIsCurrent,
      commander.nativeStations?.currentMainDock == dock,
      systemIdentity == NativeInductionCrewLogSource.location,
      carrier == commander.hullInstanceID, revision == commander.equipmentInventory?.revision,
      var parent = wayfarerInductionMission, let leaf = parent.savedWayfarerInduction,
      let capture = leaf.crewLog, var child = inductionCrewLogChild,
      var state = child.savedNativeCrewLog, let bank = state.rescueFuel,
      let fuel = child.ownedEncounters[NativeInductionCrewLogPack.encounter]?.actors["launch"]?.body
        .scriptNPC?.fuel,
      child.revision < UInt64(Int64.max) - 1, parent.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let source = try NativeInductionCrewLogSource(parent: leaf)
    let route = try NativeRescueRoutePlan(
      source: source, escortReachLY: commander.fullTankJumpDistance)
    let sequence = commander.scriptState.nextEvent + 1
    let physical = commander.flightSimulation.physicalTime
    let flight = commander.scriptState.flightSeconds
    let calendar = commander.scriptState.calendarSeconds
    let operation = try NativeRescueFlightAuthorization.identity(
      registration: state.authorization.operation, funding: bank.funding.issue,
      capture: capture.operation, dock: dock, carrier: carrier, revision: revision,
      physicalTime: physical, flightSeconds: flight, calendarSeconds: calendar,
      initialFuel: fuel, sequence: sequence, route: route)
    let authorization = NativeRescueFlightAuthorization(
      registration: state.authorization.operation, funding: bank.funding.issue,
      capture: capture.operation, job: child.id,
      actor: NativeInductionCrewLogPack.actor(job: child.id, role: .launch),
      operation: operation, sequence: sequence, dock: dock, carrier: carrier,
      inventoryRevision: revision, physicalTime: physical, flightSeconds: flight,
      calendarSeconds: calendar, initialFuelLY: fuel, crew: state.authorization.manifest.crew,
      route: route)
    state.flight = .init(authorization: authorization)
    guard state.shapeValid(parent: leaf) else { throw SaveError.invalidCommander }
    guard var group = child.ownedEncounters[NativeInductionCrewLogPack.encounter],
      var launch = group.actors["launch"], let profile = launch.body.scriptNPC?.fit.definition
    else { throw SaveError.invalidCommander }
    // Leave the nearby tender/recorder and player's ship through ordinary bounded NPC motion.
    // The normal native drive keeps refusing mass lock until the real ship has cleared them.
    launch.body.scriptNPC?.intent = .init(
      request: "native-rescue-workarea-exit",
      mode: .approach, target: nil, player: false,
      offset: NativeInductionCrewLogRole.launch.offset + Vector3(0, 0, 1200),
      speed: min(1, 144 / profile.speed), tolerance: 50)
    group.actors["launch"] = launch
    child.ownedEncounters[NativeInductionCrewLogPack.encounter] = group
    child.savedNativeCrewLog = state
    child.revision += 1
    child.acknowledge(sequence)
    parent.revision += 1
    parent.acknowledge(sequence)
    parent.journal.append(
      "Confirmed the original marked rescue launch's actual Cevilis-to-Enmadan route. Its same two original crew stay aboard; retained fuel/drive govern each real wormhole departure. No tank top-up, receiving, payment or stage9 credit was granted."
    )
    commander.scriptState.nextEvent = sequence
    commander.scriptState.instances[parent.id] = parent
    commander.scriptState.instances[child.id] = child
    notify("ORIGINAL RESCUE ESCORT REGISTERED - DEPART CEVILIS")
  }
}
