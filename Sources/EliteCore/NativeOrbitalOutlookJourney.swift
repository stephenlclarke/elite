import Foundation

struct NativeOrbitalOutlookPersonDefinition: Codable, Sendable, Equatable {
  let id: String
  let name: String
}
struct NativeOrbitalOutlookJourneyDefinition: Codable, Sendable, Equatable {
  let batch: String
  let sourceGalaxy: Int
  let sourceSystem: Int
  let destinationGalaxy: Int
  let destinationSystem: Int
  let itinerary: [String]
  let people: [NativeOrbitalOutlookPersonDefinition]
  var valid: Bool {
    batch == NativeOrbitalOutlookJourney.batch && sourceGalaxy == 0 && sourceSystem == 7
      && destinationGalaxy == 0 && destinationSystem == 7
      && itinerary == NativeOrbitalOutlookJourney.views
      && people == [
        .init(id: "lysa-renn", name: "Lysa Renn"), .init(id: "tovan-hale", name: "Tovan Hale"),
      ]
  }
}

enum NativeOrbitalTravelIntent: String, Codable, Sendable { case passage, withdrawn }
struct NativeOrbitalTravelRequest: Codable, Sendable, Equatable {
  let revision: UInt64
  let destination: SystemIdentity
  let itinerary: [String]
  let intent: NativeOrbitalTravelIntent
}
struct NativeOrbitalPersonRecord: Codable, Sendable, Equatable {
  let identity: NativeStationPersonIdentity
  let name: String
  let custodian: NativeMainStationIdentity
  var travelRequests: [NativeOrbitalTravelRequest]
  var currentRequest: NativeOrbitalTravelRequest? { travelRequests.last }
}
struct NativeOrbitalPassageOffer: Codable, Sendable, Equatable {
  let id: UUID
  let revision: UInt64
  let dock: NativeMainStationDockReceipt
  let collector: ActorIdentity
  let carrier: UUID
  let inventoryRevision: UInt64
  let destination: SystemIdentity
  let itinerary: [String]
  let reach: ScriptCourierReach
  let path: [Int]
  let berths: [PassengerBerth]
  let physicalTime: Double
  let epoch: UUID
}
enum NativeOrbitalPassageReplyKind: String, Codable, Sendable { case accept, refuse, withdraw }
struct NativeOrbitalPassageReply: Codable, Sendable, Equatable {
  let sequence: UInt64
  let person: NativeStationPersonIdentity
  let offer: UUID
  let personRevision: UInt64
  let observedOfferRevision: UInt64
  let kind: NativeOrbitalPassageReplyKind
  let dock: NativeMainStationDockReceipt
  let carrier: UUID
  let berth: UUID?
  let observedBerth: PassengerBerth?
  let inventoryRevision: UInt64
  let physicalTime: Double
  let epoch: UUID
}
struct NativeOrbitalOutlookBoarding: Codable, Sendable, Equatable {
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
struct NativeOrbitalOutlookJourneyState: Codable, Sendable, Equatable {
  let owner: UUID
  let definition: NativeOrbitalOutlookJourneyDefinition
  let version: String
  let digest: String
  let source: NativeMainStationIdentity
  let registration: NativeMainStationDockReceipt
  let stationActor: ActorIdentity
  var people: [NativeOrbitalPersonRecord]
  var offers: [NativeOrbitalPassageOffer] = []
  var replies: [NativeOrbitalPassageReply] = []
  var boarding: NativeOrbitalOutlookBoarding?
  var terminalOperation: UUID?
  var readings: [NativeOrbitalOutlookReading] = []
  var authorities: [NativeOrbitalOutlookAuthority] = []
  var references: [NativePersonReference] { people.map { .station($0.identity) } }
  var latestOffer: NativeOrbitalPassageOffer? { offers.last }
  func latestReplies(for offer: NativeOrbitalPassageOffer) -> [NativeOrbitalPassageReply] {
    people.compactMap { person in
      replies.last { $0.person == person.identity && $0.offer == offer.id }
    }
  }
}

enum NativeOrbitalOutlookJourney {
  static let stateID = "l337.contract/orbital-outlook"
  static let batch = "avenor-orbital-outlook-01"
  static let digest = "cf5076adbecad912603ddd146aeb2ead31621bf698ff4a4a7071a2b66b2cf798"
  static let source = ContractStationIdentity(galaxy: 0, system: 7, stationClass: "main-orbital")
  static let destination = ContractStationIdentity(
    galaxy: 0, system: 7, stationClass: "main-orbital")
  static let objective = ContractStationIdentity(
    galaxy: 0, system: 185, stationClass: "main-orbital")
  static let encounterID = "orbital-views"
  static let views = ["outlook-one", "outlook-two", "outlook-three"]
  static let reward = 8700
  static let boardID = "orbital-outlook"

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
    dock.station.system == SystemIdentity(galaxy: 0, system: 7)
  }
  static func nativeInstancePresent(_ commander: borrowing Commander) -> Bool {
    for state in commander.scriptState.instances.values {
      if state.definition == stateID { return true }
    }
    return false
  }

