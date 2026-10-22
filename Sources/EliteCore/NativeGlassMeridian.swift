import Foundation

struct NativeGlassMeridianDefinition: Codable, Sendable, Equatable {
  let profile: String
  var valid: Bool { profile == "native-clock-pair-v1" }
}
struct NativeGlassMeridianPermission: Codable, Sendable, Equatable {
  let mission: UUID
  let operation: UUID
  let owner: UUID
  let dock: NativeMainStationDockReceipt
  let carrier: UUID
  let inventoryRevision: UInt64
  let fit: [EquipmentPurchaseItem]
  let visited: [NativeMainStationIdentity]
  let identified: [FleetDiscoveryEvidence]
  let physicalTime: Double
}
struct NativeGlassMeridianReading: Codable, Sendable, Equatable {
  let reading: NativeOriginalSurveyReading
  let authority: NativeOriginalSurveyAuthority
}
struct NativeGlassMeridianMarkerLoss: Codable, Sendable, Equatable {
  let ordinal: Int
  let generation: Int
  let marker: ScriptOwnedActor
  let physicalTime: Double
}

struct NativeGlassMeridianState: Codable, Sendable, Equatable {
  let permission: NativeGlassMeridianPermission
  var readings: [NativeGlassMeridianReading] = []
  var losses: [NativeGlassMeridianMarkerLoss] = []
  var surveyor: NativeC01SurveyorState?
}
final class NativeGlassMeridianPending: Sendable {
  let sealed: NativeGlassMeridianReading
  init(_ sealed: NativeGlassMeridianReading) { self.sealed = sealed }
}
struct NativeGlassMeridianRuntime: Sendable {
  var observation: NativeOriginalSurveyObservation?
  var pending: NativeGlassMeridianPending?
  var reason = "Select either unread certified clock in the front view."
}

enum NativeGlassMeridian {
  static let stateID = "l337.glass-meridian/glass-meridian"
  static let capability = "native-glass-meridian-v1"
  static let version = "1.0.0"
  static let digest = "9da0a7a020d3103a9ba528543b7694399fd81ef4aba2006df62219afdebcfaa8"
  static let encounters = ["meridian-clock-a", "meridian-clock-b"]
  static let markerID = "meridian-clock"
  static let targets = ["sedan-clock-a", "sedan-clock-b"]
  static let positions = [Vector3(-5000, 0, 20000), Vector3(5000, 0, 24000)]
  static let source = ContractStationIdentity(galaxy: 0, system: 7, stationClass: "main-orbital")
  static let objective = SystemIdentity(galaxy: 0, system: 185)
  static let laterStages =
    "Clocks verified. Recover the original recorder at Navidor; stages 4-9 remain unavailable. No payment or final clue."

  static func availability(_ pack: ScriptPack, accepted: Bool) -> String? {
    guard pack.manifest.stateID == stateID, pack.digest == digest,
      pack.manifest.glassMeridian?.valid == true
    else {
      return "Restore the approved Glass Meridian opening."
    }
    return accepted
      ? nil : "Use Station Contracts at the actual Avenor berth for Venn's commission."
  }

  static func clockDefinitionValid(_ value: ScriptNPCDefinition) -> Bool {
    value.valid && value.id == markerID && value.name == "Certified Glass Meridian clock beacon"
      && value.model == "catalogue:SH040" && value.scale == 1 && value.energy == 100
      && [
        value.recharge, value.speed, value.acceleration, value.pitch, value.yaw,
        value.roll, value.fuel,
      ].allSatisfy { $0 == 0 }
      && value.missiles == 0 && !value.ecm && value.bounty == 0 && value.drive == nil
      && (value.lasers ?? []).isEmpty && (value.components ?? []).isEmpty
  }

