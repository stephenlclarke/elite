import Foundation

extension NativeStationPassengerJourney {
  static func berthsValid(_ commander: borrowing Commander) -> Bool {
    let held = commander.nativePeople?.held.filter { $0.person.station != nil } ?? []
    for berth in commander.accommodation.ownedBerths {
      if case .nativePerson(let person) = berth.use {
        if person.evacuation != nil {
          guard NativeOriginalEvacuation.berthValid(berth, commander: commander) else {
            return false
          }
          continue
        }
        if person.rescue != nil {
          guard NativeOriginalRescueJourney.berthValid(berth, commander: commander) else {
            return false
          }
          continue
        }
        guard person.station != nil,
          held.contains(where: { $0.person == person && $0.tool == berth.id }),
          commander.accommodation.fitted.contains(berth.id), berth.lifeSupportWorking,
          berth.humanoidCompatible
        else { return false }
      }
    }
    for person in held {
      guard person.origin == .stationPassenger,
        commander.accommodation.ownedBerths.contains(where: {
          $0.id == person.tool && $0.use == .nativePerson(person.person)
        })
      else { return false }
    }
    return true
  }
  static func validAdmission(_ admission: NativePeopleAdmission, commander: borrowing Commander)
    -> Bool
  {
    guard admission.origin == .stationPassenger, let identity = admission.person.station,
      let people = commander.nativePeople, let state = people.stationJourney,
      let boarding = state.boarding,
      let index = state.people.firstIndex(where: { $0.identity == identity }),
      boarding.berths.indices.contains(index), identity.valid, identity.owner == state.owner,
      admission.owner == state.owner, admission.operation == boarding.operation,
      admission.actor == boarding.dock.actor, admission.collector == boarding.collector,
      admission.hull == boarding.carrier, admission.tool == boarding.berths[index],
      admission.inventoryRevision == boarding.inventoryRevision,
      admission.physicalTime == boarding.physicalTime, admission.epoch == boarding.epoch
    else { return false }
    if people.transfer(for: admission.person) == nil {
      guard commander.hullInstanceID == boarding.carrier,
        commander.accommodation.ownedBerths.contains(where: {
          $0.id == admission.tool && $0.use == .nativePerson(admission.person)
        })
      else { return false }
    }
    return true
  }
  static func validSource(
    _ optional: NativeStationPassengerJourneyState?, custody: NativePeopleCustodyState,
    commander: borrowing Commander
  ) -> Bool {
    var missions: [UUID] = []
    for mission in commander.scriptState.instances.values {
      if mission.definition == stateID || mission.digest == digest { missions.append(mission.id) }
    }
    var boards: [String] = []
    for (key, board) in commander.contracts.boards {
      if (board.provider == "l337.contract" && board.id == boardID)
        || board.digest == digest || board.group == stateID
      {
        boards.append(key)
      }
    }
    guard let state = optional else {
      guard missions.isEmpty, boards.isEmpty else { return false }
      return custody.admissions.allSatisfy { $0.person.station?.batch != batch }
    }
    guard state.owner == custody.owner, state.owner == commander.equipmentOwnerID,
      state.definition.valid, state.version == "1.0.0", state.digest == digest,
      state.source == state.registration.station, sourceMatches(state.registration),
      historicalDock(state.registration, commander: commander),
      state.stationActor == state.registration.actor, state.people.count == 2,
      Set(state.people.map(\.identity)).count == 2, state.offers.count <= 64,
      state.replies.count <= 256
    else { return false }
    for (index, person) in state.people.enumerated() {
      guard
        person.identity
          == NativeStationPersonIdentity(
            owner: state.owner, batch: batch,
            person: state.definition.people[index].id),
        person.name == state.definition.people[index].name,
        person.custodian == state.source, (1...64).contains(person.travelRequests.count)
      else { return false }
      for (revision, request) in person.travelRequests.enumerated() {
        guard request.revision == UInt64(revision + 1),
          request.destination == SystemIdentity(galaxy: 0, system: 185)
        else { return false }
      }
    }
    for (index, offer) in state.offers.enumerated() {
      guard offer.revision == UInt64(index + 1),
        offer.id
          == ScriptIdentity.uuid(
            "native-passage-offer-v1:\(state.owner):\(batch):\(offer.revision)"),
        historicalDock(offer.dock, commander: commander), offer.dock.station == state.source,
        offer.collector.system == state.source.system, offer.collector.entity == 0,
        offer.collector.visit == offer.dock.actor.visit, offer.reach.valid,
        offer.reach.revision == "elite-canonical-native-reach-v2",
        (0..<8).contains(offer.destination.galaxy), (0..<256).contains(offer.destination.system),
        offer.physicalTime.isFinite, offer.physicalTime >= 0,
        offer.physicalTime <= commander.flightSimulation.physicalTime,
        offer.berths.count <= 2, Set(offer.berths.map(\.id)).count == offer.berths.count,
        offer.berths.allSatisfy({ !$0.use.used && $0.lifeSupportWorking && $0.humanoidCompatible })
      else { return false }
      let route =
        ScriptCourierGeneration.routes(origin: source, reach: offer.reach).first {
          $0.last == offer.destination.system && offer.destination.galaxy == 0 && $0.count == 2
        } ?? []
      guard offer.path == route else { return false }
      for person in state.people {
        guard
          state.replies.contains(where: { $0.offer == offer.id && $0.person == person.identity })
        else { return false }
      }
    }
    for (index, reply) in state.replies.enumerated() {
      guard reply.sequence == UInt64(index + 1),
        let personIndex = state.people.firstIndex(where: { $0.identity == reply.person }),
        let offer = state.offers.first(where: { $0.id == reply.offer }),
        let request = state.people[personIndex].travelRequests.first(where: {
          $0.revision == reply.personRevision
        }),
        reply.observedOfferRevision >= offer.revision,
        reply.observedOfferRevision <= UInt64(state.offers.count),
        historicalDock(reply.dock, commander: commander), reply.dock.station == state.source,
        reply.physicalTime.isFinite, reply.physicalTime >= offer.physicalTime,
        reply.physicalTime <= commander.flightSimulation.physicalTime,
        reply.berth
          == (offer.berths.indices.contains(personIndex) ? offer.berths[personIndex].id : nil)
      else { return false }
      let withdrawn =
        request.intent == .withdrawn || reply.observedOfferRevision != offer.revision
        || reply.dock != offer.dock || reply.carrier != offer.carrier || reply.epoch != offer.epoch
        || reply.inventoryRevision != offer.inventoryRevision
        || (offer.berths.count == 2 && reply.observedBerth != offer.berths[personIndex])
      let eligible =
        request.destination == offer.destination && offer.path == [7, 185]
        && offer.berths.count == 2
      switch reply.kind {
      case .accept: if withdrawn || !eligible { return false }
      case .refuse: if withdrawn || eligible { return false }
      case .withdraw: if !withdrawn { return false }
      }
    }
    guard let boarding = state.boarding else {
      guard state.terminalOperation == nil, missions.isEmpty, boards.isEmpty,
        !custody.admissions.contains(where: { $0.person.station?.batch == batch })
      else { return false }
      return true
    }
    let boardKey = digest + "/" + boardID + "/" + source.key
    guard missions == [boarding.mission], boards == [boardKey],
      boarding.replyOrdinals.count == 2, Set(boarding.replyOrdinals).count == 2,
      boarding.berths.count == 2, Set(boarding.berths).count == 2,
      let offer = state.latestOffer, offer.id == boarding.offer,
      boarding.dock == offer.dock, boarding.collector == offer.collector,
      boarding.carrier == offer.carrier, boarding.inventoryRevision == offer.inventoryRevision,
      boarding.epoch == offer.epoch, boarding.berths == offer.berths.map(\.id),
      boarding.physicalTime.isFinite, boarding.physicalTime >= offer.physicalTime,
      boarding.physicalTime <= commander.flightSimulation.physicalTime,
      let mission = commander.scriptState.instances[boarding.mission],
      validJob(mission, sourceState: state, offer: offer),
      let job = mission.contract, let board = commander.contracts.boards[boardKey],
      board.valid, board.id == boardID, board.provider == "l337.contract",
      board.version == state.version, board.digest == digest, board.station == source,
      board.revision == 0, board.seed == 0, board.clock == .local, board.period == 3600,
      board.group == stateID, board.offers.count == 1,
      custody.admissions.filter({ $0.person.station?.batch == batch }).map(\.person)
        == state.references
    else { return false }
    var acceptedOffer = job.offer
    acceptedOffer.status = .accepted(boarding.mission)
    guard board.offers == [acceptedOffer] else { return false }
    for (index, ordinal) in boarding.replyOrdinals.enumerated() {
      guard state.replies.indices.contains(ordinal) else { return false }
      let reply = state.replies[ordinal]
      guard let request = state.people[index].currentRequest,
        request.intent == .passage, request.destination == offer.destination,
        reply.personRevision == request.revision,
        state.latestReplies(for: offer).indices.contains(index),
        state.latestReplies(for: offer)[index] == reply,
        reply.kind == .accept, reply.person == state.people[index].identity,
        reply.offer == offer.id, reply.berth == boarding.berths[index],
        reply.physicalTime <= boarding.physicalTime
      else { return false }
    }
    if let operation = state.terminalOperation {
      guard let transfer = custody.transfers.first(where: { $0.operation == operation }),
        transfer.members.filter({ $0.station?.batch == batch }) == state.references,
        state.references.allSatisfy({ custody.transfer(for: $0)?.operation == operation }),
        let receipt = mission.completionReceipt,
        receipt.valid(for: mission, engine: commander.scriptState),
        receipt.causeKind == "mission.receipted", receipt.cause?.nativeMainDock == transfer.dock,
        receipt.committed.nativeMainDock == transfer.dock
      else { return false }
      switch transfer.kind {
      case .care:
        guard let dock = transfer.dock else { return false }
        if destinationMatches(dock) {
          return mission.outcome == .complete && mission.contract?.settlementAmount == reward
            && mission.milestones == [0, 1]
        }
        return sourceMatches(dock) && mission.outcome == .abandoned
          && mission.contract?.settlementAmount == 0
      case .loss, .escape:
        return mission.outcome == .failed && mission.contract?.settlementAmount == 0
      case .sale: return false
      }
    }
    return mission.outcome == .active && mission.completionReceipt == nil
      && state.references.allSatisfy { custody.transfer(for: $0) == nil }
  }

