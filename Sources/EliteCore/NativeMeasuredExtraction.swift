import Foundation

struct NativeMeasuredExtractionDefinition: Codable, Sendable, Equatable {
  let sourceGalaxy: Int
  let sourceSystem: Int
  let field: UInt16
  let rock: UInt16
  let destinationGalaxy: Int
  let destinationSystem: Int
  let quantity: Int
  var valid: Bool {
    sourceGalaxy == 0 && sourceSystem == 7 && field == 5 && rock == 0
      && destinationGalaxy == 0 && destinationSystem == 185 && quantity == 12
  }
}

enum MeasuredInputCustody: Codable, Sendable, Equatable {
  case unfilled
  case raw(UUID)
  case processed(UUID)
  case returned(UUID)
  case lost(UUID)
}

struct MeasuredOriginal: Codable, Sendable, Equatable {
  let id: UUID
  let payload: PayloadIdentity
  var custody: MeasuredInputCustody = .unfilled
}

struct MeasuredSource: Codable, Sendable, Equatable {
  let id: UUID
  let owner: NativeMainStationIdentity
  let registration: NativeMainStationDockReceipt
  let root: RockIdentity
  let mission: UUID
  var originals: [MeasuredOriginal]
}

struct MeasuredPermission: Codable, Sendable, Equatable {
  let operation: UUID
  let mission: UUID
  let source: UUID
  let carrier: UUID
  let player: ActorIdentity
  let dock: NativeMainStationDockReceipt
  let reach: ScriptCourierReach
  let inventoryRevision: UInt64
  let physicalTime: Double
}

struct MeasuredExtractionWitness: Codable, Sendable, Equatable {
  let operation: UUID
  let permission: UUID
  let incident: CombatIncident
  let body: [SpaceBody]
  let emitted: [TypedCargoPayload]
  let equipment: [EquipmentPurchaseItem]
  let carrier: UUID
  let inventoryRevision: UInt64
  let epoch: UUID
  var authority: UUID
}

struct MeasuredIntake: Codable, Sendable, Equatable {
  let operation: UUID
  let permission: UUID
  let extraction: UUID
  let original: UUID
  let payload: TypedCargoPayload
  let body: [SpaceBody]
  let player: ActorIdentity
  let carrier: UUID
  let inventoryRevision: UInt64
  let scoops: EquipmentPurchaseItem
  let relativeSpeed: Double
  let physicalTime: Double
  let epoch: UUID
  var authority: UUID
}

enum MeasuredProductCustody: Codable, Sendable, Equatable {
  case held
  case received(UUID)
  case returned(UUID)
  case lost(UUID)
}
struct MeasuredProduct: Codable, Sendable, Equatable {
  let id: UUID
  let input: UUID
  let massKg: Int
  var custody: MeasuredProductCustody = .held
}
struct MeasuredProcessing: Codable, Sendable, Equatable {
  let operation: UUID
  let dock: NativeMainStationDockReceipt
  let inputs: [UUID]
  var products: [MeasuredProduct]
}
struct MeasuredReception: Codable, Sendable, Equatable {
  let operation: UUID
  let dock: NativeMainStationDockReceipt
  let products: [UUID]
  let returnedRaw: [UUID]
  let returnedProducts: [UUID]
  let complete: Bool
  let cause: ScriptEventContext
  let committed: ScriptEventContext
}

enum MeasuredLossKind: String, Codable, Sendable {
  case source, destroyed, departed, hull, escape
}
struct MeasuredLoss: Codable, Sendable, Equatable {
  let operation: UUID
  let kind: MeasuredLossKind
  let originals: [UUID]
  let products: [UUID]
  let bodies: [SpaceBody]
  let payloads: [TypedCargoPayload]
  let incident: CombatIncident?
  let player: ActorIdentity
  let carrier: UUID
  let energy: Double
  let escapePod: EquipmentPurchaseItem?
  let physicalTime: Double
  let epoch: UUID
  var authority: UUID
}

