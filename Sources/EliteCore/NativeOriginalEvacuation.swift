import Foundation

/// A native station individual. Its identity never depends on a mission instance or visit.
public struct NativeOriginalEvacuationIdentity: Hashable, Codable, Sendable {
  let owner: UUID
  let batch: String
  let person: String
  var key: String { "evacuation-person-v1:\(owner):main-orbital:0:7:\(batch):\(person)" }
  var id: UUID { ScriptIdentity.uuid(key) }
  var valid: Bool {
    batch == NativeOriginalEvacuation.batch
      && ["sera-venn", "tavi-noll", "eren-pell", "mara-quill"].contains(person)
  }
}

struct NativeEvacuationPersonDefinition: Codable, Sendable, Equatable {
  let id: String
  let name: String
}
struct NativeOriginalEvacuationDefinition: Codable, Sendable, Equatable {
  let batch: String
  let sourceGalaxy: Int
  let sourceSystem: Int
  let destinationGalaxy: Int
  let destinationSystem: Int
  let people: [NativeEvacuationPersonDefinition]
  var valid: Bool {
    batch == NativeOriginalEvacuation.batch && sourceGalaxy == 0 && sourceSystem == 7
      && destinationGalaxy == 0 && destinationSystem == 185
      && people == [
        .init(id: "sera-venn", name: "Sera Venn"), .init(id: "tavi-noll", name: "Tavi Noll"),
        .init(id: "eren-pell", name: "Eren Pell"), .init(id: "mara-quill", name: "Mara Quill"),
      ]
  }
}

struct NativeEvacuationPersonRecord: Codable, Sendable, Equatable {
  let identity: NativeOriginalEvacuationIdentity
  let name: String
  let custodian: NativeMainStationIdentity
  var travelRequests: [NativeStationTravelRequest]
  var currentRequest: NativeStationTravelRequest? { travelRequests.last }
}
struct NativeEvacuationPassageReply: Codable, Sendable, Equatable {
  let sequence: UInt64
  let person: NativeOriginalEvacuationIdentity
  let offer: UUID
  let personRevision: UInt64
  let observedOfferRevision: UInt64
  let kind: NativeStationPassageReplyKind
  let dock: NativeMainStationDockReceipt
  let carrier: UUID
  let berth: UUID?
  let observedBerth: PassengerBerth?
  let inventoryRevision: UInt64
  let physicalTime: Double
  let epoch: UUID
}
/// Original people and consent history; existing admissions/transfers own their actual custody.
struct NativeEvacuationWithdrawal: Codable, Sendable, Equatable {
  let operation: UUID
  let dock: NativeMainStationDockReceipt
  let epoch: UUID
  let physicalTime: Double
}
struct NativeOriginalEvacuationState: Codable, Sendable, Equatable {
  let owner: UUID
  let definition: NativeOriginalEvacuationDefinition
  let version: String
  let digest: String
  let source: NativeMainStationIdentity
  let registration: NativeMainStationDockReceipt
  let stationActor: ActorIdentity
  var people: [NativeEvacuationPersonRecord]
  var offers: [NativeStationPassageOffer] = []
  var replies: [NativeEvacuationPassageReply] = []
  var boarding: NativeStationPassengerBoarding?
  var terminalOperation: UUID?
  var withdrawal: NativeEvacuationWithdrawal?
  var references: [NativePersonReference] { people.map { .evacuation($0.identity) } }
  var latestOffer: NativeStationPassageOffer? { offers.last }
  func latestReplies(for offer: NativeStationPassageOffer) -> [NativeEvacuationPassageReply] {
    people.compactMap { person in
      replies.last { $0.person == person.identity && $0.offer == offer.id }
    }
  }
}

enum NativeOriginalEvacuation {
  static let stateID = "l337.contract/orbital-evacuation"
  static let batch = "avenor-orbital-evacuation-01"
  static let digest = "a0079912be31a64af9f08cd678d266bea230d1606ad53b4a543300facc64a12f"
  static let source = ContractStationIdentity(galaxy: 0, system: 7, stationClass: "main-orbital")
  static let destination = ContractStationIdentity(
    galaxy: 0, system: 185, stationClass: "main-orbital")
  static let reward = 10650
  static let boardID = "orbital-evacuation"