  static func actor(mission: UUID, ordinal: Int, generation: Int = 0) -> UUID {
    if generation == 0 {
      return ScriptIdentity.uuid(
        "script-actor-v2:\(mission):\(digest):\(encounters[ordinal]):\(targets[ordinal])")
    }
    return ScriptIdentity.uuid(
      "glass-clock-replacement-v1:\(mission):\(digest):\(targets[ordinal]):\(generation)")
  }
  static func qualified(
    visited: [NativeMainStationIdentity], identified: [FleetDiscoveryEvidence],
    owner: UUID
  ) -> Bool {
    visited.count <= NativeMainStationIdentity.maximumCount
      && Set(visited.map(\.system)).count >= 3
      && visited.allSatisfy { $0.valid && $0.world == owner }
      && identified.count <= 171 && Set(identified.map(\.ship)).count >= 2
      && identified.allSatisfy {
        $0.valid && $0.kind == .identification && $0.owner == owner
          && ShipCatalogue.ship($0.ship)?.catalogue.objectKind == .ship
      }
  }
  static func identifiedShips(_ discovery: NativeFleetDiscovery?) -> [FleetDiscoveryEvidence] {
    guard let discovery else { return [] }
    return discovery.entries.values.compactMap(\.identification).filter {
      ShipCatalogue.ship($0.ship)?.catalogue.objectKind == .ship
    }.sorted { $0.ship < $1.ship }
  }
  static func operation(
    mission: UUID, owner: UUID, dock: NativeMainStationDockReceipt
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "glass-meridian-permission-v1:\(mission):\(owner):\(try NativeFlightReception.hash(dock))")
  }
  static func readingOperation(permission: UUID, ordinal: Int) -> UUID {
    ScriptIdentity.uuid("glass-meridian-clock-reading-v1:\(permission):\(ordinal)")
  }
  static func readingsValid(_ state: NativeGlassMeridianState) -> Bool {
    guard state.readings.count <= 2,
      Set(state.readings.map { $0.reading.ordinal }).count == state.readings.count
    else { return false }
    var lastEnd = state.permission.physicalTime
    for sealed in state.readings {
      let r = sealed.reading
      let a = sealed.authority
      let p = state.permission
      guard (0..<2).contains(r.ordinal), r.mission == p.mission, r.permission == p.operation,
        r.owner == p.owner,
        r.operation == readingOperation(permission: p.operation, ordinal: r.ordinal),
        r.marker
          == actor(
            mission: p.mission, ordinal: r.ordinal,
            generation: state.losses.filter { $0.ordinal == r.ordinal }.count),
        r.actor.system == objective, r.player.system == objective,
        r.player.entity == 0, r.actor.entity > 1, r.actor.visit == r.player.visit,
        r.actor.visit > p.dock.actor.visit,
        r.start.isFinite, r.end.isFinite, r.qualifiedSeconds.isFinite,
        r.start >= lastEnd, r.end > r.start,
        r.start
          >= (state.losses.last(where: { $0.ordinal == r.ordinal })?.physicalTime ?? p.physicalTime),
        !state.losses.contains(where: { $0.marker.body.physical?.identity == r.actor }),
        (12...(12.1 + 1e-8)).contains(r.qualifiedSeconds),
        abs(r.end - r.start - r.qualifiedSeconds) < 1e-6,
        (120...1_000_000).contains(r.intervals),
        r.qualifiedSeconds <= Double(r.intervals) * 0.1 + 1e-6,
        r.revision == UInt64(r.ordinal + 1), a.operation == r.operation, a.id == r.authority,
        a.permission == p.operation, a.owner == p.owner, a.carrier == r.carrier,
        a.inventoryRevision == r.inventoryRevision, a.epoch == r.epoch,
        a.observedAt == r.end, a.equipment.id == r.equipment,
        a.equipment.location == .init(hull: r.carrier, slot: "targeting.core"),
        TargetingTier.allCases.contains(where: { $0.equipmentName == a.equipment.node.key }),
        EquipmentRuntimeCatalog.node(for: a.equipment.node.key) == a.equipment.node,
        a.marker.valid, a.marker.identity == r.marker,
        a.marker.alias == targets[r.ordinal], a.marker.presence == .present,
        a.marker.body.physical?.identity == r.actor, a.marker.body.energy > 0,
        !a.marker.body.hostile, a.marker.body.missionInstanceID == p.mission,
        a.marker.body.scriptNPC.map({ clockDefinitionValid($0.fit.definition) }) == true,
        a.id
          == (try? NativeOriginalSurvey.authorityIdentity(
            operation: r.operation, equipment: a.equipment,
            inventoryRevision: r.inventoryRevision, epoch: r.epoch, actor: r.actor))
      else { return false }
      lastEnd = r.end
    }
    return true
  }
}

extension Game {
  var glassMeridianMission: ScriptInstance? {
    commander.scriptState.instances.values.first { $0.definition == NativeGlassMeridian.stateID }
  }
  var glassMeridianPack: ScriptPack? {
    scriptPacks.first {
      $0.manifest.stateID == NativeGlassMeridian.stateID
        && $0.digest == NativeGlassMeridian.digest && $0.manifest.glassMeridian?.valid == true
    }
  }
  var glassMeridianScanStatus: String? {
    guard let state = glassMeridianMission?.savedGlassMeridian else { return nil }
    if state.surveyor?.loss != nil { return "MERIDIAN RECORDER LOST - ORIGINAL CANNOT BE REISSUED" }
    if state.surveyor?.held == true {
      return "MERIDIAN ORIGINAL RECORDER ABOARD - 8KG PROTECTED / STAGE FOUR UNAVAILABLE"
    }
    if state.readings.count == 2 { return NativeGlassMeridian.laterStages }
    let elapsed = nativeGlassMeridianRuntime?.observation?.seconds ?? 0
    return "MERIDIAN \(state.readings.count)/2 \(String(format: "%.1f", elapsed))/12s - "
      + (nativeGlassMeridianRuntime?.reason ?? "Select either unread clock.")
  }
}

