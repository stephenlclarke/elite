import Foundation

struct WayfarerRecordRecoveryDefinition: Codable, Sendable, Equatable {
  let batch: String
  let sourceGalaxy: Int
  let sourceSystem: Int
  let collectionGalaxy: Int
  let collectionSystem: Int
  let destinationGalaxy: Int
  let destinationSystem: Int
  let serials: [String]

  var valid: Bool {
    guard batch == WayfarerRecordRecovery.batch, sourceGalaxy == 0, sourceSystem == 85,
      collectionGalaxy == 0, collectionSystem == 241, destinationGalaxy == 0,
      destinationSystem == 85, serials == WayfarerRecordRecovery.serials
    else { return false }
    return true
  }
}

struct WayfarerRecordRecoveryOriginal: Codable, Sendable, Equatable {
  let id: UUID
  let serial: String
  let name: String
  let tonnes: Int
  var custody: WayfarerRecordRecoveryCustody = .cradle
}

enum WayfarerRecordRecoveryCustody: Codable, Sendable, Equatable {
  case cradle
  case held(capture: UUID, carrier: UUID)
  case returned(UUID)
  case lost(UUID)
}

/// The depot retains title. Allocation is permanent and independent of pack/visit identities.
struct WayfarerRecordRecoverySource: Codable, Sendable, Equatable {
  let id: UUID
  let owner: NativeMainStationIdentity
  let batch: String
  var originals: [WayfarerRecordRecoveryOriginal]
  let allocatedMission: UUID
  let registration: NativeMainStationDockReceipt
}

struct WayfarerRecordRecoveryPermission: Codable, Sendable, Equatable {
  let mission: UUID
  let operation: UUID
  let source: UUID
  let dock: NativeMainStationDockReceipt
  let collector: ActorIdentity
  let carrier: UUID
  let inventoryRevision: UInt64
  let reach: ScriptCourierReach
  let path: [Int]
  let physicalTime: Double
  let epoch: UUID
}

struct WayfarerRecordRecoveryObservation: Codable, Sendable, Equatable {
  let original: UUID
  let permission: UUID
  let owner: UUID
  let carrier: UUID
  let actor: ActorIdentity
  let player: ActorIdentity
  let inventoryRevision: UInt64
  let equipment: [EquipmentPurchaseItem]
  let markers: [ScriptOwnedActor]
  let targetPoint: Vector3
  let surfacePoint: Vector3
  let surfaceDistance: Double
  let physicalTime: Double
  let epoch: UUID

  func sameAuthority(as other: Self) -> Bool {
    original == other.original && permission == other.permission && owner == other.owner
      && carrier == other.carrier && actor == other.actor && player == other.player
      && inventoryRevision == other.inventoryRevision && equipment == other.equipment
      && epoch == other.epoch
  }
}

struct WayfarerRecordRecoveryIdentification: Codable, Sendable, Equatable {
  let operation: UUID
  let source: UUID
  let permission: UUID
  let original: UUID
  var authority: UUID
  let observations: [WayfarerRecordRecoveryObservation]
}

struct WayfarerRecordRecoveryCapture: Codable, Sendable, Equatable {
  let identification: UUID
  let original: UUID
  let operation: UUID
  let authority: UUID
  let logicalActor: UUID
  let actor: ActorIdentity
  let collector: ActorIdentity
  let carrier: UUID
  let inventoryRevision: UInt64
  let equipment: [EquipmentPurchaseItem]
  let marker: [ScriptOwnedActor]
  let capturePoint: Vector3
  let relativeSpeed: Double
  let startTime: Double
  let physicalTime: Double
  let epoch: UUID
}

enum WayfarerRecordRecoveryLossKind: String, Codable, Sendable {
  case destroyed, hull, escape
}

struct WayfarerRecordRecoveryLoss: Codable, Sendable, Equatable {
  let original: UUID
  let operation: UUID
  var authority: UUID
  let kind: WayfarerRecordRecoveryLossKind
  let actor: ActorIdentity
  let carrier: UUID
  let collector: ActorIdentity
  let energy: Double
  let escapePod: EquipmentPurchaseItem?
  let marker: [ScriptOwnedActor]
  let context: ScriptEventContext
  let physicalTime: Double
  let epoch: UUID
}

struct WayfarerRecordRecoveryReception: Codable, Sendable, Equatable {
  let operation: UUID
  let dock: NativeMainStationDockReceipt
  let carrier: UUID
  let originals: [UUID]
  let complete: Bool
  let cause: ScriptEventContext
  let committed: ScriptEventContext
}