  static func historicalDock(_ dock: NativeMainStationDockReceipt, commander: borrowing Commander)
    -> Bool
  {
    guard dock.valid, dock.commanderOwner == commander.equipmentOwnerID,
      let world = commander.nativeStations, world.ledger.world == dock.commanderOwner,
      world.mainStations.contains(dock.station), dock.sequence < world.nextMainDockSequence,
      dock.actor.visit <= commander.flightSimulation.visit,
      dock.calendarSeconds <= commander.scriptState.calendarSeconds
    else { return false }
    return true
  }
  static func sourceMatches(_ dock: NativeMainStationDockReceipt) -> Bool {
    dock.station.system == SystemIdentity(galaxy: 0, system: 7)
  }
  static func destinationMatches(_ dock: NativeMainStationDockReceipt) -> Bool {
    dock.station.system == SystemIdentity(galaxy: 0, system: 185)
  }
  static func nativeInstancePresent(_ commander: borrowing Commander) -> Bool {
    for state in commander.scriptState.instances.values {
      if state.definition == stateID { return true }
    }
    return false
  }

  /// Player input requests passage. Only the native original person's policy creates its reply.
  @inline(never)
  static func requestConsent(
    state: inout NativeOriginalEvacuationState, game: borrowing Game,
    destination requested: SystemIdentity
  ) throws {
    let dockEvidenceIsCurrent = game.nativeMainStationDockEvidenceIsCurrent
    let atSource = game.contractStation == source
    let epoch = game.nativeStationRuntimeEpoch
    try game.withReadOnlyCommander { commander in
      try requestConsent(
        state: &state, commander: commander, destination: requested,
        dockEvidenceIsCurrent: dockEvidenceIsCurrent, atSource: atSource, epoch: epoch)
    }
  }

  @inline(never)
  private static func requestConsent(
    state: inout NativeOriginalEvacuationState, commander: borrowing Commander,
    destination requested: SystemIdentity, dockEvidenceIsCurrent: Bool, atSource: Bool, epoch: UUID
  ) throws {
    guard state.boarding == nil, state.withdrawal == nil,
      state.owner == commander.equipmentOwnerID,
      state.definition.valid,
      state.offers.count < 64, state.replies.count <= 248,
      dockEvidenceIsCurrent, atSource,
      let dock = commander.nativeStations?.currentMainDock, state.source == dock.station,
      let collector = commander.flightSimulation.player,
      let carrier = commander.hullInstanceID,
      let inventory = commander.equipmentInventory
    else { throw MissionPackError("Request passage from the actual Avenor passage office.") }
    let slots = commander.accommodation.fittedBerths.filter {
      !$0.use.used && $0.lifeSupportWorking && $0.humanoidCompatible
    }.sorted { $0.id.uuidString < $1.id.uuidString }
    let reach = ScriptCourierReach(commander)
    let route =
      ScriptCourierGeneration.routes(origin: source, reach: reach).first {
        $0.last == requested.system && requested.galaxy == 0 && $0.count == 2
      } ?? []
    if let previous = state.latestOffer {
      for person in state.people {
        let reply = try replyToPassageOffer(
          person: person.identity, offer: previous, state: state, commander: commander,
          dockEvidenceIsCurrent: dockEvidenceIsCurrent, atSource: atSource, epoch: epoch)
        if reply.kind == .withdraw { state.replies.append(reply) }
      }
    }
    guard state.replies.count <= 252 else {
      throw MissionPackError("The native reply history is full.")
    }
    let revision = UInt64(state.offers.count + 1)
    let offer = NativeStationPassageOffer(
      id: ScriptIdentity.uuid(
        "native-evacuation-offer-v1:\(state.owner):\(state.definition.batch):\(revision)"),
      revision: revision, dock: dock, collector: collector, carrier: carrier,
      inventoryRevision: inventory.revision, destination: requested, reach: reach, path: route,
      berths: commander.passengerFit?.allowed == true ? Array(slots.prefix(4)) : [],
      physicalTime: commander.flightSimulation.physicalTime,
      epoch: epoch)
    state.offers.append(offer)
    for person in state.people {
      let reply = try replyToPassageOffer(
        person: person.identity, offer: offer, state: state, commander: commander,
        dockEvidenceIsCurrent: dockEvidenceIsCurrent, atSource: atSource, epoch: epoch)
      state.replies.append(reply)
    }
  }

  @inline(never)
  static func replyToPassageOffer(
    person identity: NativeOriginalEvacuationIdentity, offer: NativeStationPassageOffer,
    state: NativeOriginalEvacuationState, game: borrowing Game
  ) throws -> NativeEvacuationPassageReply {
    let dockEvidenceIsCurrent = game.nativeMainStationDockEvidenceIsCurrent
    let atSource = game.contractStation == source
    let epoch = game.nativeStationRuntimeEpoch
    return try game.withReadOnlyCommander { commander in
      try replyToPassageOffer(
        person: identity, offer: offer, state: state, commander: commander,
        dockEvidenceIsCurrent: dockEvidenceIsCurrent, atSource: atSource, epoch: epoch)
    }
  }

