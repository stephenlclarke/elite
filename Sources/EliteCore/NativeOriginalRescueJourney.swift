import Foundation

/// The incident's original people, independent of mission, visit, capture or later transport.
public struct NativeOriginalRescueIdentity: Hashable, Codable, Sendable {
  let owner: UUID
  let batch: String
  let ordinal: Int
  var valid: Bool { batch == NativeOriginalRescueJourney.batch && (0..<2).contains(ordinal) }
  var key: String { "original-rescue-v1:\(owner):0:85:\(batch):\(ordinal)" }
  var id: UUID { ScriptIdentity.uuid(key) }
}

struct NativeOriginalRescueDefinition: Codable, Equatable, Sendable {
  let batch: String
  let sourceGalaxy: Int
  let sourceSystem: Int
  let destinationGalaxy: Int
  let destinationSystem: Int
  let people: [NativeStationJourneyPersonDefinition]
  var valid: Bool {
    batch == NativeOriginalRescueJourney.batch && sourceGalaxy == 0 && sourceSystem == 85
      && destinationGalaxy == 0 && destinationSystem == 241
      && people == [
        .init(id: "neri-voss", name: "Neri Voss"), .init(id: "ilan-rook", name: "Ilan Rook"),
      ]
  }
}

struct NativeOriginalRescueCapture: Codable, Equatable, Sendable {
  let authority: UUID
  let operation: UUID
  let logicalActor: UUID
  let alias: String
  let actor: ActorIdentity
  let collector: ActorIdentity
  let owner: UUID
  let carrier: UUID
  let tool: EquipmentPurchaseItem
  let inventoryRevision: UInt64
  let physicalTime: Double
  let epoch: UUID
  let revision: UInt64
}

struct NativeOriginalRescueReply: Codable, Equatable, Sendable {
  let sequence: UInt64
  let person: NativeOriginalRescueIdentity
  let request: NativeStationTravelRequest
  let offer: UUID
  let kind: NativeStationPassageReplyKind
  let careOperation: UUID
  let dock: NativeMainStationDockReceipt
  let carrier: UUID
  let berth: PassengerBerth?
  let inventoryRevision: UInt64
  let epoch: UUID
  let physicalTime: Double
}

struct NativeOriginalRescueBoarding: Codable, Equatable, Sendable {
  let operation: UUID
  let offer: UUID
  let replies: [Int]
  let dock: NativeMainStationDockReceipt
  let collector: ActorIdentity
  let carrier: UUID
  let berths: [UUID]
  let inventoryRevision: UInt64
  let physicalTime: Double
  let epoch: UUID
  let revision: UInt64
}

struct NativeOriginalRescueRecordReceipt: Codable, Equatable, Sendable {
  let operation: UUID
  let capture: UUID
  let dock: NativeMainStationDockReceipt
  let carrier: UUID
  let physicalTime: Double
  let epoch: UUID
}

struct NativeOriginalRescueJourneyState: Codable, Equatable, Sendable {
  let owner: UUID
  let definition: NativeOriginalRescueDefinition
  let version: String
  let digest: String
  let registration: NativeMainStationDockReceipt
  let registeredAt: Double
  let inventoryRevision: UInt64
  let operation: UUID
  let mission: UUID
  let carrier: UUID
  let reservedBerths: [UUID]
  var captures: [NativeOriginalRescueCapture] = []
  var offers: [NativeStationPassageOffer] = []
  var replies: [NativeOriginalRescueReply] = []
  var boarding: NativeOriginalRescueBoarding?
  var record: NativeOriginalRescueCapture?
  var recordReception: NativeOriginalRescueRecordReceipt?
  var terminalOperation: UUID?
  var terminalDock: NativeMainStationDockReceipt?
  var references: [NativePersonReference] {
    (0..<2).map { .rescue(.init(owner: owner, batch: definition.batch, ordinal: $0)) }
  }
  func care(for person: NativePersonReference, custody: NativePeopleCustodyState)
    -> NativePeopleTransferReceipt?
  {
    custody.transfers.first { $0.kind == .care && $0.members.contains(person) }
  }
  var reservedCargoTonnes: Int { terminalOperation == nil ? 1 : 0 }
}