struct WayfarerRecordRecoveryState: Codable, Sendable, Equatable {
  let source: UUID
  let definition: WayfarerRecordRecoveryDefinition
  let permission: WayfarerRecordRecoveryPermission
  var identification: WayfarerRecordRecoveryIdentification?
  var captures: [WayfarerRecordRecoveryCapture] = []
  var losses: [WayfarerRecordRecoveryLoss] = []
  var reception: WayfarerRecordRecoveryReception?

  var held: [UUID] {
    let lost = Set(losses.map(\.original))
    let returned = Set(reception?.originals ?? [])
    return captures.map(\.original).filter { id in
      !lost.contains(id) && !returned.contains(id)
    }
  }
}

enum WayfarerRecordRecovery {
  static let stateID = "l337.wayfarer-service/record-recovery"
  static let digest = "460df445d7249498185e0ef150366b91eafddfdfc651968182cf487f9e208578"
  static let batch = "cedamar-flight-record-01"
  static let boardID = "record-recovery"
  static let encounterID = "w05-wreck"
  static let serials = ["CDR-001"]
  static let aliases = ["cdr-001"]
  static let names = ["Sealed flight/custody recorder"]
  static let source = ContractStationIdentity(galaxy: 0, system: 85, stationClass: "main-orbital")
  static let objective = ContractStationIdentity(
    galaxy: 0, system: 241, stationClass: "main-orbital")
  static let reward = 6500
  static let packageGeometry = "5362f0948c8a6f1b2acc770b100f746ff3f55799db7c0c53261f02943c6a680e"
  static let cradleGeometry = "6bd163387c2fa30eaa34027add90ebb9eb377e87b46b996afd6979beaadfd813"

  static func sourceIdentity(_ owner: NativeMainStationIdentity) -> UUID {
    ScriptIdentity.uuid("record-recovery-source-v1:\(owner.world):\(owner.resource):\(batch)")
  }

  static func originals(_ owner: NativeMainStationIdentity) -> [WayfarerRecordRecoveryOriginal] {
    serials.enumerated().map { index, serial in
      .init(
        id: ScriptIdentity.uuid(
          "record-recovery-original-v1:\(owner.world):\(owner.resource):\(batch):\(serial)"),
        serial: serial, name: names[index], tonnes: 1)
    }
  }

  static func originalIdentitiesValid(_ source: borrowing WayfarerRecordRecoverySource) -> Bool {
    let expected = originals(source.owner)
    guard source.originals.count == expected.count else { return false }
    for index in expected.indices {
      guard source.originals[index].id == expected[index].id,
        source.originals[index].serial == expected[index].serial,
        source.originals[index].name == expected[index].name,
        source.originals[index].tonnes == expected[index].tonnes
      else { return false }
    }
    return true
  }

  static func actorIdentity(mission: UUID, digest: String, alias: String) -> UUID {
    ScriptIdentity.uuid("script-actor-v2:\(mission):\(digest):\(encounterID):\(alias)")
  }

  static func route(reach: ScriptCourierReach) -> [Int] {
    guard ScriptCourierGeneration.routes(origin: source, reach: reach).contains([85, 241]),
      ScriptCourierGeneration.routes(origin: objective, reach: reach).contains([241, 85])
    else { return [] }
    return [85, 241, 85]
  }

  static func payloads(
    _ state: borrowing WayfarerRecordRecoveryState, outcome: ScriptOutcome,
    source: borrowing WayfarerRecordRecoverySource
  ) -> [String: Int] {
    var result: [String: Int] = [:]
    let held = state.held
    for original in source.originals {
      if held.contains(original.id) {
        result[original.serial.lowercased()] = 1
      } else if outcome == .active {
        if !state.losses.contains(where: { $0.original == original.id }) {
          result[original.serial.lowercased()] = 1
        }
      }
    }
    return result
  }

  static func marker(_ body: borrowing SpaceBody, commander: borrowing Commander) -> Bool {
    guard let mission = body.missionInstanceID else { return false }
    for index in commander.scriptState.instances.indices {
      guard commander.scriptState.instances.keys[index] == mission else { continue }
      return commander.scriptState.instances.values[index].definition == stateID
    }
    return false
  }

  static func consumed(_ actor: UUID, commander: borrowing Commander) -> Bool {
    guard let source = commander.scriptState.savedRecordRecoverySource,
      originalIdentitiesValid(source)
    else { return false }
    for instance in commander.scriptState.instances.values {
      guard instance.definition == stateID, instance.digest == digest,
        let state = instance.savedRecordRecovery, state.source == source.id,
        source.allocatedMission == instance.id
      else { continue }
      for index in state.captures.indices {
        if state.captures[index].logicalActor == actor {
          guard let identification = state.identification,
            WayfarerRecordRecoverySave.identificationValid(
              identification, state: state, source: source, commander: commander)
          else { return false }
          return WayfarerRecordRecoverySave.captureValid(
            state.captures[index], state: state, source: source, commander: commander)
        }
      }
    }
    return false
  }
}

