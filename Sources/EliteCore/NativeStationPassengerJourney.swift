import Foundation

/// A native station individual. Its identity never depends on a mission instance or visit.
public struct NativeStationPersonIdentity: Hashable, Codable, Sendable {
  let owner: UUID
  let batch: String
  let person: String
  var key: String { "station-person-v1:\(owner):main-orbital:0:7:\(batch):\(person)" }
  var id: UUID { ScriptIdentity.uuid(key) }
  var valid: Bool {
    (batch == NativeStationPassengerJourney.batch && ["mira-talen", "oren-vey"].contains(person))
      || (batch == NativeOrbitalOutlookJourney.batch
        && ["lysa-renn", "tovan-hale"].contains(person))
  }
}

struct NativeStationJourneyPersonDefinition: Codable, Sendable, Equatable {
  let id: String
  let name: String
}
struct NativeStationPassengerJourneyDefinition: Codable, Sendable, Equatable {
  let batch: String
  let sourceGalaxy: Int
  let sourceSystem: Int
  let destinationGalaxy: Int
  let destinationSystem: Int
  let people: [NativeStationJourneyPersonDefinition]
  var valid: Bool {
    batch == NativeStationPassengerJourney.batch && sourceGalaxy == 0 && sourceSystem == 7
      && destinationGalaxy == 0 && destinationSystem == 185
      && people == [
        .init(id: "mira-talen", name: "Mira Talen"), .init(id: "oren-vey", name: "Oren Vey"),
      ]
  }
}

enum NativeStationTravelIntent: String, Codable, Sendable { case passage, withdrawn }
struct NativeStationTravelRequest: Codable, Sendable, Equatable {
  let revision: UInt64
  let destination: SystemIdentity
  let intent: NativeStationTravelIntent
}
struct NativeStationPersonRecord: Codable, Sendable, Equatable {
  let identity: NativeStationPersonIdentity
  let name: String
  let custodian: NativeMainStationIdentity
  var travelRequests: [NativeStationTravelRequest]
  var currentRequest: NativeStationTravelRequest? { travelRequests.last }
}
struct NativeStationPassageOffer: Codable, Sendable, Equatable {
  let id: UUID
  let revision: UInt64
  let dock: NativeMainStationDockReceipt
  let collector: ActorIdentity
  let carrier: UUID
  let inventoryRevision: UInt64
  let destination: SystemIdentity
  let reach: ScriptCourierReach
  let path: [Int]
  let berths: [PassengerBerth]
  let physicalTime: Double
  let epoch: UUID
}
enum NativeStationPassageReplyKind: String, Codable, Sendable { case accept, refuse, withdraw }
struct NativeStationPassageReply: Codable, Sendable, Equatable {
  let sequence: UInt64
  let person: NativeStationPersonIdentity
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
struct NativeStationPassengerBoarding: Codable, Sendable, Equatable {
  let mission: UUID
  let offer: UUID
  let operation: UUID
  let dock: NativeMainStationDockReceipt
  let collector: ActorIdentity
  let carrier: UUID
  let inventoryRevision: UInt64
  let berths: [UUID]
  let replyOrdinals: [Int]
  let physicalTime: Double
  let epoch: UUID
}

/// Original people and consent history; existing admissions/transfers own their actual custody.
struct NativeStationPassengerJourneyState: Codable, Sendable, Equatable {
  let owner: UUID
  let definition: NativeStationPassengerJourneyDefinition
  let version: String
  let digest: String
  let source: NativeMainStationIdentity
  let registration: NativeMainStationDockReceipt
  let stationActor: ActorIdentity
  var people: [NativeStationPersonRecord]
  var offers: [NativeStationPassageOffer] = []
  var replies: [NativeStationPassageReply] = []
  var boarding: NativeStationPassengerBoarding?
  var terminalOperation: UUID?
  var references: [NativePersonReference] { people.map { .station($0.identity) } }
  var latestOffer: NativeStationPassageOffer? { offers.last }
  func latestReplies(for offer: NativeStationPassageOffer) -> [NativeStationPassageReply] {
    people.compactMap { person in
      replies.last { $0.person == person.identity && $0.offer == offer.id }
    }
  }
}

enum NativeStationPassengerJourney {
  static let stateID = "l337.contract/cabin-journey"
  static let batch = "avenor-cabin-journey-01"
  static let digest = "2e2f46e0bed56f79c489cf21c438289c07469511336beaf1ef953f38253dc800"
  static let source = ContractStationIdentity(galaxy: 0, system: 7, stationClass: "main-orbital")
  static let destination = ContractStationIdentity(
    galaxy: 0, system: 185, stationClass: "main-orbital")
  static let reward = 6100
  static let boardID = "cabin-journey"

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
  static func requestConsent(
    state: inout NativeStationPassengerJourneyState, game: borrowing Game,
    destination requested: SystemIdentity
  ) throws {
    guard state.boarding == nil, state.owner == game.commander.equipmentOwnerID,
      state.definition.valid,
      state.offers.count < 64, state.replies.count <= 254,
      game.nativeMainStationDockEvidenceIsCurrent, game.contractStation == source,
      let dock = game.commander.nativeStations?.currentMainDock, state.source == dock.station,
      let collector = game.commander.flightSimulation.player,
      let carrier = game.commander.hullInstanceID,
      let inventory = game.commander.equipmentInventory
    else { throw MissionPackError("Request passage from the actual Avenor passage office.") }
    let slots = game.commander.accommodation.fittedBerths.filter {
      !$0.use.used && $0.lifeSupportWorking && $0.humanoidCompatible
    }.sorted { $0.id.uuidString < $1.id.uuidString }
    let reach = ScriptCourierReach(game.commander)
    let route =
      ScriptCourierGeneration.routes(origin: source, reach: reach).first {
        $0.last == requested.system && requested.galaxy == 0 && $0.count == 2
      } ?? []
    if let previous = state.latestOffer {
      for person in state.people {
        let reply = try replyToPassageOffer(
          person: person.identity, offer: previous, state: state, game: game)
        if reply.kind == .withdraw { state.replies.append(reply) }
      }
    }
    guard state.replies.count <= 254 else {
      throw MissionPackError("The native reply history is full.")
    }
    let revision = UInt64(state.offers.count + 1)
    let offer = NativeStationPassageOffer(
      id: ScriptIdentity.uuid(
        "native-passage-offer-v1:\(state.owner):\(state.definition.batch):\(revision)"),
      revision: revision, dock: dock, collector: collector, carrier: carrier,
      inventoryRevision: inventory.revision, destination: requested, reach: reach, path: route,
      berths: game.commander.passengerFit?.allowed == true ? Array(slots.prefix(2)) : [],
      physicalTime: game.commander.flightSimulation.physicalTime,
      epoch: game.nativeStationRuntimeEpoch)
    state.offers.append(offer)
    for person in state.people {
      let reply = try replyToPassageOffer(
        person: person.identity, offer: offer, state: state, game: game)
      state.replies.append(reply)
    }
  }

