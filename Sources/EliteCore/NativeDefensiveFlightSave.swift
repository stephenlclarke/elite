import Foundation

enum NativeDefensiveFlightSave {
  static let version = 135
  static let alienVersion = 136
  static func contains(_ schema: Int?) -> Bool { schema == version || schema == alienVersion }
  static func marked(_ instance: ScriptInstance) -> Bool {
    instance.savedDefensiveFlight != nil || instance.digest == NativeDefensiveFlight.digest
  }
  static func hasClaims(_ commander: borrowing Commander) -> Bool {
    let instances = commander.scriptState.instances
    if instances.values.contains(where: marked) { return true }
    let boards = commander.contracts.boards
    return boards.values.contains { $0.digest == NativeDefensiveFlight.digest }
  }
  static func shapeValid(_ instance: ScriptInstance) -> Bool {
    guard instance.definition == NativeDefensiveFlight.stateID,
      instance.digest == NativeDefensiveFlight.digest,
      instance.version == NativeDefensiveFlight.version,
      let state = instance.savedDefensiveFlight, state.valid,
      state.permission.mission == instance.id,
      (state.terminalOutcome ?? .active) == instance.outcome,
      instance.choiceReceipts[NativePracticeSource.consentGroup] == state.permission.consent,
      instance.payloads.isEmpty, instance.gearIssues.isEmpty, instance.ownedEncounters.isEmpty,
      instance.timers.isEmpty, instance.savedFlightReception == nil
    else { return false }
    if let original = state.original {
      guard let provider = instance.savedNativePractice, state.matches(provider),
        original.permission.mission == state.permission.mission,
        provider.hits.isEmpty || state.failure != nil,
        !state.ready || provider.endedAt != nil
      else { return false }
    } else if instance.savedNativePractice != nil {
      return false
    }
    return instance.milestones == state.milestones
  }

  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    let instances = commander.scriptState.instances
    let boardCache = commander.contracts.boards
    let physicalTime = commander.flightSimulation.physicalTime
    let nextEmission = commander.flightSimulation.nextEmission
    let nextIncident = commander.flightSimulation.nextIncident
    let currentVisit = commander.flightSimulation.visit
    let own = instances.values.filter(marked)
    guard own.count <= 128, own.filter({ $0.outcome == .active }).count <= 1 else { return false }
    var attempts: Set<Int> = []
    for instance in own {
      guard shapeValid(instance), let state = instance.savedDefensiveFlight,
        let owner = commander.equipmentOwnerID, state.permission.owner == owner,
        state.permission.consent.valid(for: instance, engine: commander.scriptState),
        NativeFlightReceptionSave.historicalDock(state.permission.dock, commander: commander),
        state.permission.acceptedAt <= physicalTime,
        state.attemptPlayer.map({ $0.visit <= currentVisit }) ?? true,
        state.previous.map({ $0.reading.time <= physicalTime }) ?? true,
        state.windows.allSatisfy({ $0.last.reading.time <= physicalTime }),
        state.pending.map({ $0.last.reading.time <= physicalTime }) ?? true,
        failureAllocated(
          state.failure, physicalTime: physicalTime,
          nextEmission: nextEmission, nextIncident: nextIncident),
        let job = instance.contract, job.provider == "l337.training",
        job.digest == instance.digest, job.version == instance.version,
        job.group == instance.definition,
        job.station.galaxy == 0, job.station.system == 7,
        job.station.stationClass == "main-orbital",
        job.boardRevision == 0, job.clock == .local, job.deadline == nil,
        job.offer.reward == 0, job.offer.deposit == 0, job.offer.failureReward == 0,
        !job.offer.refundOnFailure, job.offer.duration == 0,
        job.offer.destinationGalaxy == 0, job.offer.destinationSystem == 7,
        job.offer.parameters == .object([:]), job.offer.key.hasPrefix("defensive-flight-"),
        let suffix = job.offer.key.split(separator: "-").last, let attempt = Int(suffix),
        (0..<128).contains(attempt), attempts.insert(attempt).inserted,
        job.boardKey == instance.digest + "/" + NativeDefensiveFlight.boardID + "/"
          + job.station.key,
        job.offer.id == ScriptIdentity.uuid("contract-offer-v1:\(job.boardKey):0:\(job.offer.key)"),
        Game.contractJobIdentity(job.offer.id) == instance.id,
        let board = boardCache[job.boardKey],
        board.offers.first(where: { $0.id == job.offer.id })?.status == .accepted(instance.id)
      else { return false }
      if let receipt = instance.completionReceipt {
        guard receipt.valid(for: instance, engine: commander.scriptState),
          receipt.causeKind == "mission.receipted", job.settlementAmount == 0
        else { return false }
      } else if instance.outcome != .active {
        return false
      }
      if instance.outcome == .complete {
        guard let dock = state.terminalDock, dock.station == state.permission.dock.station,
          dock.sequence > state.permission.dock.sequence,
          NativeFlightReceptionSave.historicalDock(dock, commander: commander),
          instance.completionReceipt?.cause?.nativeMainDock == dock,
          instance.completionReceipt?.committed.nativeMainDock == dock,
          let original = state.original, let disengaged = state.disengagedCalendar,
          dock.calendarSeconds > disengaged,
          dock.actor.visit >= original.permission.player.visit
        else { return false }
      }
    }
    guard attempts == Set(0..<own.count) else { return false }
    let boards = boardCache.filter { $0.value.digest == NativeDefensiveFlight.digest }
    for (key, board) in boards {
      let matching = own.filter { $0.contract?.boardKey == key }
      guard !matching.isEmpty, board.cacheKey == key, board.id == NativeDefensiveFlight.boardID,
        board.provider == "l337.training", board.version == NativeDefensiveFlight.version,
        board.group == NativeDefensiveFlight.stateID, board.revision == 0, board.seed == 0,
        board.clock == .local, board.period == 3600,
        board.offers.count == matching.count,
        Set(board.offers.map(\.id)) == Set(matching.compactMap { $0.contract?.offer.id })
      else { return false }
    }
    guard Set(own.compactMap { $0.contract?.boardKey }) == Set(boards.keys) else { return false }
    let completed = own.filter { $0.outcome == .complete }
    if !completed.isEmpty {
      guard
        let award = commander.scriptState.savedClueJournal?.awards[NativeDefensiveFlight.stateID],
        award.clueID == "defensive-flight-family-trace",
        completed.contains(where: { $0.completionReceipt == award.completion })
      else { return false }
    }
    return true
  }

  private static func failureAllocated(
    _ failure: NativeDefensiveFlightFailure?, physicalTime: Double,
    nextEmission: UInt64, nextIncident: UInt64
  ) -> Bool {
    guard let failure else { return true }
    switch failure {
    case .discharge(_, let emission, let time):
      return time <= physicalTime && (emission.map { $0 < nextEmission } ?? true)
    case .ordinaryHit(let incident):
      return incident.physicalTime <= physicalTime && incident.id < nextIncident
        && incident.origin.emissionID < nextEmission
    case .collision(_, let time), .interruption(_, let time, _): return time <= physicalTime
    case .nearPass(_, let last): return last.time <= physicalTime
    }
  }

  static func publicationVersion(
    defensive: Bool, lesson: Bool, practice: Bool, crewLog: Bool, alien: Bool
  ) -> Int? {
    let previous = NativeSafeGunnerySave.publicationVersion(
      lesson: lesson, practice: practice, crewLog: crewLog, alien: alien)
    guard defensive else { return previous }
    return max(alien ? alienVersion : version, previous ?? 0)
  }

  static func validateArchiveFields(
    _ data: Data, part: ScriptFreightVersionedSave.Part, schema: Int?, alien: Bool
  ) throws {
    try validateFields(data, part: part, schema: schema)
    let lessonSchema = contains(schema) ? (alien ? 128 : 127) : schema
    try NativeSafeGunnerySave.validateFields(data, part: part, schema: lessonSchema)
    let practiceSchema =
      NativeSafeGunnerySave.contains(lessonSchema) ? (alien ? 122 : 121) : lessonSchema
    try NativePracticeSave.validateFields(data, part: part, schema: practiceSchema)
    // C01's closed leaf must see its own namespace before any older-family lowering.
    let predecessor =
      contains(schema)
      ? (alien ? NativeC01SurveyorSave.alienVersion : NativeC01SurveyorSave.version)
      : NativePracticeSave.contains(practiceSchema)
        ? (alien ? NativeInductionCrewLogSave.alienVersion : NativeInductionCrewLogSave.version)
        : practiceSchema
    try ScriptSaveJSONPreflight.validateRepairLoopFields(data, part: part, schema: predecessor)
  }

  static func validateFields(_ data: Data, part: ScriptFreightVersionedSave.Part, schema: Int?)
    throws
  {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      !root.keys.contains("savedDefensiveFlight"), !root.keys.contains("defensiveFlight")
    else { throw SaveError.invalidCommander }
    func instances(_ raw: Any?, embedded: Bool) throws {
      guard let raw else { return }
      let entries: [Any]
      if let dictionary = raw as? [String: Any], dictionary.count <= 128 {
        entries = Array(dictionary.values)
      } else if let pairs = raw as? [Any], pairs.count <= 256, pairs.count.isMultiple(of: 2) {
        entries = stride(from: 1, to: pairs.count, by: 2).map { pairs[$0] }
      } else {
        throw SaveError.invalidCommander
      }
      for entry in entries {
        guard let instance = entry as? [String: Any], !instance.keys.contains("defensiveFlight")
        else {
          throw SaveError.invalidCommander
        }
        let pinned = instance["digest"] as? String == NativeDefensiveFlight.digest
        let leaf = instance["savedDefensiveFlight"]
        guard pinned == (leaf != nil) else { throw SaveError.invalidCommander }
        if let leaf {
          guard contains(schema), !embedded,
            instance["definition"] as? String == NativeDefensiveFlight.stateID,
            let object = leaf as? [String: Any]
          else { throw SaveError.invalidCommander }
          if let windows = object["windows"] {
            guard let windows = windows as? [Any], windows.count <= 4 else {
              throw SaveError.invalidCommander
            }
          }
          if let original = object["original"] {
            guard let original = original as? [String: Any],
              let beacons = original["beacons"] as? [Any], beacons.count == 3,
              let hits = original["hits"] as? [Any], hits.isEmpty
            else { throw SaveError.invalidCommander }
          }
          let decoded = try JSONDecoder().decode(
            NativeDefensiveFlightState.self, from: JSONSerialization.data(withJSONObject: object))
          guard decoded.valid,
            (object as NSDictionary).isEqual(
              try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)))
          else { throw SaveError.invalidCommander }
        }
      }
    }
    switch part {
    case .missions: try instances(root["instances"], embedded: false)
    case .commander:
      if let state = root["savedScriptState"] as? [String: Any] {
        try instances(state["instances"], embedded: true)
      }
    case .contracts: break
    }
  }
}