extension ScriptPackLibrary {
  static func validateGlassMeridian(_ manifest: ScriptManifest) throws {
    guard let definition = manifest.glassMeridian else {
      guard manifest.stateID != NativeGlassMeridian.stateID,
        !manifest.capabilities.contains(NativeGlassMeridian.capability)
      else {
        throw MissionPackError("Glass Meridian requires its closed native declaration.")
      }
      return
    }
    guard definition.valid, manifest.stateID == NativeGlassMeridian.stateID,
      manifest.version == NativeGlassMeridian.version, manifest.mission.milestones.count == 9,
      Set(manifest.capabilities)
        == Set([
          "script-lua-v1", "story-v2", "durable-commands-v2",
          "profiled-encounters-v2", NativeGlassMeridian.capability,
        ]),
      manifest.handlers.count == 1, manifest.handlers.first?.event == "mission.accepted",
      manifest.board == nil, manifest.trial == nil, manifest.providerContract == nil,
      manifest.flightReception == nil, manifest.fieldRelief == nil,
      manifest.measuredExtraction == nil,
      manifest.originalSurvey == nil, manifest.orbitalOutlook == nil,
      manifest.stationJourney == nil,
      manifest.recordRecovery == nil, manifest.identifiedSalvage == nil,
      manifest.originalRescue == nil,
      manifest.orbitalEvacuation == nil, manifest.courier == nil, manifest.freight == nil,
      manifest.procurement == nil, manifest.coldChain == nil, manifest.repairLoop == nil,
      manifest.pledge == nil,
      (manifest.dependencies ?? []).isEmpty, (manifest.dialogs ?? []).isEmpty,
      (manifest.equipment ?? []).isEmpty, (manifest.passengerParties ?? []).isEmpty,
      (manifest.children ?? []).isEmpty, (manifest.collections ?? []).isEmpty,
      (manifest.worldJobs ?? []).isEmpty, (manifest.loans ?? []).isEmpty,
      (manifest.books ?? []).isEmpty, (manifest.models ?? []).isEmpty,
      (manifest.modules ?? []).isEmpty,
      (manifest.receiptRequirements ?? []).isEmpty, (manifest.answerRequirements ?? []).isEmpty,
      (manifest.mission.requiredBooks ?? []).isEmpty,
      (manifest.mission.requiredPassengerParties ?? []).isEmpty,
      (manifest.mission.requiredCollections ?? []).isEmpty,
      (manifest.mission.requiredChoiceGroups ?? []).isEmpty,
      (manifest.mission.requiredDestructionEncounters ?? []).isEmpty,
      (manifest.mission.requiredEquipmentReturns ?? []).isEmpty,
      let npcs = manifest.npcs, npcs.count == 1, let npc = npcs.first,
      NativeGlassMeridian.clockDefinitionValid(npc),
      let encounters = manifest.encounters, encounters.count == 2
    else {
      throw MissionPackError(
        "Invalid closed Glass Meridian opening or unearned later-stage authority.")
    }
    for (ordinal, encounter) in encounters.enumerated() {
      guard encounter.id == NativeGlassMeridian.encounters[ordinal], encounter.galaxy == 0,
        encounter.system == 185, encounter.profile == "profiled-local-freeze-v1",
        encounter.actors.count == 1, let actor = encounter.actors.first,
        actor.id == NativeGlassMeridian.targets[ordinal], actor.npc == npc.id,
        actor.hull == nil, !actor.hostile,
        Vector3(actor.x, actor.y, actor.z) == NativeGlassMeridian.positions[ordinal]
      else {
        throw MissionPackError("The certified clock source, identity or placement differs.")
      }
    }
  }
}

extension Game {
  func isGlassMeridianClock(_ body: SpaceBody) -> Bool {
    guard let mission = glassMeridianMission, body.missionInstanceID == mission.id,
      body.scriptNPC?.fit.definition.id == NativeGlassMeridian.markerID
    else { return false }
    return NativeGlassMeridian.targets.indices.contains { index in
      mission.ownedEncounters[NativeGlassMeridian.encounters[index]]?
        .actors[NativeGlassMeridian.targets[index]]?.identity == body.missionActorID
    }
  }
}

extension NativeGlassMeridian {
  /// Only contiguous qualified native intervals accumulate. Different targets start their own dwell.
  static func observe(
    previous: NativeOriginalSurveyObservation?, first: NativeOriginalSurveySample,
    last: NativeOriginalSurveySample
  ) throws -> NativeOriginalSurveyObservation {
    guard first.sameAuthority(as: last), (0..<2).contains(first.ordinal),
      first.actor.system == objective, first.player.system == objective,
      first.player.entity == 0, first.actor.entity > 1,
      first.actor.visit == first.player.visit, first.actor.visit > 0,
      first.time.isFinite, last.time.isFinite, first.time >= 0, last.time <= 1e12,
      last.time > first.time, last.time - first.time <= 0.1 + 1e-9
    else {
      throw SaveError.invalidCommander
    }
    let interval = last.time - first.time
    if var prior = previous, prior.last.sameAuthority(as: first),
      abs(prior.last.time - first.time) < 1e-9,
      prior.first.sameAuthority(as: first), prior.intervals > 0,
      prior.seconds.isFinite, prior.seconds > 0, prior.seconds < 12,
      abs(prior.last.time - prior.first.time - prior.seconds) < 1e-6
    {
      prior.last = last
      prior.seconds += interval
      prior.intervals += 1
      return prior
    }
    return .init(first: first, last: last, seconds: interval, intervals: 1)
  }
}