  static func parameters(
    _ state: NativeStationPassengerJourneyState, offer: NativeStationPassageOffer
  ) -> ScriptValue {
    .object([
      "station_passage": .object([
        "batch": .string(batch), "offer": .string(offer.id.uuidString),
        "route": .array(offer.path.map { .integer(Int64($0)) }),
        "people": .array(state.people.map { .string($0.identity.id.uuidString) }),
        "berths": .array(offer.berths.map { .string($0.id.uuidString) }),
      ])
    ])
  }
  static func validJob(
    _ mission: ScriptInstance, sourceState state: NativeStationPassengerJourneyState,
    offer: NativeStationPassageOffer
  ) -> Bool {
    guard mission.definition == stateID, mission.version == state.version,
      mission.digest == state.digest,
      let job = mission.contract, job.valid, job.provider == "l337.contract", job.digest == digest,
      job.version == "1.0.0", job.station == source, job.boardRevision == 0,
      job.boardKey == digest + "/" + boardID + "/" + source.key, job.group == stateID,
      job.clock == .local, job.deadline == nil, job.offer.duration == 0,
      job.offer.reward == reward, job.offer.deposit == 0, job.offer.failureReward == 0,
      !job.offer.refundOnFailure, job.offer.destinationGalaxy == 0,
      job.offer.destinationSystem == 185,
      job.offer.parameters == parameters(state, offer: offer),
      mission.id == Game.contractJobIdentity(job.offer.id),
      mission.payloads.isEmpty, mission.ownedEncounters.isEmpty, mission.gearIssues.isEmpty,
      mission.choiceReceipts.isEmpty, mission.timers.isEmpty
    else { return false }
    return mission.milestones == (mission.outcome == .complete ? Set([0, 1]) : Set([0]))
  }
}