enum NativeOriginalRescueJourney {
  static let stateID = "l337.contract/custody-rescue"
  static let batch = "cedamar-rescue-01"
  static let boardID = "custody-rescue"
  static let encounterID = "cedamar-rescue"
  static let aliases = ["neri-capsule", "ilan-capsule", "emergency-record"]
  static let names = ["Neri Voss", "Ilan Rook"]
  static let reward = 10200
  static let geometryHash: String? = {
    guard let design = ShipCatalogue.ship("SH040")?.design,
      let bytes = try? ScriptPackLibrary.canonicalGeometry(design)
    else { return nil }
    return ScriptPackLibrary.hash(bytes)
  }()
  // Resolved by the native pack loader, including actual referenced geometry bytes.
  static let digest = "5ca2543b9a3d5ad03129c290c81cdba652a316ef2a11b23741125fe9567800fd"
  static let source = ContractStationIdentity(galaxy: 0, system: 85, stationClass: "main-orbital")
  static let destination = ContractStationIdentity(
    galaxy: 0, system: 241, stationClass: "main-orbital")
  static func sourceMatches(_ dock: NativeMainStationDockReceipt) -> Bool {
    dock.station.system == SystemIdentity(galaxy: 0, system: 85)
  }
  static func destinationMatches(_ dock: NativeMainStationDockReceipt) -> Bool {
    dock.station.system == SystemIdentity(galaxy: 0, system: 241)
  }
  static func actorIdentity(mission: UUID, alias: String) -> UUID {
    ScriptIdentity.uuid("script-actor-v2:\(mission):\(digest):\(encounterID):\(alias)")
  }
  static func captureAuthority(
    operation: UUID, actor: ActorIdentity, tool: EquipmentPurchaseItem,
    inventory: UInt64, epoch: UUID, time: Double
  ) throws -> UUID {
    // This captured fitted item contains no unordered sets. Preserve its complete native
    // acquisition and historical fitting, including origins that never mint paid history.
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let itemHash = ScriptPackLibrary.hash(try encoder.encode(tool))
    return ScriptIdentity.uuid(
      "original-rescue-capture-v1:\(operation):\(actor.system.galaxy):\(actor.system.system):\(actor.visit):\(actor.entity):\(itemHash):\(inventory):\(epoch):\(time)"
    )
  }
  static func hasMission(_ commander: borrowing Commander) -> Bool {
    for index in commander.scriptState.instances.indices {
      if commander.scriptState.instances.values[index].definition == stateID { return true }
      if commander.scriptState.instances.values[index].digest == digest { return true }
    }
    return false
  }
  @inline(never)
  static func requestConsent(state: inout NativeOriginalRescueJourneyState, game: borrowing Game)
    throws
  {
    let dockEvidenceIsCurrent = game.nativeMainStationDockEvidenceIsCurrent
    let epoch = game.nativeStationRuntimeEpoch
    try game.withReadOnlyCommander { commander in
      try requestConsent(
        state: &state, commander: commander, dockEvidenceIsCurrent: dockEvidenceIsCurrent,
        epoch: epoch)
    }
  }

