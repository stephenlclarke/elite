import Foundation
import Testing

@testable import EliteCore

extension GameRuntime {
  func beginScriptRefusalObservation() { scriptRefusalDiagnostic = ScriptRefusalDiagnostic() }
  func scriptRefusalObservationDetail() -> String? { scriptRefusalDiagnostic?.detail() }
}

private func refusalChecks(_ detail: String) -> UInt16? {
  guard let value = detail.components(separatedBy: ",checks=").last?.split(separator: ",").first
  else {
    return nil
  }
  return UInt16(value)
}

@Test func scriptRefusalObservationIsBoundedFirstOnlyAndDoesNotRenderErrorData() throws {
  let diagnostics = ScriptRefusalDiagnostic()
  let game = Game(executive: false)
  let secret = "private-path-and-error-description"
  let error = NSError(
    domain: NSCocoaErrorDomain, code: 260,
    userInfo: [NSLocalizedDescriptionKey: secret, NSFilePathErrorKey: secret])
  diagnostics.record(.publication, .init(stage: .storeWrite, error: error, game: game))
  for _ in 0..<64 {
    diagnostics.record(
      .publication, .init(stage: .commandPublish, error: SaveError.invalidCommander, game: game))
  }
  diagnostics.record(
    .resolver,
    .init(stage: .freightPublish, error: NSError(domain: secret, code: 42), game: game))
  let detail = try #require(diagnostics.detail())
  #expect(detail.contains("publication=storeWrite,error=cocoa:260"))
  #expect(detail.contains("resolver=freightPublish,error=other"))
  #expect(!detail.contains(secret) && !detail.contains("commandPublish"))
  #expect(detail.utf8.count < 2048 && detail.utf8.allSatisfy { (32...126).contains($0) })
}

@Test func scriptRefusalObservationPreservesNativeAndStoreValidationRefusals() throws {
  var game = Game(executive: false)
  game.screen = .status
  game.ensureScriptCalendar(origin: .newCommander)
  try game.commander.prepareEquipment()
  let initiallyValid =
    game.commander.valid && game.scriptWorldSave.valid
    && ScriptFreightVersionedSave.validateClaims(game.commander)
    && (game.commander.usesFreightNativeSaveVersion
      || !game.commander.usesProviderContractSaveVersion)
    && game.scriptWorldSave.consistent(with: game.commander)
  try #require(initiallyValid)
  var invalid = game
  invalid.commander.cargo = []
  let before = invalid.commander
  let native = ScriptRefusalDiagnostic()
  var nativeRefused = false
  do {
    _ = try GameRuntime.prepareNativeSaveState(invalid, diagnostics: native)
  } catch {
    nativeRefused = error is SaveError
  }
  #expect(nativeRefused && invalid.commander == before)
  let nativeDetail = try #require(native.detail())
  #expect(nativeDetail.contains("publication=nativeSaveValidation,error=save.invalidCommander"))
  let nativeChecks = try #require(refusalChecks(nativeDetail))
  #expect(nativeChecks & 4 == 0 && nativeDetail.contains("count=0"))
  var world = game.scriptWorldSave
  world.energy = -1
  let store = ScriptRefusalDiagnostic()
  let target = FileManager.default.temporaryDirectory
    .appendingPathComponent("refusal-" + UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: target.appendingPathExtension("missions")) }
  defer { try? FileManager.default.removeItem(at: target) }
  var storeRefused = false
  do {
    _ = try ScriptSaveStore.write(
      commander: game.commander, world: world, to: target, diagnostics: store)
  } catch {
    storeRefused = error is SaveError
  }
  #expect(storeRefused)
  let storeDetail = try #require(store.detail())
  #expect(storeDetail.contains("publication=storeValidation,error=save.invalidCommander"))
  let storeChecks = try #require(refusalChecks(storeDetail))
  #expect(storeChecks & 1 == 1 && storeChecks & 2 == 0 && storeChecks & 96 == 96)
  let pointerExists = FileManager.default.fileExists(atPath: target.path)
  #expect(!pointerExists)
}
