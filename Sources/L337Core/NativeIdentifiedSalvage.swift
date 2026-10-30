import Foundation

struct NativeIdentifiedSalvageDefinition: Codable, Sendable, Equatable {
  let batch: String
  let sourceGalaxy: Int
  let sourceSystem: Int
  let collectionGalaxy: Int
  let collectionSystem: Int
  let destinationGalaxy: Int
  let destinationSystem: Int
  let serials: [String]

  var valid: Bool {
    guard batch == NativeIdentifiedSalvage.batch, sourceGalaxy == 0, sourceSystem == 7,
      collectionGalaxy == 0, collectionSystem == 185, destinationGalaxy == 0,
      destinationSystem == 7, serials == NativeIdentifiedSalvage.serials
    else { return false }
    return true
  }
}

struct NativeIdentifiedSalvageOriginal: Codable, Sendable, Equatable {
  let id: UUID
  let serial: String
  let name: String
  let tonnes: Int
  var custody: NativeIdentifiedSalvageCustody = .cradle
}

enum NativeIdentifiedSalvageCustody: Codable, Sendable, Equatable {
  case cradle
  case held(capture: UUID, carrier: UUID)
  case returned(UUID)
  case lost(UUID)
}

/// The depot retains title. Allocation is permanent and independent of pack/visit identities.
struct NativeIdentifiedSalvageSource: Codable, Sendable, Equatable {
  let id: UUID
  let owner: NativeMainStationIdentity
  let batch: String
  var originals: [NativeIdentifiedSalvageOriginal]
  let allocatedMission: UUID
  let registration: NativeMainStationDockReceipt
}

struct NativeIdentifiedSalvagePermission: Codable, Sendable, Equatable {
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

struct NativeIdentifiedSalvageCapture: Codable, Sendable, Equatable {
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

enum NativeIdentifiedSalvageLossKind: String, Codable, Sendable {
  case destroyed, hull, escape
}

struct NativeIdentifiedSalvageLoss: Codable, Sendable, Equatable {
  let original: UUID
  let operation: UUID
  var authority: UUID
  let kind: NativeIdentifiedSalvageLossKind
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

struct NativeIdentifiedSalvageReception: Codable, Sendable, Equatable {
  let operation: UUID
  let dock: NativeMainStationDockReceipt
  let carrier: UUID
  let originals: [UUID]
  let complete: Bool
  let cause: ScriptEventContext
  let committed: ScriptEventContext
}

struct NativeIdentifiedSalvageState: Codable, Sendable, Equatable {
  let source: UUID
  let definition: NativeIdentifiedSalvageDefinition
  let permission: NativeIdentifiedSalvagePermission
  var captures: [NativeIdentifiedSalvageCapture] = []
  var losses: [NativeIdentifiedSalvageLoss] = []
  var reception: NativeIdentifiedSalvageReception?

  var held: [UUID] {
    let lost = Set(losses.map(\.original))
    let returned = Set(reception?.originals ?? [])
    return captures.map(\.original).filter { id in
      !lost.contains(id) && !returned.contains(id)
    }
  }
}

enum NativeIdentifiedSalvage {
  static let stateID = "l337.contract/identified-salvage"
  static let digest = "ee65a469de1673c440e9b12effd8df2ff3bed96120d9e4b4c78a7c6bf8ab5e5c"
  static let batch = "avenor-pell-cradle-01"
  static let boardID = "identified-salvage"
  static let encounterID = "pell-wreck"
  static let serials = ["PELL-01", "PELL-02"]
  static let aliases = ["pell-01", "pell-02"]
  static let names = ["Sealed utility controller", "Sealed power regulator"]
  static let source = ContractStationIdentity(galaxy: 0, system: 7, stationClass: "main-orbital")
  static let objective = ContractStationIdentity(
    galaxy: 0, system: 185, stationClass: "main-orbital")
  static let reward = 8800
  static let packageGeometry = "5362f0948c8a6f1b2acc770b100f746ff3f55799db7c0c53261f02943c6a680e"
  static let cradleGeometry = "6bd163387c2fa30eaa34027add90ebb9eb377e87b46b996afd6979beaadfd813"

  static func sourceIdentity(_ owner: NativeMainStationIdentity) -> UUID {
    ScriptIdentity.uuid("identified-salvage-source-v1:\(owner.world):\(owner.resource):\(batch)")
  }