enum NativeStationPassengerJourneySave {
  static let version = 41
  static let alienVersion = 42
  static func contains(_ schema: Int?) -> Bool { schema == version || schema == alienVersion }
  static func lowerSchema(_ schema: Int?) -> Int? {
    contains(schema)
      ? (schema == alienVersion
        ? OriginalConsentedFreightSupplySave.alienVersion
        : OriginalConsentedFreightSupplySave.version) : schema
  }
  static func hasClaims(_ commander: borrowing Commander) -> Bool {
    if commander.nativePeople?.stationJourney != nil { return true }
    for mission in commander.scriptState.instances.values {
      if mission.definition == NativeStationPassengerJourney.stateID
        || mission.digest == NativeStationPassengerJourney.digest
      {
        return true
      }
    }
    for berth in commander.accommodation.ownedBerths {
      if case .nativePerson(let person) = berth.use,
        person.station?.batch == NativeStationPassengerJourney.batch
      {
        return true
      }
    }
    for person in commander.nativePeople?.admissions ?? [] {
      if person.person.station?.batch == NativeStationPassengerJourney.batch { return true }
    }
    for receipt in commander.nativePeople?.transfers ?? [] {
      if receipt.members.contains(where: {
        $0.station?.batch == NativeStationPassengerJourney.batch
      }) {
        return true
      }
    }
    for board in commander.contracts.boards.values {
      if (board.provider == "l337.contract" && board.id == "cabin-journey")
        || board.digest == NativeStationPassengerJourney.digest
        || board.group == NativeStationPassengerJourney.stateID
      {
        return true
      }
    }
    return false
  }
  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    guard let custody = commander.nativePeople else { return !hasClaims(commander) }
    guard
      NativeStationPassengerJourney.validSource(
        custody.stationJourney, custody: custody, commander: commander),
      NativeStationPassengerJourney.berthsValid(commander)
    else { return false }
    return true
  }
}