extension Game {
  var recordRecoveryState: WayfarerRecordRecoveryState? {
    for instance in commander.scriptState.instances.values {
      if instance.definition == WayfarerRecordRecovery.stateID {
        return instance.savedRecordRecovery
      }
    }
    return nil
  }
}

extension WayfarerRecordRecovery {
  static func npcValid(_ npc: borrowing ScriptNPCDefinition, package: Bool) -> Bool {
    let model = package ? "catalogue:SH058" : "catalogue:SH141"
    let id = package ? "w05-flight-recorder" : "w05-record-cradle"
    let scale = package ? 0.2 : 1.0
    guard npc.valid, npc.id == id, npc.model == model, npc.scale == scale,
      npc.energy == 100, npc.recharge == 0, npc.speed == 0, npc.acceleration == 0,
      npc.pitch == 0, npc.yaw == 0, npc.roll == 0, npc.fuel == 0, npc.missiles == 0,
      !npc.ecm, npc.bounty == 0, npc.drive == nil,
      (npc.lasers ?? []).isEmpty, (npc.components ?? []).isEmpty
    else { return false }
    return true
  }
}

extension ScriptPackLibrary {
  static func validateRecordRecovery(_ manifest: ScriptManifest) throws {
    guard let declaration = manifest.recordRecovery else {
      guard !manifest.capabilities.contains("native-record-recovery-v1") else {
        throw MissionPackError("Native recovery needs its original depot declaration.")
      }
      return
    }
    let capabilities: Set<String> = [
      "script-lua-v1", "story-v2", "durable-commands-v2", "contracts-basic-v2",
      "local-flight-clocks-v2", "native-record-recovery-v1", "profiled-encounters-v2",
    ]
    guard declaration.valid, manifest.stateID == WayfarerRecordRecovery.stateID,
      manifest.version == "1.0.0", Set(manifest.capabilities) == capabilities,
      manifest.mission.milestones.count == 4, manifest.board == nil,
      manifest.courier == nil, manifest.freight == nil, manifest.procurement == nil,
      manifest.pledge == nil, manifest.coldChain == nil, manifest.repairLoop == nil,
      manifest.providerContract == nil, manifest.trial == nil,
      manifest.stationJourney == nil, manifest.orbitalOutlook == nil,
      manifest.identifiedSalvage == nil, manifest.originalSurvey == nil,
      manifest.originalRescue == nil,
      manifest.orbitalEvacuation == nil,
      (manifest.passengerParties ?? []).isEmpty, (manifest.collections ?? []).isEmpty,
      (manifest.equipment ?? []).isEmpty, (manifest.children ?? []).isEmpty,
      (manifest.worldJobs ?? []).isEmpty, (manifest.loans ?? []).isEmpty,
      (manifest.receiptRequirements ?? []).isEmpty,
      (manifest.mission.requiredPassengerParties ?? []).isEmpty,
      (manifest.mission.requiredCollections ?? []).isEmpty,
      (manifest.mission.requiredDestructionEncounters ?? []).isEmpty,
      (manifest.mission.requiredEquipmentReturns ?? []).isEmpty,
      (manifest.mission.requiredChoiceGroups ?? []).isEmpty,
      let encounters = manifest.encounters, encounters.count == 1,
      let encounter = encounters.first, encounter.id == WayfarerRecordRecovery.encounterID,
      encounter.galaxy == 0, encounter.system == 241,
      encounter.profile == "profiled-local-freeze-v1", encounter.actors.count == 2,
      let npcs = manifest.npcs, npcs.count == 2,
      WayfarerRecordRecovery.npcValid(npcs[0], package: false),
      WayfarerRecordRecovery.npcValid(npcs[1], package: true)
    else { throw MissionPackError("Invalid original record-recovery declaration.") }
    let aliases = ["w05-cradle"] + WayfarerRecordRecovery.aliases
    let positions = [Vector3(0, 0, 24000), Vector3(-2000, 0, 24000)]
    for (index, actor) in encounter.actors.enumerated() {
      guard actor.id == aliases[index], actor.npc == npcs[index == 0 ? 0 : 1].id,
        actor.hull == nil, !actor.hostile,
        Vector3(actor.x, actor.y, actor.z) == positions[index]
      else { throw MissionPackError("The registered recovery poses or actor identities changed.") }
    }
  }
}
