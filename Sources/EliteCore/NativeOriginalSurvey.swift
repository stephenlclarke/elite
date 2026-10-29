import Foundation

/// Closed registration for the original Avenor survey; other families cannot supply targets.
struct NativeOriginalSurveyDefinition: Codable, Sendable, Equatable {
  let batch: String
  let sourceGalaxy: Int
  let sourceSystem: Int
  let surveyGalaxy: Int
  let surveySystem: Int
  let destinationGalaxy: Int
  let destinationSystem: Int
  let targets: [String]

  var valid: Bool {
    batch == NativeOriginalSurvey.batch && sourceGalaxy == 0 && sourceSystem == 7
      && surveyGalaxy == 0 && surveySystem == 185
      && destinationGalaxy == 0 && destinationSystem == 7
      && targets == NativeOriginalSurvey.targets
  }
}

/// Issued only by acceptance at the actual native station, before any observation.
struct NativeOriginalSurveyPermission: Codable, Sendable, Equatable {
  let mission: UUID
  let operation: UUID
  let dock: NativeMainStationDockReceipt
  let collector: ActorIdentity
  let carrier: UUID
  let inventoryRevision: UInt64
  let reach: ScriptCourierReach
  let path: [Int]
  let physicalTime: Double
  let epoch: UUID
}

struct NativeOriginalSurveyState: Codable, Sendable, Equatable {
  let owner: UUID
  let definition: NativeOriginalSurveyDefinition
  let version: String
  let digest: String
  let permission: NativeOriginalSurveyPermission?
  var readings: [NativeOriginalSurveyReading] = []
  var authorities: [NativeOriginalSurveyAuthority] = []
  var terminalOperation: UUID?
  var terminalDock: NativeMainStationDockReceipt?
}

enum NativeOriginalSurvey {
  static let stateID = "l337.contract/consented-survey"
  static let digest = "ff7b87f92b2896a17a7e4047b64c5ab6461e4e743cddb1ee3594998b67a1fdd6"
  static let batch = "avenor-consented-survey-01"
  static let boardID = "consented-survey"
  static let encounterID = "survey-points"
  static let markerID = "survey-marker"
  static let targets = ["calibration-a", "calibration-b", "calibration-c"]
  static let reward = 7300
  static let source = ContractStationIdentity(
    galaxy: 0, system: 7, stationClass: "main-orbital")
  static let objective = ContractStationIdentity(
    galaxy: 0, system: 185, stationClass: "main-orbital")
  static let requiredSeconds = 12.0
  static let maximumInterval = 0.1
  static let minimumRange = 250.0
  static let maximumRange = 1500.0
}

extension NativeOriginalSurvey {
  static func route(reach: ScriptCourierReach) -> [Int] {
    guard ScriptCourierGeneration.routes(origin: source, reach: reach).contains([7, 185]),
      ScriptCourierGeneration.routes(origin: objective, reach: reach).contains([185, 7])
    else { return [] }
    return [7, 185, 7]
  }

  static func sourceMatches(_ dock: NativeMainStationDockReceipt) -> Bool {
    dock.station.system == SystemIdentity(galaxy: 0, system: 7)
  }
}

extension Game {
  var originalSurveyState: NativeOriginalSurveyState? {
    for instance in commander.scriptState.instances.values {
      if instance.definition == NativeOriginalSurvey.stateID {
        return instance.savedOriginalSurvey
      }
    }
    return nil
  }
}

extension ScriptPackLibrary {
  static func validateOriginalSurvey(_ manifest: ScriptManifest) throws {
    guard let declaration = manifest.originalSurvey else {
      guard !manifest.capabilities.contains("native-consented-survey-v1") else {
        throw MissionPackError("Native survey needs its closed original declaration.")
      }
      return
    }
    let capabilities: Set<String> = [
      "script-lua-v1", "story-v2", "durable-commands-v2", "contracts-basic-v2",
      "local-flight-clocks-v2", "native-consented-survey-v1", "profiled-encounters-v2",
    ]
    guard declaration.valid, manifest.stateID == NativeOriginalSurvey.stateID,
      manifest.version == "1.0.0", Set(manifest.capabilities) == capabilities,
      manifest.mission.milestones.count == 5, manifest.board == nil,
      manifest.courier == nil, manifest.freight == nil, manifest.procurement == nil,
      manifest.pledge == nil, manifest.coldChain == nil, manifest.repairLoop == nil,
      manifest.providerContract == nil, manifest.trial == nil,
      manifest.stationJourney == nil, manifest.orbitalOutlook == nil,
      manifest.originalRescue == nil, manifest.orbitalEvacuation == nil,
      (manifest.passengerParties ?? []).isEmpty, (manifest.collections ?? []).isEmpty,
      validSurveyMarkers(manifest),
      (manifest.equipment ?? []).isEmpty, (manifest.children ?? []).isEmpty,
      (manifest.worldJobs ?? []).isEmpty, (manifest.loans ?? []).isEmpty,
      (manifest.receiptRequirements ?? []).isEmpty,
      (manifest.mission.requiredPassengerParties ?? []).isEmpty,
      (manifest.mission.requiredCollections ?? []).isEmpty,
      (manifest.mission.requiredDestructionEncounters ?? []).isEmpty,
      (manifest.mission.requiredEquipmentReturns ?? []).isEmpty,
      (manifest.mission.requiredChoiceGroups ?? []).isEmpty
    else {
      throw MissionPackError("Invalid original native consented survey declaration.")
    }
  }
}

extension ScriptPackLibrary {
  static func validSurveyMarkers(_ manifest: ScriptManifest) -> Bool {
    guard let encounters = manifest.encounters, encounters.count == 1,
      let encounter = encounters.first, encounter.id == NativeOriginalSurvey.encounterID,
      encounter.galaxy == 0, encounter.system == 185,
      encounter.profile == "profiled-local-freeze-v1", encounter.actors.count == 3,
      let npcs = manifest.npcs, npcs.count == 1, let npc = npcs.first,
      npc.valid, npc.id == "survey-marker", npc.model == "catalogue:SH040", npc.scale == 1,
      npc.energy == 100, npc.recharge == 0, npc.speed == 0, npc.acceleration == 0,
      npc.pitch == 0, npc.yaw == 0, npc.roll == 0, npc.missiles == 0, npc.fuel == 0,
      !npc.ecm, npc.bounty == 0, npc.drive == nil,
      (npc.lasers ?? []).isEmpty, (npc.components ?? []).isEmpty
    else { return false }
    let positions = [Vector3(-5000, 0, 20000), Vector3(0, 4000, 24000), Vector3(5000, 0, 28000)]
    for (index, actor) in encounter.actors.enumerated() {
      guard actor.id == NativeOriginalSurvey.targets[index], actor.npc == npc.id,
        actor.hull == nil, !actor.hostile,
        Vector3(actor.x, actor.y, actor.z) == positions[index]
      else { return false }
    }
    return true
  }
}