  @inline(never)
  private static func replyToPassageOffer(
    person identity: NativeOriginalEvacuationIdentity, offer: NativeStationPassageOffer,
    state: NativeOriginalEvacuationState, commander: borrowing Commander,
    dockEvidenceIsCurrent: Bool, atSource: Bool, epoch: UUID
  ) throws -> NativeEvacuationPassageReply {
    guard state.boarding == nil, state.withdrawal == nil,
      state.owner == commander.equipmentOwnerID,
      let person = state.people.first(where: { $0.identity == identity }),
      let request = person.currentRequest,
      person.custodian == state.source, person.identity.owner == state.owner,
      dockEvidenceIsCurrent, atSource,
      let dock = commander.nativeStations?.currentMainDock, state.source == dock.station,
      let carrier = commander.hullInstanceID,
      let inventory = commander.equipmentInventory
    else { throw MissionPackError("A reply needs the actual living original station individual.") }
    guard let index = state.people.firstIndex(where: { $0.identity == identity }) else {
      throw SaveError.invalidCommander
    }
    let offered = offer.berths.indices.contains(index) ? offer.berths[index] : nil
    let berth = offered?.id
    let observed = commander.accommodation.fittedBerths.first { $0.id == berth }
    let inventoryRevision = inventory.revision
    let kind: NativeStationPassageReplyKind
    if request.intent == .withdrawn || state.latestOffer?.id != offer.id || offer.dock != dock
      || offer.carrier != carrier || offer.epoch != epoch
      || offer.inventoryRevision != inventoryRevision
      || (offer.berths.count == 4 && observed != offered)
    {
      kind = .withdraw
    } else if request.destination != offer.destination
      || offer.path != [7, 185] || offer.berths.count != 4 || berth == nil
    {
      kind = .refuse
    } else {
      kind = .accept
    }
    return .init(
      sequence: UInt64(state.replies.count + 1), person: identity, offer: offer.id,
      personRevision: request.revision,
      observedOfferRevision: state.latestOffer?.revision ?? 0, kind: kind, dock: dock,
      carrier: carrier, berth: berth, observedBerth: observed, inventoryRevision: inventoryRevision,
      physicalTime: commander.flightSimulation.physicalTime,
      epoch: epoch)
  }
}

extension ScriptPackLibrary {
  static func validateOriginalEvacuationJourney(_ manifest: ScriptManifest) throws {
    guard let declaration = manifest.orbitalEvacuation else {
      guard !manifest.capabilities.contains("native-orbital-evacuation-v1") else {
        throw MissionPackError("Native passage needs its closed original declaration.")
      }
      return
    }
    let capabilities: Set<String> = [
      "script-lua-v1", "story-v2", "durable-commands-v2", "contracts-basic-v2",
      "local-flight-clocks-v2", "native-orbital-evacuation-v1",
    ]
    guard declaration.valid, manifest.stateID == NativeOriginalEvacuation.stateID,
      manifest.version == "1.0.0", Set(manifest.capabilities) == capabilities,
      manifest.mission.milestones.count == 2, manifest.board == nil,
      manifest.courier == nil, manifest.freight == nil, manifest.procurement == nil,
      manifest.pledge == nil, manifest.coldChain == nil, manifest.repairLoop == nil,
      manifest.providerContract == nil, manifest.trial == nil,
      manifest.stationJourney == nil, manifest.orbitalOutlook == nil,
      manifest.originalRescue == nil,
      (manifest.passengerParties ?? []).isEmpty, (manifest.collections ?? []).isEmpty,
      (manifest.encounters ?? []).isEmpty, (manifest.npcs ?? []).isEmpty,
      (manifest.equipment ?? []).isEmpty, (manifest.children ?? []).isEmpty,
      (manifest.worldJobs ?? []).isEmpty, (manifest.loans ?? []).isEmpty,
      (manifest.receiptRequirements ?? []).isEmpty,
      (manifest.mission.requiredPassengerParties ?? []).isEmpty,
      (manifest.mission.requiredCollections ?? []).isEmpty,
      (manifest.mission.requiredDestructionEncounters ?? []).isEmpty,
      (manifest.mission.requiredEquipmentReturns ?? []).isEmpty,
      (manifest.mission.requiredChoiceGroups ?? []).isEmpty
    else {
      throw MissionPackError("Invalid original native station-passenger journey declaration.")
    }
  }
}
