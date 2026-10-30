import Foundation
import os

/// Observation only. Never encoded, consulted by admission, or used to replace an Error.
enum ScriptRefusalBoundary: String, Sendable, Hashable { case resolver, publication }
enum ScriptRefusalStage: String, Sendable {
  case freightGuard, freightFinish, completionEnqueue, freightCommander, freightPublish
  case commandFlush, commandPublish, nativePeople, nativeDock, nativeStations, equipment
  case nativeDestruction, salvagePoses, nativeSaveValidation, storeValidation, storeSize, storeWrite
  case sceneSalvage, sceneEMP, sceneEMPUnowned, sceneStations, sceneStationUnowned
  case sceneCapacity, sceneLibrary, sceneCourierFatal, sceneFreightFatal, sceneMainDestroyed
  case sceneMainEnergy, sceneActorDuplicate, sceneShotPopulation, sceneShotBinding,
    sceneShotCanonical
  case scenePendingJourney, sceneUnadmittedJump, sceneLegacyJourney, sceneActorPopulation,
    sceneActorBinding
}

struct ScriptRefusalObservation: Sendable {
  let stage: ScriptRefusalStage
  let error: String
  let system: Int
  let visit: UInt64
  let revision: UInt64?
  let physicalTime: Double
  let checks: UInt16?
  let count: Int?

  init(
    stage: ScriptRefusalStage, error: any Error, game: Game,
    checks: UInt16? = nil, count: Int? = nil
  ) {
    self.init(
      stage: stage, error: error, commander: game.commander, revision: game.gameplayRevision,
      checks: checks, count: count)
  }

  init(
    stage: ScriptRefusalStage, error: any Error, commander: Commander,
    revision: UInt64? = nil, checks: UInt16? = nil, count: Int? = nil
  ) {
    self.stage = stage
    self.error = Self.errorToken(error)
    system = commander.system
    visit = commander.flightSimulation.visit
    self.revision = revision
    physicalTime = commander.flightSimulation.physicalTime
    self.checks = checks
    self.count = count
  }

  private static func errorToken(_ error: any Error) -> String {
    if error is SaveError { return "save.invalidCommander" }
    if let error = error as? NativeStationRuntimeError {
      switch error {
      case .invalidSource: return "station.invalidSource"
      case .invalidState: return "station.invalidState"
      case .unavailable: return "station.unavailable"
      case .unsafePlacement: return "station.unsafePlacement"
      case .capacity: return "station.capacity"
      case .unsafeEntry: return "station.unsafeEntry"
      case .unsafeExit: return "station.unsafeExit"
      }
    }
    if error is MissionPackError { return "missionPack" }
    if error is EncodingError { return "encoding" }
    let native = error as NSError
    if native.domain == NSPOSIXErrorDomain { return "posix:\(native.code)" }
    if native.domain == NSCocoaErrorDomain { return "cocoa:\(native.code)" }
    return "other"
  }

  /// True prefix of the original store guard; stop before any predicate it could not reach.
  static func storeChecks(_ commander: Commander, world: ScriptWorldSave, scope: String) -> UInt16 {
    var checks: UInt16 = 0
    guard ["commander", "gallery"].contains(scope) else { return checks }
    checks |= 32
    guard commander.scriptState.calendarLedger != nil else { return checks }
    checks |= 64
    guard commander.valid else { return checks }
    checks |= 1
    guard world.valid else { return checks }
    checks |= 2
    guard ScriptFreightVersionedSave.validateClaims(commander) else { return checks }
    checks |= 4
    guard commander.usesFreightNativeSaveVersion || !commander.usesProviderContractSaveVersion
    else {
      return checks
    }
    checks |= 8
    guard world.consistent(with: commander) else { return checks }
    return checks | 16
  }
}

/// One runtime-owned slot with at most two first refusals, never a history or callback.
/// The lock only lets its captured Sendable publisher record into the same bounded slot.
final class ScriptRefusalDiagnostic: Sendable {
  private let state = OSAllocatedUnfairLock(
    initialState: [ScriptRefusalBoundary: ScriptRefusalObservation]())

  func contains(_ boundary: ScriptRefusalBoundary) -> Bool {
    state.withLock { $0[boundary] != nil }
  }

  func record(_ boundary: ScriptRefusalBoundary, _ observation: ScriptRefusalObservation) {
    state.withLock { if $0[boundary] == nil { $0[boundary] = observation } }
  }

  /// The writer maps this existing false predicate to its unchanged invalidCommander refusal.
  func recordSceneFailure(
    _ stage: ScriptRefusalStage, commander: Commander, boundary: ScriptRefusalBoundary
  ) {
    guard !contains(boundary) else { return }
    record(boundary, .init(stage: stage, error: SaveError.invalidCommander, commander: commander))
  }

  func detail() -> String? {
    let records = state.withLock { $0 }
    guard !records.isEmpty else { return nil }
    let pieces: [String] = records.keys.sorted { $0.rawValue < $1.rawValue }.map { key in
      guard let value = records[key] else { return "" }
      return "\(key.rawValue)=\(value.stage.rawValue),error=\(value.error)"
        + ",system=\(value.system),visit=\(value.visit)"
        + ",revision=\(value.revision.map { String($0) } ?? "nil")"
        + ",time=\(value.physicalTime),checks=\(value.checks.map { String($0) } ?? "nil")"
        + ",count=\(value.count.map { String($0) } ?? "nil")"
    }
    let text = "SCRIPT_REFUSAL " + pieces.joined(separator: ";")
    // Fixed tokens and numeric scalars only; includes one eventual presentation newline.
    guard text.utf8.count < 2048, text.utf8.allSatisfy({ (32...126).contains($0) }) else {
      return "SCRIPT_REFUSAL refused=bound"
    }
    return text
  }
}