struct NativeMeasuredExtractionState: Codable, Sendable, Equatable {
  let definition: NativeMeasuredExtractionDefinition
  let permission: MeasuredPermission
  var extraction: MeasuredExtractionWitness?
  var captures: [MeasuredIntake] = []
  var processing: MeasuredProcessing?
  var reception: MeasuredReception?
  var losses: [MeasuredLoss] = []
}

public struct NativeMeasuredExtractionSelectionFacts: Sendable, Equatable {
  let fits: Bool
}

enum NativeMeasuredExtraction {
  static let stateID = "l337.contract/measured-extraction"
  // Installed native pack CLI qualification 1154, source a342ccc2.
  static let digest = "31b26af2735fb907355acb2d4dba5fca3b3622032f4a95642a50c5421aa021c2"
  static let boardID = "measured-extraction"
  static let root = RockIdentity(system: .init(galaxy: 0, system: 7), field: 5, rock: 0)
  static let source = ContractStationIdentity(galaxy: 0, system: 7, stationClass: "main-orbital")
  static let destination = ContractStationIdentity(
    galaxy: 0, system: 185, stationClass: "main-orbital")
  static let reward = 8900

  static func identity(_ owner: NativeMainStationIdentity) -> UUID {
    ScriptIdentity.uuid("measured-source-v1:\(owner.world):\(owner.resource):0:7:5:0")
  }
  static func originals(_ owner: NativeMainStationIdentity) -> [MeasuredOriginal] {
    (0..<12).map { index in
      .init(
        id: ScriptIdentity.uuid("measured-original-v1:\(identity(owner)):\(index)"),
        payload: .ore(root, fragment: UInt16(index)))
    }
  }
  static func route(_ reach: ScriptCourierReach) -> Bool {
    ScriptCourierGeneration.routes(origin: source, reach: reach).contains([7, 185])
  }
  static func rawHeld(_ source: borrowing MeasuredSource) -> [UUID] {
    source.originals.compactMap { item in
      if case .raw = item.custody { return item.id }
      return nil
    }
  }
  static func payloads(
    _ source: borrowing MeasuredSource, state: borrowing NativeMeasuredExtractionState,
    outcome: ScriptOutcome
  ) -> [String: Int] {
    var result: [String: Int] = [:]
    for (index, original) in source.originals.enumerated() {
      switch original.custody {
      case .unfilled: if outcome == .active { result["input-\(index)"] = 1 }
      case .raw: result["input-\(index)"] = 1
      case .processed, .returned, .lost: break
      }
    }
    for (index, product) in (state.processing?.products ?? []).enumerated() {
      if product.custody == .held { result["product-\(index)"] = 1 }
    }
    return result
  }
  static func hash<T: Encodable>(_ value: T) throws -> String {
    let object = try JSONSerialization.jsonObject(
      with: JSONEncoder().encode(value), options: [.fragmentsAllowed])
    return ScriptPackLibrary.hash(
      try JSONSerialization.data(
        withJSONObject: object, options: [.sortedKeys, .fragmentsAllowed]))
  }
  static func extractionAuthority(_ value: borrowing MeasuredExtractionWitness) throws -> UUID {
    ScriptIdentity.uuid(
      "measured-extraction-authority-v1:\(value.operation):\(value.permission):\(value.carrier):\(value.inventoryRevision):\(value.epoch):\(try hash(value.incident)):\(try hash(value.body)):\(try hash(value.emitted)):\(try hash(value.equipment))"
    )
  }
  static func intakeAuthority(_ value: borrowing MeasuredIntake) throws -> UUID {
    ScriptIdentity.uuid(
      "measured-intake-authority-v1:\(value.operation):\(value.permission):\(value.extraction):\(value.original):\(value.carrier):\(value.inventoryRevision):\(value.epoch):\(try hash(value.payload)):\(try hash(value.body)):\(try hash(value.player)):\(try hash(value.scoops)):\(try hash(value.relativeSpeed)):\(try hash(value.physicalTime))"
    )
  }
  static func lossAuthority(_ value: borrowing MeasuredLoss) throws -> UUID {
    ScriptIdentity.uuid(
      "measured-loss-authority-v1:\(value.operation):\(value.kind.rawValue):\(value.carrier):\(value.epoch):\(try hash(value.originals)):\(try hash(value.products)):\(try hash(value.bodies)):\(try hash(value.payloads)):\(try hash(value.incident)):\(try hash(value.player)):\(try hash(value.energy)):\(try hash(value.escapePod)):\(try hash(value.physicalTime))"
    )
  }
}

