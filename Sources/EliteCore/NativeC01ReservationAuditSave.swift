import Foundation

enum NativeC01ReservationAuditSave {
  static let version = 137
  static let alienVersion = 138
  static func contains(_ schema: Int?) -> Bool { schema == version || schema == alienVersion }
  static func lowerSchema(_ schema: Int?) -> Int? {
    guard contains(schema) else { return schema }
    return schema == alienVersion
      ? NativeC01SurveyorSave.alienVersion : NativeC01SurveyorSave.version
  }
  static func hasClaims(_ commander: borrowing Commander) -> Bool {
    commander.scriptState.instances.values.contains {
      $0.savedGlassMeridian?.reservationCase != nil
    }
  }
  static func validateFields(
    _ data: Data, part: ScriptFreightVersionedSave.Part, schema: Int?
  ) throws {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      !root.keys.contains("reservationCase"), !root.keys.contains("nativeC01ReservationAudit")
    else { throw SaveError.invalidCommander }
    func check(_ object: [String: Any], embedded: Bool) throws {
      let raw = object["instances"]
      let values: [Any]
      if let raw = raw as? [String: Any], raw.count <= 128 {
        values = Array(raw.values)
      } else if let raw = raw as? [Any], raw.count <= 256, raw.count.isMultiple(of: 2) {
        values = stride(from: 1, to: raw.count, by: 2).map { raw[$0] }
      } else if raw == nil {
        values = []
      } else {
        throw SaveError.invalidCommander
      }
      for value in values {
        guard let mission = value as? [String: Any], !mission.keys.contains("reservationCase"),
          !mission.keys.contains("nativeC01ReservationAudit")
        else { throw SaveError.invalidCommander }
        guard let glass = mission["savedGlassMeridian"] as? [String: Any],
          let rawCase = glass["reservationCase"]
        else { continue }
        guard contains(schema), !embedded,
          mission["definition"] as? String == NativeGlassMeridian.stateID,
          mission["digest"] as? String == NativeGlassMeridian.digest,
          NativeGlassMeridianSave.boundedFields(glass),
          let object = rawCase as? [String: Any],
          let source = object["source"] as? [String: Any]
        else { throw SaveError.invalidCommander }
        let sourceBytes = try JSONSerialization.data(withJSONObject: source)
        _ = try NativeC01ReservationSource.decodeClosed(sourceBytes)
        if let audit = object["audit"] as? [String: Any] {
          guard let pin = audit["pin"] as? [String: Any],
            let readings = pin["readings"] as? [Any], readings.count == 2,
            let contents = pin["clockContents"] as? [Any], contents.count == 2,
            let findings = audit["findings"] as? [String: Any],
            let claims = findings["claims"] as? [Any], claims.count == 2,
            let payments = findings["payments"] as? [Any], payments.count == 2
          else { throw SaveError.invalidCommander }
        }
        let bytes = try JSONSerialization.data(withJSONObject: glass)
        guard bytes.count <= 1_048_576 else { throw SaveError.invalidCommander }
        let decoded = try JSONDecoder().decode(NativeGlassMeridianState.self, from: bytes)
        guard decoded.reservationCase != nil, shapeValid(decoded),
          (glass as NSDictionary).isEqual(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)))
        else { throw SaveError.invalidCommander }
      }
    }
    if part == .missions { try check(root, embedded: false) }
    if part == .commander, let saved = root["savedScriptState"] as? [String: Any] {
      try check(saved, embedded: true)
    }
  }

  static func shapeValid(_ state: NativeGlassMeridianState) -> Bool {
    guard let value = state.reservationCase else { return true }
    let source = value.source
    let p = state.permission
    guard source.terms.valid, source.terms.mission == p.mission,
      source.terms.permission == p.operation, source.terms.owner == p.owner,
      source.terms.epoch == p.physicalTime,
      state.readings.allSatisfy({ $0.reading.start >= source.terms.epoch }),
      state.surveyor.map({ $0.source.physicalTime >= source.terms.epoch }) ?? true
    else { return false }
    guard let audit = value.audit else { return value.laterLoss == nil }
    guard let capture = state.surveyor?.capture,
      audit.operation == NativeC01ReservationAuditReceipt.operation(source: source.terms.source),
      audit.sequence > source.lastSequence, audit.sequence < UInt64(Int64.max),
      audit.physicalTime.isFinite, audit.physicalTime >= capture.physicalTime,
      audit.auditor == source.sorel, audit.ledgerOwner == source.portAuthority,
      audit.target == NativeC01ReservationAuditReceipt.target,
      audit.stage == NativeC01ReservationAuditReceipt.stage,
      audit.event == NativeC01ReservationAuditReceipt.event,
      audit.findings
        == (try? NativeC01ReservationComparison.compare(
          source: source, clocks: source.clocks, recorder: source.recorder))
    else { return false }
    let pin = audit.pin
    let readings = state.readings.sorted { $0.reading.ordinal < $1.reading.ordinal }.map {
      $0.reading.operation
    }
    guard pin.mission == p.mission, pin.owner == p.owner, pin.source == source.terms.source,
      pin.sourceRevision == source.revision, pin.sourceFingerprint == source.fingerprint,
      pin.recorderContents == source.recorderFingerprint,
      pin.captureOperation == capture.operation,
      pin.recorderActor == capture.marker.body.physical?.identity,
      pin.readings == readings,
      pin.readings.count == 2, Set(pin.readings).count == 2,
      pin.clockContents == source.clockFingerprints,
      pin.dock.valid, pin.dock.commanderOwner == p.owner,
      pin.dock.station.system == .init(galaxy: 0, system: 0),
      pin.inventoryRevision < UInt64(Int64.max), pin.missionRevision < UInt64(Int64.max) - 1
    else { return false }
    if let loss = state.surveyor?.loss {
      guard let observation = value.laterLoss, observation.loss == loss,
        observation.audit == audit.operation, observation.sequence > audit.sequence,
        observation.sequence < UInt64(Int64.max), loss.physicalTime >= audit.physicalTime
      else { return false }
    } else if value.laterLoss != nil {
      return false
    }
    return true
  }

  static func sourceValid(_ mission: ScriptInstance, commander: borrowing Commander) -> Bool {
    guard let state = mission.savedGlassMeridian, shapeValid(state),
      let value = state.reservationCase,
      mission.definition == NativeGlassMeridian.stateID,
      mission.digest == NativeGlassMeridian.digest,
      mission.version == NativeGlassMeridian.version,
      value.source.terms.owner == commander.equipmentOwnerID,
      value.source.terms.mission == mission.id,
      value.source.terms.epoch <= commander.flightSimulation.physicalTime,
      value.source.lastSequence <= commander.scriptState.nextEvent,
      value.source.events.allSatisfy({ mission.hasAcknowledged($0.sequence) })
    else { return false }
    return true
  }

  static func valid(_ mission: ScriptInstance, commander: borrowing Commander) -> Bool {
    guard let state = mission.savedGlassMeridian else { return true }
    guard let value = state.reservationCase else { return true }
    guard sourceValid(mission, commander: commander) else { return false }
    guard let audit = value.audit else { return true }
    guard audit.sequence <= commander.scriptState.nextEvent,
      mission.hasAcknowledged(audit.sequence),
      audit.pin.missionRevision < mission.revision,
      audit.physicalTime <= commander.flightSimulation.physicalTime,
      audit.pin.dock.actor.visit <= commander.flightSimulation.visit,
      let world = commander.nativeStations,
      world.mainStations.contains(audit.pin.dock.station),
      audit.pin.dock.sequence < world.nextMainDockSequence,
      mission.receipts.contains(audit.target),
      mission.receipts.contains(NativeC01ReservationAuditReceipt.localStage)
    else { return false }
    if let loss = value.laterLoss {
      guard loss.sequence <= commander.scriptState.nextEvent,
        mission.hasAcknowledged(loss.sequence),
        loss.loss.physicalTime <= commander.flightSimulation.physicalTime
      else { return false }
    }
    return true
  }
}
