import Foundation

extension Game {
  func inductionUtilityAuthorizationIssues() -> [String] {
    guard let parent = wayfarerInductionMission, parent.outcome == .active,
      parent.suspension == nil, let leaf = parent.savedWayfarerInduction,
      leaf.rescueReception != nil, inductionUtilityChild == nil,
      nativeInductionUtilityPack != nil, NativeInductionCrewLogSave.validateClaims(commander)
    else {
      return [
        "Complete actual original-survivor receiving and restore the Enron utility source; an existing authorization cannot issue another set of kits."
      ]
    }
    guard commander.scriptState.instances.count < 128 else {
      return ["The mission record capacity is full."]
    }
    return []
  }

  mutating func confirmInductionUtilityAuthorization(
    dock: NativeMainStationDockReceipt,
    carrier: UUID, revision: UInt64
  ) throws {
    guard inductionUtilityAuthorizationIssues().isEmpty, nativeMainStationDockEvidenceIsCurrent,
      commander.nativeStations?.currentMainDock == dock,
      systemIdentity == NativeInductionUtilitySource.location, commander.hullInstanceID == carrier,
      commander.equipmentInventory?.revision == revision,
      var parent = wayfarerInductionMission, let leaf = parent.savedWayfarerInduction,
      let pack = nativeInductionUtilityPack, parent.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 2
    else { throw SaveError.invalidCommander }
    let source = try NativeInductionUtilitySource(parent: leaf)
    let job = NativeInductionUtilityPack.instance(issue: source.issue)
    guard commander.scriptState.instances[job] == nil else { throw SaveError.invalidCommander }
    let sequence = commander.scriptState.nextEvent + 1
    let authorization = try NativeInductionUtilityAuthorization(
      parent: leaf, dock: dock,
      carrier: carrier, revision: revision, physicalTime: commander.flightSimulation.physicalTime,
      flightSeconds: commander.scriptState.flightSeconds, sequence: sequence)
    let state = NativeInductionUtilityState(authorization: authorization, source: source)
    guard state.shapeValid(parent: leaf) else { throw SaveError.invalidCommander }
    var child = ScriptInstance(
      id: job, definition: NativeInductionUtilityPack.stateID,
      version: NativeInductionUtilityPack.version, digest: pack.digest)
    child.savedNativeInductionUtility = state
    child.acknowledge(sequence)
    parent.acknowledge(sequence)
    parent.revision += 1
    parent.journal.append(
      "Enron's actual utility crew authorized remote maintenance of their three original external handoffs. Each retains its own sealed local repair kit and initial fault. This grants no player equipment/cargo or repair progress. Depart for actual safe native source admission."
    )
    commander.scriptState.nextEvent = sequence
    commander.scriptState.instances[parent.id] = parent
    commander.scriptState.instances[job] = child
    emitScriptEvent("mission.accepted", only: job)
    notify("ENRON MAINTENANCE AUTHORIZED - ORIGINAL HANDOFFS / KITS UNCHANGED")
  }

  var inductionUtilitySourceStatus: String? {
    guard wayfarerInductionMission?.savedWayfarerInduction?.rescueReception != nil else {
      return nil
    }
    guard let child = inductionUtilityChild, let state = child.savedNativeInductionUtility else {
      return
        "Stage10: review Enron G01-S190 utility crew authorization for the three original external handoffs. No player cargo or equipment purchase is required."
    }
    if state.admission == nil {
      return
        "Enron utility maintenance authorized; depart for native clearance/admission. Non-spinning metre reference: inlet X+60km/Y+20km, buffer X+60.3km/Y+20km, return X+60.6km/Y+20km. Faults and one local kit each remain unchanged."
    }
    return
      "Three original Enron handoffs admitted: inlet valve CLOSED, buffer relay DISCONNECTED, return bypass CLOSED; one crew-owned kit each. Separate arming/timed physical repair and receiving remain next; authorization/admission grant no stage10 progress."
  }
}