extension Game {
  var measuredExtractionState: NativeMeasuredExtractionState? {
    for instance in commander.scriptState.instances.values {
      if instance.definition == NativeMeasuredExtraction.stateID {
        return instance.savedMeasuredExtraction
      }
    }
    return nil
  }
  var measuredExtractionRock: MiningRock? {
    for field in miningFields {
      if let rock = field.rocks.first(where: { $0.identity == NativeMeasuredExtraction.root }) {
        return rock
      }
    }
    return nil
  }
  func measuredOriginal(_ payload: PayloadIdentity) -> MeasuredOriginal? {
    commander.scriptState.savedMeasuredExtractionSource?.originals.first { $0.payload == payload }
  }
  var hasMeasuredExtractionFit: Bool {
    commander.targetingTier != nil && commander.fittedEquipment(at: .targetingMining) != nil
      && commander.hasMiningWorkTool && commander.fittedEquipment(at: .utility(.fuelScoops)) != nil
  }
}

extension ScriptPackLibrary {
  static func validateMeasuredExtraction(_ manifest: ScriptManifest) throws {
    guard let definition = manifest.measuredExtraction else {
      guard !manifest.capabilities.contains("native-measured-extraction-v1") else {
        throw MissionPackError("Measured extraction requires its native declaration.")
      }
      return
    }
    guard definition.valid, manifest.stateID == NativeMeasuredExtraction.stateID,
      manifest.version == "1.0.0", manifest.mission.milestones.count == 5,
      Set(manifest.capabilities)
        == Set([
          "script-lua-v1", "story-v2", "durable-commands-v2", "contracts-basic-v2",
          "local-flight-clocks-v2", "native-measured-extraction-v1",
        ]),
      manifest.board == nil, manifest.fieldRelief == nil,
      manifest.identifiedSalvage == nil, manifest.recordRecovery == nil,
      manifest.originalSurvey == nil, manifest.originalRescue == nil,
      manifest.orbitalEvacuation == nil,
      manifest.stationJourney == nil, manifest.orbitalOutlook == nil,
      manifest.courier == nil, manifest.freight == nil, manifest.procurement == nil,
      manifest.coldChain == nil, manifest.repairLoop == nil, manifest.pledge == nil,
      manifest.providerContract == nil, manifest.trial == nil,
      (manifest.npcs ?? []).isEmpty, (manifest.encounters ?? []).isEmpty,
      (manifest.equipment ?? []).isEmpty, (manifest.passengerParties ?? []).isEmpty,
      (manifest.collections ?? []).isEmpty, (manifest.children ?? []).isEmpty,
      (manifest.worldJobs ?? []).isEmpty, (manifest.loans ?? []).isEmpty,
      (manifest.receiptRequirements ?? []).isEmpty, (manifest.answerRequirements ?? []).isEmpty,
      (manifest.books ?? []).isEmpty, (manifest.models ?? []).isEmpty,
      (manifest.modules ?? []).isEmpty,
      (manifest.dialogs ?? []).isEmpty,
      (manifest.mission.requiredPassengerParties ?? []).isEmpty,
      (manifest.mission.requiredCollections ?? []).isEmpty,
      (manifest.mission.requiredDestructionEncounters ?? []).isEmpty,
      (manifest.mission.requiredEquipmentReturns ?? []).isEmpty,
      (manifest.mission.requiredChoiceGroups ?? []).isEmpty
    else { throw MissionPackError("Invalid closed measured-extraction source or recipe.") }
  }
}