  static func originals(_ owner: NativeMainStationIdentity) -> [NativeIdentifiedSalvageOriginal] {
    serials.enumerated().map { index, serial in
      .init(
        id: ScriptIdentity.uuid(
          "identified-salvage-original-v1:\(owner.world):\(owner.resource):\(batch):\(serial)"),
        serial: serial, name: names[index], tonnes: 1)
    }
  }

  static func originalIdentitiesValid(_ source: borrowing NativeIdentifiedSalvageSource) -> Bool {
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
    guard ScriptCourierGeneration.routes(origin: source, reach: reach).contains([7, 185]),
      ScriptCourierGeneration.routes(origin: objective, reach: reach).contains([185, 7])
    else { return [] }
    return [7, 185, 7]
  }

  static func payloads(
    _ state: borrowing NativeIdentifiedSalvageState, outcome: ScriptOutcome,
    source: borrowing NativeIdentifiedSalvageSource
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
    guard let source = commander.scriptState.savedIdentifiedSalvageSource,
      originalIdentitiesValid(source)
    else { return false }
    for instance in commander.scriptState.instances.values {
      guard instance.definition == stateID, instance.digest == digest,
        let state = instance.savedIdentifiedSalvage, state.source == source.id,
        source.allocatedMission == instance.id
      else { continue }
      for index in state.captures.indices {
        if state.captures[index].logicalActor == actor {
          return NativeIdentifiedSalvageSave.captureValid(
            state.captures[index], state: state, source: source, commander: commander)
        }
      }
    }
    return false
  }
}

extension Game {
  var identifiedSalvageState: NativeIdentifiedSalvageState? {
    for instance in commander.scriptState.instances.values {
      if instance.definition == NativeIdentifiedSalvage.stateID {
        return instance.savedIdentifiedSalvage
      }
    }
    return nil
  }
}

extension NativeIdentifiedSalvage {
  static func npcValid(_ npc: borrowing ScriptNPCDefinition, package: Bool) -> Bool {
    let model = package ? "catalogue:SH058" : "catalogue:SH141"
    let id = package ? "pell-return-package" : "pell-wreck-cradle"
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
  static func validateIdentifiedSalvage(_ manifest: ScriptManifest) throws {
    guard let declaration = manifest.identifiedSalvage else {
      guard !manifest.capabilities.contains("native-identified-salvage-v1") else {
        throw MissionPackError("Native recovery needs its original depot declaration.")
      }
      return
    }
    let capabilities: Set<String> = [
      "script-lua-v1", "story-v2", "durable-commands-v2", "contracts-basic-v2",
      "local-flight-clocks-v2", "native-identified-salvage-v1", "profiled-encounters-v2",
    ]
    guard declaration.valid, manifest.stateID == NativeIdentifiedSalvage.stateID,
      manifest.version == "1.0.0", Set(manifest.capabilities) == capabilities,
      manifest.mission.milestones.count == 4, manifest.board == nil,
      manifest.courier == nil, manifest.freight == nil, manifest.procurement == nil,
      manifest.pledge == nil, manifest.coldChain == nil, manifest.repairLoop == nil,
      manifest.providerContract == nil, manifest.trial == nil,
      manifest.stationJourney == nil, manifest.orbitalOutlook == nil,
      manifest.originalSurvey == nil, manifest.originalRescue == nil,
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
      let encounter = encounters.first, encounter.id == NativeIdentifiedSalvage.encounterID,
      encounter.galaxy == 0, encounter.system == 185,
      encounter.profile == "profiled-local-freeze-v1", encounter.actors.count == 3,
      let npcs = manifest.npcs, npcs.count == 2,
      NativeIdentifiedSalvage.npcValid(npcs[0], package: false),
      NativeIdentifiedSalvage.npcValid(npcs[1], package: true)
    else { throw MissionPackError("Invalid original identified-salvage declaration.") }
    let aliases = ["pell-cradle"] + NativeIdentifiedSalvage.aliases
    let positions = [Vector3(0, 0, 24000), Vector3(-2000, 0, 24000), Vector3(2000, 0, 24000)]
    for (index, actor) in encounter.actors.enumerated() {
      guard actor.id == aliases[index], actor.npc == npcs[index == 0 ? 0 : 1].id,
        actor.hull == nil, !actor.hostile,
        Vector3(actor.x, actor.y, actor.z) == positions[index]
      else { throw MissionPackError("The registered recovery poses or actor identities changed.") }
    }
  }
}