  /// Player input requests passage. Only the native original person's policy creates its reply.
  static func requestConsent(
    state: inout NativeOrbitalOutlookJourneyState, game: borrowing Game,
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
    let slots = game.commander.accommodation.availablePlaces(privateCabin: true).sorted {
      $0.id.uuidString < $1.id.uuidString
    }
    let reach = ScriptCourierReach(game.commander)
    let route = itineraryRoute(reach: reach, requested: requested)
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
    let offer = NativeOrbitalPassageOffer(
      id: ScriptIdentity.uuid(
        "native-passage-offer-v1:\(state.owner):\(state.definition.batch):\(revision)"),
      revision: revision, dock: dock, collector: collector, carrier: carrier,
      inventoryRevision: inventory.revision, destination: requested,
      itinerary: state.definition.itinerary, reach: reach, path: route,
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
    person identity: NativeStationPersonIdentity, offer: NativeOrbitalPassageOffer,
    state: NativeOrbitalOutlookJourneyState, game: borrowing Game
  ) throws -> NativeOrbitalPassageReply {
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
    let observed = game.commander.accommodation.availablePlaces(privateCabin: true).first {
      $0.id == berth
    }
    let inventoryRevision = inventory.revision
    let kind: NativeOrbitalPassageReplyKind
    if request.intent == .withdrawn || state.latestOffer?.id != offer.id || offer.dock != dock
      || offer.carrier != carrier || offer.epoch != epoch
      || offer.inventoryRevision != inventoryRevision
      || (offer.berths.count == 2 && observed != offered)
    {
      kind = .withdraw
    } else if request.destination != offer.destination || request.itinerary != offer.itinerary
      || offer.itinerary != views
      || offer.path != [7, 185, 7] || offer.berths.count != 2 || berth == nil
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

extension NativeOrbitalOutlookJourney {
  static func itineraryRoute(reach: ScriptCourierReach, requested: SystemIdentity) -> [Int] {
    guard requested == SystemIdentity(galaxy: 0, system: 7),
      ScriptCourierGeneration.routes(origin: source, reach: reach).contains([7, 185]),
      ScriptCourierGeneration.routes(origin: objective, reach: reach).contains([185, 7])
    else { return [] }
    return [7, 185, 7]
  }
}

extension ScriptPackLibrary {
  static func validateOrbitalOutlookJourney(_ manifest: ScriptManifest) throws {
    guard let declaration = manifest.orbitalOutlook else {
      guard !manifest.capabilities.contains("native-orbital-outlook-v1") else {
        throw MissionPackError("Native passage needs its closed original declaration.")
      }
      return
    }
    let capabilities: Set<String> = [
      "script-lua-v1", "story-v2", "durable-commands-v2", "contracts-basic-v2",
      "local-flight-clocks-v2", "native-orbital-outlook-v1", "profiled-encounters-v2",
    ]
    guard declaration.valid, manifest.stateID == NativeOrbitalOutlookJourney.stateID,
      manifest.version == "1.0.0", Set(manifest.capabilities) == capabilities,
      manifest.mission.milestones.count == 5, manifest.board == nil,
      manifest.courier == nil, manifest.freight == nil, manifest.procurement == nil,
      manifest.pledge == nil, manifest.coldChain == nil, manifest.repairLoop == nil,
      manifest.providerContract == nil, manifest.trial == nil,
      (manifest.passengerParties ?? []).isEmpty, (manifest.collections ?? []).isEmpty,
      validMarkers(manifest),
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

extension ScriptPackLibrary {
  static func validMarkers(_ manifest: ScriptManifest) -> Bool {
    guard let encounters = manifest.encounters, encounters.count == 1,
      let encounter = encounters.first, encounter.id == NativeOrbitalOutlookJourney.encounterID,
      encounter.galaxy == 0, encounter.system == 185,
      encounter.profile == "profiled-local-freeze-v1", encounter.actors.count == 3,
      let npcs = manifest.npcs, npcs.count == 1, let npc = npcs.first,
      npc.valid, npc.id == "outlook-marker", npc.model == "catalogue:SH040", npc.scale == 1,
      npc.energy == 100, npc.recharge == 0, npc.speed == 0, npc.acceleration == 0,
      npc.pitch == 0, npc.yaw == 0, npc.roll == 0, npc.missiles == 0, npc.fuel == 0,
      !npc.ecm, npc.bounty == 0, npc.drive == nil,
      (npc.lasers ?? []).isEmpty, (npc.components ?? []).isEmpty
    else { return false }
    let positions = [Vector3(-5000, 0, 20000), Vector3(0, 4000, 24000), Vector3(5000, 0, 28000)]
    for (index, actor) in encounter.actors.enumerated() {
      guard actor.id == NativeOrbitalOutlookJourney.views[index], actor.npc == npc.id,
        actor.hull == nil, !actor.hostile,
        Vector3(actor.x, actor.y, actor.z) == positions[index]
      else { return false }
    }
    return true
  }
}