extension NativeStationPassengerJourneySave {
  /// Inspect only the native header/mission/contract paths, never authored script data keys.
  static func validateFields(
    _ data: Data, part: ScriptFreightVersionedSave.Part, schema: Int?,
    allowOriginalRescue: Bool = false, allowOriginalEvacuation: Bool = false
  ) throws {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      root["stationJourney"] == nil, root["nativePerson"] == nil
    else { throw SaveError.invalidCommander }
    let allowed = contains(schema)
    func records(_ raw: Any?) throws -> [[String: Any]] {
      guard let raw else { return [] }
      let values: [Any]
      if let map = raw as? [String: Any], map.count <= 128 {
        values = Array(map.values)
      } else if let pairs = raw as? [Any], pairs.count % 2 == 0, pairs.count <= 256 {
        values = stride(from: 1, to: pairs.count, by: 2).map { pairs[$0] }
      } else {
        throw SaveError.invalidCommander
      }
      return try values.map { value in
        guard let object = value as? [String: Any] else { throw SaveError.invalidCommander }
        return object
      }
    }
    func missions(_ object: [String: Any], embedded: Bool) throws {
      for instance in try records(object["instances"]) {
        guard instance["stationJourney"] == nil, instance["nativePerson"] == nil else {
          throw SaveError.invalidCommander
        }
        if instance["definition"] as? String == NativeStationPassengerJourney.stateID {
          guard allowed, !embedded else { throw SaveError.invalidCommander }
        }
      }
    }
    func contracts(_ object: [String: Any], embedded: Bool) throws {
      for board in try records(object["boards"]) {
        guard board["stationJourney"] == nil, board["nativePerson"] == nil else {
          throw SaveError.invalidCommander
        }
        if board["provider"] as? String == "l337.contract",
          board["id"] as? String == "cabin-journey"
        {
          guard allowed, !embedded else { throw SaveError.invalidCommander }
        }
      }
    }
    if part != .commander {
      guard root["savedNativePeopleCustody"] == nil, root["savedAccommodation"] == nil else {
        throw SaveError.invalidCommander
      }
      if part == .missions {
        try missions(root, embedded: false)
      } else {
        try contracts(root, embedded: false)
      }
      return
    }
    let custody = root["savedNativePeopleCustody"] as? [String: Any] ?? [:]
    let hasLeaf = custody.keys.contains("stationJourney")
    if hasLeaf {
      guard allowed, let raw = custody["stationJourney"] as? [String: Any] else {
        throw SaveError.invalidCommander
      }
      guard let people = raw["people"] as? [[String: Any]], people.count == 2,
        let offers = raw["offers"] as? [[String: Any]], offers.count <= 64,
        let replies = raw["replies"] as? [Any], replies.count <= 256
      else { throw SaveError.invalidCommander }
      for person in people {
        guard let requests = person["travelRequests"] as? [Any], (1...64).contains(requests.count)
        else { throw SaveError.invalidCommander }
      }
      for offer in offers {
        guard let slots = offer["berths"] as? [Any], slots.count <= 2,
          let path = offer["path"] as? [Any], path.count <= 2
        else { throw SaveError.invalidCommander }
      }
      let bytes = try JSONSerialization.data(withJSONObject: raw)
      let leaf = try JSONDecoder().decode(NativeStationPassengerJourneyState.self, from: bytes)
      let canonical = try JSONSerialization.jsonObject(with: JSONEncoder().encode(leaf))
      guard (raw as NSDictionary).isEqual(canonical) else { throw SaveError.invalidCommander }
    }
    func reference(_ raw: Any?) throws {
      guard let object = raw as? [String: Any], object.keys.contains("station") else { return }
      let bytes = try JSONSerialization.data(withJSONObject: object)
      let person = try JSONDecoder().decode(NativePersonReference.self, from: bytes)
      guard person.station?.valid == true else { throw SaveError.invalidCommander }
      guard person.station?.batch == NativeStationPassengerJourney.batch else { return }
      guard allowed, hasLeaf, Set(object.keys) == ["station"],
        (object as NSDictionary).isEqual(
          try JSONSerialization.jsonObject(with: JSONEncoder().encode(person)))
      else { throw SaveError.invalidCommander }
    }
    if let admissions = custody["admissions"] as? [[String: Any]] {
      guard admissions.count <= NativePeopleCustodyState.maximumPeople else {
        throw SaveError.invalidCommander
      }
      for admission in admissions {
        guard admission["stationJourney"] == nil else { throw SaveError.invalidCommander }
        try reference(admission["person"])
      }
    }
    if let transfers = custody["transfers"] as? [[String: Any]] {
      guard transfers.count <= NativePeopleCustodyState.maximumPeople else {
        throw SaveError.invalidCommander
      }
      for transfer in transfers {
        guard transfer["stationJourney"] == nil else { throw SaveError.invalidCommander }
        for person in transfer["members"] as? [Any] ?? [] { try reference(person) }
      }
    }
    let accommodation = root["savedAccommodation"] as? [String: Any] ?? [:]
    guard accommodation["stationJourney"] == nil else { throw SaveError.invalidCommander }
    for berth in accommodation["ownedBerths"] as? [[String: Any]] ?? [] {
      guard berth["stationJourney"] == nil else { throw SaveError.invalidCommander }
      if let use = berth["use"] as? [String: Any], use.keys.contains("nativePerson") {
        let decoded = try JSONDecoder().decode(
          PassengerPlaceUse.self, from: JSONSerialization.data(withJSONObject: use))
        guard case .nativePerson(let person) = decoded else { throw SaveError.invalidCommander }
        if let evacuation = person.evacuation {
          guard allowOriginalEvacuation, evacuation.valid else { throw SaveError.invalidCommander }
          continue
        }
        if let rescue = person.rescue {
          // The coordinator has already validated this rescue in its original G08 schema.
          guard allowOriginalRescue, rescue.valid else { throw SaveError.invalidCommander }
          continue
        }
        guard person.station?.valid == true else { throw SaveError.invalidCommander }
        guard person.station?.batch == NativeStationPassengerJourney.batch else { continue }
        guard allowed, hasLeaf, Set(use.keys) == ["nativePerson"],
          (use as NSDictionary).isEqual(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)))
        else { throw SaveError.invalidCommander }
      }
    }
    if let embedded = root["savedScriptState"] as? [String: Any] {
      try missions(embedded, embedded: true)
    }
    if let embedded = root["savedContracts"] as? [String: Any] {
      try contracts(embedded, embedded: true)
    }
  }
}
