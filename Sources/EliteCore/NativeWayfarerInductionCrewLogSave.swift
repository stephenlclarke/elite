import Foundation

enum NativeInductionCrewLogSave {
  static let version = 125
  static let alienVersion = 126
  static func supportsAccreditation(_ schema: Int?) -> Bool {
    schema == version || schema == alienVersion || schema == 127 || schema == 128
  }
  static func supportsNetworkCertification(_ schema: Int?) -> Bool {
    supportsAccreditation(schema) || schema == 123 || schema == 124
  }
  static func supportsCharterAudit(_ schema: Int?) -> Bool {
    supportsNetworkCertification(schema) || schema == 119 || schema == 120 || schema == 121
      || schema == 122
  }
  static func supportsSeed(_ schema: Int?) -> Bool {
    supportsCharterAudit(schema) || schema == 117 || schema == 118
  }
  static func supportsWorkshop(_ schema: Int?) -> Bool {
    supportsSeed(schema) || schema == 115 || schema == 116
  }
  static func supportsClinicCustody(_ schema: Int?) -> Bool {
    supportsWorkshop(schema) || schema == 113 || schema == 114
  }
  static func supportsClinicAcceptance(_ schema: Int?) -> Bool {
    supportsClinicCustody(schema) || schema == 111 || schema == 112
  }
  static func supportsClinicSource(_ schema: Int?) -> Bool {
    supportsClinicAcceptance(schema) || schema == 109 || schema == 110
  }
  static func supportsCharterConsent(_ schema: Int?) -> Bool {
    supportsClinicSource(schema) || schema == 107 || schema == 108
  }
  static func supportsCharterCapacity(_ schema: Int?) -> Bool {
    supportsCharterConsent(schema) || schema == 105 || schema == 106
  }
  static func supportsUtilityBinding(_ schema: Int?) -> Bool {
    supportsCharterCapacity(schema) || schema == 103 || schema == 104
  }
  static func supportsCharterChoice(_ schema: Int?) -> Bool {
    supportsUtilityBinding(schema) || schema == 101 || schema == 102
  }
  static func supportsUtilityWork(_ schema: Int?) -> Bool {
    supportsCharterChoice(schema) || schema == 99 || schema == 100
  }
  static func supportsUtilitySource(_ schema: Int?) -> Bool {
    supportsUtilityWork(schema) || schema == 97 || schema == 98
  }
  static func supportsRescueReceiving(_ schema: Int?) -> Bool {
    supportsUtilitySource(schema) || schema == 95 || schema == 96
  }
  static func supportsRescueService(_ schema: Int?) -> Bool {
    supportsRescueReceiving(schema) || schema == 93 || schema == 94
  }
  static func supportsRescueFlight(_ schema: Int?) -> Bool {
    supportsRescueService(schema) || schema == 91 || schema == 92
  }
  static func supportsRescueFunding(_ schema: Int?) -> Bool {
    supportsRescueFlight(schema) || schema == 89 || schema == 90
  }
  static func supportsHullCustody(_ schema: Int?) -> Bool {
    supportsRescueFunding(schema) || schema == 87 || schema == 88
  }
  static func supportsPickup(_ schema: Int?) -> Bool {
    supportsHullCustody(schema) || schema == 85 || schema == 86
  }
  static func contains(_ schema: Int?) -> Bool {
    supportsPickup(schema) || schema == 83 || schema == 84
  }
  static func hasClaims(_ commander: borrowing Commander) -> Bool {
    commander.scriptState.instances.values.contains {
      NativeInductionCrewLogPack.marked($0) || NativeInductionUtilityPack.marked($0)
        || $0.savedWayfarerInduction?.charterClinicSource != nil
        || $0.savedWayfarerInduction?.charterSeedSource != nil
        || NativeInductionSeedPack.marked($0) || $0.savedNativeInductionSeed != nil
        || $0.savedWayfarerInduction?.charterWorkshopSource != nil
        || NativeInductionWorkshopPack.marked($0) || $0.savedNativeInductionWorkshop != nil
        || NativeInductionClinicPack.marked($0) || $0.savedNativeInductionClinic != nil
    }
  }

  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    guard recorderClaimsValid(commander) else { return false }
    // A parent cannot claim pickup or receiving without the same original source job and receipt.
    guard NativeInductionUtilitySave.validateClaims(commander),
      NativeInductionClinicSave.validateClaims(commander),
      NativeInductionWorkshopSave.validateClaims(commander),
      NativeInductionSeedSave.validateClaims(commander)
    else { return false }
    return parentClaimsValid(commander)
  }

  // Release completed recorder-validation temporaries before validating later child claims.
  @inline(never)
  private static func recorderClaimsValid(_ commander: borrowing Commander) -> Bool {
    let engine = commander.scriptState
    let jobs = engine.instances.values.filter { NativeInductionCrewLogPack.marked($0) }
    guard jobs.count <= 1 else { return false }
    for child in jobs {
      guard let state = child.savedNativeCrewLog,
        let parent = engine.instances[state.authorization.manifest.mission],
        let leaf = parent.savedWayfarerInduction,
        parent.definition == NativeWayfarerInduction.stateID,
        parent.version == NativeWayfarerInduction.version,
        parent.digest == NativeWayfarerInduction.digest,
        let source = try? NativeInductionCrewLogSource(parent: leaf),
        state.shapeValid(parent: leaf), state.capture == leaf.crewLog,
        state.authorization.manifest == source.manifest,
        state.authorization.manifest.owner == commander.equipmentOwnerID,
        state.authorization.sequence <= engine.nextEvent,
        state.authorization.stationActor.visit <= commander.flightSimulation.visit,
        state.authorization.physicalTime <= commander.flightSimulation.physicalTime,
        state.authorization.flightSeconds <= engine.flightSeconds,
        commander.nativeStations?.mainStations.contains(where: {
          $0.world == source.manifest.owner && $0.system == NativeInductionCrewLogSource.location
        }) == true,
        parent.hasAcknowledged(state.authorization.sequence),
        child.hasAcknowledged(state.authorization.sequence),
        child.id == state.authorization.job,
        child.definition == NativeInductionCrewLogPack.stateID,
        child.version == NativeInductionCrewLogPack.version,
        child.digest == NativeInductionCrewLogPack.digest,
        child.outcome == .active, child.contract == nil, child.completionReceipt == nil,
        child.dialogue == nil, child.payloads.isEmpty, child.gearIssues.isEmpty,
        child.milestones
          == (state.capture == nil ? [] : state.rescueReception == nil ? [0] : [0, 1]),
        child.data == .object([:]),
        child.campaignParent == nil,
        child.campaignChildren.isEmpty,
        child.timers.keys.allSatisfy({ $0 == NativeInductionCrewLogPack.timer }),
        actorClaimsValid(child, state: state, source: source, commander: commander),
        NativeRescueFlightSave.valid(
          state, parent: parent, child: child, source: source, commander: commander)
      else { return false }
      if let funding = state.rescueFuel?.funding {
        guard funding.sequence <= engine.nextEvent,
          parent.hasAcknowledged(funding.sequence), child.hasAcknowledged(funding.sequence),
          funding.physicalTime <= commander.flightSimulation.physicalTime,
          funding.flightSeconds <= engine.flightSeconds
        else { return false }
        if let dock = funding.legacyRebriefDock {
          guard commander.nativeStations?.mainStations.contains(dock.station) == true,
            dock.sequence < (commander.nativeStations?.nextMainDockSequence ?? 0),
            dock.actor.visit <= commander.flightSimulation.visit
          else { return false }
        }
      }
      if let capture = state.capture {
        if leaf.crewLogLoss == nil && leaf.rescueReception == nil {
          guard leaf.crewLogCarrier == commander.hullInstanceID,
            let revision = commander.equipmentInventory?.revision,
            revision >= (leaf.crewLogInventoryRevision ?? UInt64.max)
          else { return false }
        }
        guard capture.sequence <= engine.nextEvent,
          child.hasAcknowledged(capture.sequence), parent.hasAcknowledged(capture.sequence),
          capture.actor.visit <= commander.flightSimulation.visit,
          capture.physicalTime <= commander.flightSimulation.physicalTime,
          capture.flightSeconds <= engine.flightSeconds
        else { return false }
      }
    }
    return true
  }

  @inline(never)
  private static func parentClaimsValid(_ commander: borrowing Commander) -> Bool {
    let engine = commander.scriptState
    return engine.instances.values.allSatisfy { parent in
      guard let capture = parent.savedWayfarerInduction?.crewLog else { return true }
      guard let source = engine.instances[capture.job]?.savedNativeCrewLog else { return false }
      return source.capture == capture
        && source.rescueReception == parent.savedWayfarerInduction?.rescueReception
    }
  }

  static func actorClaimsValid(
    _ child: ScriptInstance, state: NativeInductionCrewLogState,
    source: NativeInductionCrewLogSource, commander: borrowing Commander
  ) -> Bool {
    if child.ownedEncounters.isEmpty { return state.admission == nil && state.losses.isEmpty }
    guard child.ownedEncounters.count == 1,
      let group = child.ownedEncounters[NativeInductionCrewLogPack.encounter],
      group.id == NativeInductionCrewLogPack.encounter, group.galaxy == 0, group.system == 211,
      group.actors.count == 3, group.admitted || state.admission == nil
    else { return false }
    if let admission = state.admission {
      guard admission.physicalTime <= commander.flightSimulation.physicalTime,
        admission.tender.visit <= commander.flightSimulation.visit
      else { return false }
    }
    for role in NativeInductionCrewLogRole.allCases {
      guard let actor = group.actors[role.rawValue],
        actor.alias == role.rawValue,
        actor.identity == NativeInductionCrewLogPack.actor(job: child.id, role: role),
        actor.body.missionActorID == actor.identity, actor.body.missionInstanceID == child.id,
        !actor.body.hostile, let npc = actor.body.scriptNPC,
        source.matchesFit(npc.fit, recorder: role == .recorder),
        role != .tender || npc.components["drive"]?.energy == 0,
        actor.body.physical?.empSource == nil, actor.body.physical?.empCrewPod == nil
      else { return false }
      if role == .launch, let flight = state.flight {
        guard
          NativeRescueFlightSave.actorValid(
            actor, flight: flight, root: state.authorization, commander: commander)
        else { return false }
        if let loss = state.losses.first(where: { $0.role == "launch" }) {
          guard actor.presence == .destroyed, actor.body.energy == 0,
            actor.body.physical?.identity == loss.actor,
            loss.physicalTime <= commander.flightSimulation.physicalTime
          else { return false }
        }
        continue
      }
      guard actor.location(in: group) == NativeInductionCrewLogSource.location,
        actor.transitLocation == nil, ![.inTransit, .arrivalPending].contains(actor.presence),
        npc.intent == nil, npc.velocity == .init(0, 0, 0)
      else { return false }
      if group.admitted {
        guard let native = actor.body.physical,
          native.population == .mission, native.npc?.role == .mission,
          native.identity.system == NativeInductionCrewLogSource.location,
          native.identity.visit >= state.authorization.stationActor.visit,
          native.identity.visit <= commander.flightSimulation.visit,
          native.identity.entity > 1, native.identity.entity < commander.flightSimulation.nextActor,
          native.ordnance == nil, native.rock == nil, native.salvage == nil,
          native.empSource == nil, native.empCrewPod == nil
        else { return false }
      }
      if role == .recorder, let capture = state.capture {
        guard actor.presence == .outside, actor.body.energy > 0,
          actor.body.physical?.identity == capture.actor
        else { return false }
      }
      if let loss = state.losses.first(where: { $0.role == role.rawValue }) {
        guard actor.presence == .destroyed, actor.body.energy == 0,
          actor.body.physical?.identity == loss.actor,
          loss.physicalTime <= commander.flightSimulation.physicalTime
        else { return false }
      }
    }
    // Actual admission/destruction can precede its secondary observation publication.
    return true
  }
}