  @inline(never)
  private static func requestConsent(
    state: inout NativeOriginalRescueJourneyState, commander: borrowing Commander,
    dockEvidenceIsCurrent: Bool, epoch: UUID
  ) throws {
    guard state.boarding == nil, state.terminalOperation == nil, state.offers.count < 64,
      state.replies.count <= 252, let custody = commander.nativePeople,
      let dock = commander.nativeStations?.currentMainDock,
      sourceMatches(dock), dockEvidenceIsCurrent,
      let collector = commander.flightSimulation.player,
      let carrier = commander.hullInstanceID, carrier == state.carrier,
      let inventory = commander.equipmentInventory,
      state.references.allSatisfy({ person in
        state.care(for: person, custody: custody)?.dock.map(sourceMatches) == true
      })
    else { throw SaveError.invalidCommander }
    let fitted = commander.accommodation.fittedBerths
    let berths = state.reservedBerths.compactMap { id in fitted.first { $0.id == id } }
    let reach = ScriptCourierReach(commander)
    let path =
      ScriptCourierGeneration.routes(origin: source, reach: reach).first {
        $0 == [85, 241]
      } ?? []
    if let previous = state.offers.last {
      for reference in state.references {
        guard let identity = reference.rescue else { throw SaveError.invalidCommander }
        let reply = try replyToTransportOffer(
          identity, offer: previous, state: state, commander: commander,
          dockEvidenceIsCurrent: dockEvidenceIsCurrent, epoch: epoch)
        if reply.kind == .withdraw { state.replies.append(reply) }
      }
    }
    let offer = NativeStationPassageOffer(
      id: ScriptIdentity.uuid(
        "original-rescue-offer-v1:\(state.operation):\(state.offers.count + 1)"),
      revision: UInt64(state.offers.count + 1), dock: dock, collector: collector,
      carrier: carrier, inventoryRevision: inventory.revision,
      destination: .init(galaxy: 0, system: 241), reach: reach, path: path, berths: berths,
      physicalTime: commander.flightSimulation.physicalTime,
      epoch: epoch)
    state.offers.append(offer)
    for ordinal in 0..<2 {
      let identity = NativeOriginalRescueIdentity(
        owner: state.owner, batch: batch, ordinal: ordinal)
      let reply = try replyToTransportOffer(
        identity, offer: offer, state: state, commander: commander,
        dockEvidenceIsCurrent: dockEvidenceIsCurrent, epoch: epoch)
      state.replies.append(reply)
    }
  }
  @inline(never)
  static func replyToTransportOffer(
    _ identity: NativeOriginalRescueIdentity, offer: NativeStationPassageOffer,
    state: NativeOriginalRescueJourneyState, game: borrowing Game
  ) throws -> NativeOriginalRescueReply {
    let dockEvidenceIsCurrent = game.nativeMainStationDockEvidenceIsCurrent
    let epoch = game.nativeStationRuntimeEpoch
    return try game.withReadOnlyCommander { commander in
      try replyToTransportOffer(
        identity, offer: offer, state: state, commander: commander,
        dockEvidenceIsCurrent: dockEvidenceIsCurrent, epoch: epoch)
    }
  }

  @inline(never)
  private static func replyToTransportOffer(
    _ identity: NativeOriginalRescueIdentity, offer: NativeStationPassageOffer,
    state: NativeOriginalRescueJourneyState, commander: borrowing Commander,
    dockEvidenceIsCurrent: Bool, epoch: UUID
  ) throws -> NativeOriginalRescueReply {
    guard identity.valid, identity.owner == state.owner, let custody = commander.nativePeople,
      let care = state.care(for: .rescue(identity), custody: custody), let dock = care.dock,
      sourceMatches(dock), let current = commander.nativeStations?.currentMainDock,
      sourceMatches(current), dockEvidenceIsCurrent,
      let carrier = commander.hullInstanceID, let inventory = commander.equipmentInventory
    else { throw SaveError.invalidCommander }
    let ordinal = identity.ordinal
    let berth = commander.accommodation.fittedBerths.first {
      $0.id == state.reservedBerths[ordinal]
    }
    let request = NativeStationTravelRequest(
      revision: 1, destination: .init(galaxy: 0, system: 241), intent: .passage)
    let fresh =
      offer.id == state.offers.last?.id && offer.dock == current
      && offer.carrier == carrier && offer.inventoryRevision == inventory.revision
      && offer.epoch == epoch
    let eligible =
      request.destination == offer.destination && offer.path == [85, 241]
      && offer.berths.count == 2 && berth?.lifeSupportWorking == true
      && berth?.humanoidCompatible == true
      && berth.map { commander.accommodation.supports($0, mode: .awake) && $0.privateCabin } == true
      && berth?.use == .reserved(mission: state.mission, person: identity.id)
      && offer.berths.indices.contains(ordinal) && offer.berths[ordinal] == berth
    return .init(
      sequence: UInt64(state.replies.count + 1), person: identity, request: request,
      offer: offer.id, kind: !fresh ? .withdraw : (eligible ? .accept : .refuse),
      careOperation: care.operation, dock: current, carrier: carrier, berth: berth,
      inventoryRevision: inventory.revision, epoch: epoch,
      physicalTime: commander.flightSimulation.physicalTime)
  }
}