  static func replyToPassageOffer(
    person identity: NativeStationPersonIdentity, offer: NativeStationPassageOffer,
    state: NativeStationPassengerJourneyState, game: borrowing Game
  ) throws -> NativeStationPassageReply {
    guard state.boarding == nil, state.owner == game.commander.equipmentOwnerID,
      let person = state.people.first(where: { $0.identity == identity }),
      let request = person.currentRequest,
      person.custodian == state.source, person.identity.owner == state.owner,
      game.nativeMainStationDockEvidenceIsCurrent, game.contractStation == source,
      let dock = game.commander.nativeStations?.currentMainDock, state.source == dock.station,
      let carrier = game.commander.hullInstanceID,
      let inventory = game.commander.equipmentInventory
    else { throw MissionPackError("A reply needs the actual living original station individual.") }
    guard let index = state.people.firstIndex(where: { $0.identity == identity }) else {
      throw SaveError.invalidCommander
    }
    let epoch = game.nativeStationRuntimeEpoch
    let offered = offer.berths.indices.contains(index) ? offer.berths[index] : nil
    let berth = offered?.id
    let observed = game.commander.accommodation.fittedBerths.first { $0.id == berth }
    let inventoryRevision = inventory.revision
    let kind: NativeStationPassageReplyKind
    if request.intent == .withdrawn || state.latestOffer?.id != offer.id || offer.dock != dock
      || offer.carrier != carrier || offer.epoch != epoch
      || offer.inventoryRevision != inventoryRevision
      || (offer.berths.count == 2 && observed != offered)
    {
      kind = .withdraw
    } else if request.destination != offer.destination
      || offer.path != [7, 185] || offer.berths.count != 2 || berth == nil
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
      physicalTime: game.commander.flightSimulation.physicalTime,
      epoch: game.nativeStationRuntimeEpoch)
  }
}

extension ScriptPackLibrary {
  static func validateStationPassengerJourney(_ manifest: ScriptManifest) throws {
    guard let declaration = manifest.stationJourney else {
      guard !manifest.capabilities.contains("native-station-passengers-v1") else {
        throw MissionPackError("Native passage needs its closed original declaration.")
      }
      return
    }
    let capabilities: Set<String> = [
      "script-lua-v1", "story-v2", "durable-commands-v2", "contracts-basic-v2",
      "local-flight-clocks-v2", "native-station-passengers-v1",
    ]
    guard declaration.valid, manifest.stateID == NativeStationPassengerJourney.stateID,
      manifest.version == "1.0.0", Set(manifest.capabilities) == capabilities,
      manifest.mission.milestones.count == 2, manifest.board == nil,
      manifest.courier == nil, manifest.freight == nil, manifest.procurement == nil,
      manifest.pledge == nil, manifest.coldChain == nil, manifest.repairLoop == nil,
      manifest.providerContract == nil, manifest.trial == nil,
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