extension ScriptPackLibrary {
  static func validateOriginalRescueJourney(_ manifest: ScriptManifest) throws {
    guard let declaration = manifest.originalRescue else {
      guard !manifest.capabilities.contains("native-original-rescue-v1") else {
        throw MissionPackError("Original rescue needs its closed finite source declaration.")
      }
      return
    }
    let capabilities: Set<String> = [
      "script-lua-v1", "story-v2", "durable-commands-v2",
      "contracts-basic-v2", "local-flight-clocks-v2", "native-original-rescue-v1",
      "profiled-encounters-v2",
    ]
    guard declaration.valid, manifest.stateID == NativeOriginalRescueJourney.stateID,
      manifest.version == "1.0.0", Set(manifest.capabilities) == capabilities,
      manifest.mission.milestones.count == 2, manifest.board == nil,
      manifest.stationJourney == nil, manifest.orbitalOutlook == nil,
      manifest.courier == nil, manifest.freight == nil, manifest.procurement == nil,
      manifest.pledge == nil, manifest.coldChain == nil, manifest.repairLoop == nil,
      manifest.providerContract == nil, manifest.trial == nil,
      (manifest.passengerParties ?? []).isEmpty, (manifest.collections ?? []).isEmpty,
      (manifest.equipment ?? []).isEmpty, (manifest.children ?? []).isEmpty,
      (manifest.worldJobs ?? []).isEmpty, (manifest.loans ?? []).isEmpty,
      (manifest.receiptRequirements ?? []).isEmpty,
      (manifest.mission.requiredPassengerParties ?? []).isEmpty,
      (manifest.mission.requiredCollections ?? []).isEmpty,
      (manifest.mission.requiredDestructionEncounters ?? []).isEmpty,
      (manifest.mission.requiredEquipmentReturns ?? []).isEmpty,
      (manifest.mission.requiredChoiceGroups ?? []).isEmpty,
      let npcs = manifest.npcs, npcs.count == 2,
      let encounters = manifest.encounters, encounters.count == 1, let encounter = encounters.first,
      encounter.id == NativeOriginalRescueJourney.encounterID,
      encounter.galaxy == 0, encounter.system == 85,
      encounter.profile == "profiled-local-freeze-v1",
      encounter.actors.count == 3
    else { throw MissionPackError("Invalid complete original custody rescue declaration.") }
    for (index, npc) in npcs.enumerated() {
      guard npc.valid,
        npc.id == (index == 0 ? "original-living-capsule" : "original-emergency-record"),
        npc.model == "catalogue:SH040", npc.scale == 1, npc.energy == 70,
        npc.recharge == 0, npc.speed == 0, npc.acceleration == 0,
        npc.pitch == 0, npc.yaw == 0, npc.roll == 0, npc.missiles == 0, npc.fuel == 0,
        !npc.ecm, npc.bounty == 0, npc.drive == nil,
        (npc.lasers ?? []).isEmpty, (npc.components ?? []).isEmpty
      else {
        throw MissionPackError(
          "Original rescue actors require supported noncombat physical templates.")
      }
    }
    let positions = [Vector3(-5000, 0, 20000), Vector3(5000, 0, 20000), Vector3(0, 4000, 24000)]
    for (index, actor) in encounter.actors.enumerated() {
      guard actor.id == NativeOriginalRescueJourney.aliases[index], actor.hull == nil,
        actor.npc == npcs[index == 2 ? 1 : 0].id, !actor.hostile,
        Vector3(actor.x, actor.y, actor.z) == positions[index]
      else { throw MissionPackError("Original capsule and record source poses are closed.") }
    }
  }
}
