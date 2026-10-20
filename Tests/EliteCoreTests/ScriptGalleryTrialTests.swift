import Foundation
import Testing

@testable import EliteCore

private var galleryExamples: URL {
  URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().appendingPathComponent("docs/mission-packs")
}
private func galleryFolder() throws -> URL {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(
    "gallery-flow-" + UUID().uuidString)
  try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  return url
}
private func galleryPack(_ name: String) throws -> ScriptPack {
  try ScriptPackLibrary.read(galleryExamples.appendingPathComponent(name))
}
private func sortedWorld(_ game: Game) throws -> Data {
  let encoder = JSONEncoder()
  encoder.outputFormatting = .sortedKeys
  return try encoder.encode(game.scriptWorldSave)
}
@Test func galleryTrialPreservesCompleteLiveWorldAndRestoresItsWriter() async throws {
  let directory = try galleryFolder()
  defer { try? FileManager.default.removeItem(at: directory) }
  let courier = try galleryPack("scripted-courier")
  let passengers = try galleryPack("scripted-passengers")
  var game = Game(executive: false)
  game.screen = .status
  game.commander.name = "LIVE"
  game.commander.credits = 32100
  game.commander.cargo[0] = 5
  game.scriptPacks = [courier, passengers]
  _ = try game.acceptScriptMission(courier)
  game.launch()
  game.speed = 4
  game.energy = 199
  game.cabinTemperature = 0.25
  game.openGallery()
  let url = directory.appendingPathComponent("live.json")
  let runtime = GameRuntime(game: game, saveURL: url)
  try await runtime.save(to: url)
  let before = await runtime.snapshot()
  let bytes = try Data(contentsOf: url)
  try await runtime.startScriptGalleryTrial(packDigest: passengers.digest, seed: 42)
  let namespace = try #require(await runtime.gallerySaveDirectory())
  defer { try? FileManager.default.removeItem(at: namespace) }
  let trial = await runtime.snapshot()
  #expect(
    trial.isMissionTrial && trial.commander.name == NewCommanderDefaults.name
      && trial.commander.credits == 90000)
  #expect(
    trial.commander.accommodation.people.count == 1
      && trial.commander.accommodation.fitted.count == 1)
  #expect(trial.commander.scriptState.instances.values.first?.randomState == 42)
  await #expect(throws: MissionPackError.self) {
    try await runtime.startScriptGalleryTrial(packDigest: passengers.digest)
  }
  _ = await runtime.advance(delta: 0.1)
  let receipt = try await runtime.saveForInterface()
  #expect(receipt.isTrial && receipt.url.path.hasPrefix(namespace.path + "/"))
  _ = try await runtime.loadForInterface()
  #expect(await runtime.snapshot().isMissionTrial)
  #expect(try Data(contentsOf: url) == bytes)
  try await runtime.returnFromScriptGalleryTrial()
  let restored = await runtime.snapshot()
  #expect(!restored.isMissionTrial && restored.commander == before.commander)
  #expect(try sortedWorld(restored) == sortedWorld(before))
  #expect(await runtime.gallerySaveDirectory() == nil)
  let liveReceipt = try await runtime.saveForInterface()
  #expect(!liveReceipt.isTrial && liveReceipt.url == url)
}
@Test func galleryKeyboardLaunchAndReturnAndHintsUseTheSelectedDigest() async throws {
  let pack = try galleryPack("scripted-passengers")
  var game = Game(executive: false)
  game.screen = .status
  game.scriptPacks = [pack]
  let runtime = GameRuntime(game: game)
  await runtime.key("gallery-open")
  await runtime.key("t")
  #expect(await runtime.gallerySaveDirectory() == nil)
  for _ in 0..<3 { await runtime.key("down") }
  let selected = await runtime.snapshot()
  #expect(
    selected.canTrialSelectedMission && selected.selectedGalleryMission?.trialDigest == pack.digest)
  for width in [512.0, 768, 1200] {
    let frame = Display.gallery(selected, width: width, height: 768)
    #expect(frame.labels.contains { $0.text.contains("T: trial") })
    #expect(frame.labels.allSatisfy { $0.x.isFinite && $0.y.isFinite })
  }
  await runtime.key("gallery-trial")
  let namespace = try #require(await runtime.gallerySaveDirectory())
  defer { try? FileManager.default.removeItem(at: namespace) }
  #expect(await runtime.snapshot().isMissionTrial)
  await runtime.key("trial-return")
  let restored = await runtime.snapshot()
  #expect(restored.screen == .gallery && !restored.isMissionTrial)
  await #expect(throws: MissionPackError.self) { try await runtime.returnFromScriptGalleryTrial() }
}
@Test func trialManifestCannotInjectProgressAndRejectsImpossibleLoadouts() throws {
  let folder = try galleryFolder()
  defer { try? FileManager.default.removeItem(at: folder) }
  let pack = folder.appendingPathComponent("pack")
  try FileManager.default.copyItem(
    at: galleryExamples.appendingPathComponent("scripted-passengers"), to: pack)
  let file = pack.appendingPathComponent("manifest.toml")
  let original = try String(contentsOf: file, encoding: .utf8)
  for (old, new) in [
    ("cabins = 1", "cabins = 129"), ("credits = 100000", "credits = 0"),
    ("ship = \"SH023\"", "ship = \"SH141\""), ("system = 7", "system = 256"),
    ("flight = false", "flight = false\nmission_complete = true"),
    (", \"gallery-basic-v2\"", ""),
  ] {
    try original.replacingOccurrences(of: old, with: new).write(
      to: file, atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { try ScriptPackLibrary.read(pack) }
  }
}
@Test func staleParentControlsCannotFireAWeaponInTheTrial() async throws {
  let folder = try galleryFolder()
  defer { try? FileManager.default.removeItem(at: folder) }
  let path = folder.appendingPathComponent("pack")
  try FileManager.default.copyItem(
    at: galleryExamples.appendingPathComponent("scripted-patrol"), to: path)
  let manifest = path.appendingPathComponent("manifest.toml")
  var text = try String(contentsOf: manifest, encoding: .utf8)
  text = text.replacingOccurrences(
    of: "\"classic-encounters-v2\"]", with: "\"classic-encounters-v2\", \"gallery-basic-v2\"]")
  text += "\n[trial]\nship='SH023'\ngalaxy=0\nsystem=7\ncredits=1000\ncabins=0\nflight=true\n"
  try text.write(to: manifest, atomically: true, encoding: .utf8)
  let pack = try ScriptPackLibrary.read(path)
  var game = Game(executive: false)
  game.screen = .status
  game.scriptPacks = [pack]
  game.openGallery()
  let runtime = GameRuntime(game: game)
  let parentEpoch = await runtime.snapshot().ecmControl.epoch
  try await runtime.startScriptGalleryTrial(packDigest: pack.digest)
  let namespace = try #require(await runtime.gallerySaveDirectory())
  defer { try? FileManager.default.removeItem(at: namespace) }
  let trial = await runtime.snapshot()
  #expect(!trial.docked && trial.bodies.filter { $0.missionActorID != nil }.count == 2)
  var firing = Controls()
  firing.fire = true
  await runtime.setControls(firing, expectedEpoch: parentEpoch)
  let rejected = await runtime.advance(delta: 0.1)
  #expect(rejected.laserFlash == 0)
  #expect(rejected.dischargeAudio.events == trial.dischargeAudio.events)
  let pausedAfterRejectedControl = rejected.paused
  let rejectedMessage = rejected.message
  #expect(!pausedAfterRejectedControl, Comment(rawValue: rejectedMessage))
  #expect(rejected.screen == .front && !rejected.docked)
  #expect(rejected.commander.laser(on: .front) == .pulse)
  #expect(rejected.commander.flightSimulation.valid)
  #expect(rejected.ecmControl.epoch == trial.ecmControl.epoch)
  #expect(throws: Never.self) {
    _ = try rejected.nearestMissionCollision(
      from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 6000,
      radius: 0, includePlayer: false)
  }
  // These actual restoration probes operate only on a local snapshot, never on the runtime.
  #expect(throws: Never.self) { try rejected.validateRetainedMissionProjectileRestoration() }
  let firstPolice = try #require(
    rejected.bodies.first { $0.physical?.spawnIdentity?.producer == .security })
  #expect(firstPolice.hull == .viper && firstPolice.physical?.npc?.role == .police)
  #expect(firstPolice.physical?.spawnIdentity?.sequence == 0)
  #expect(firstPolice.physical?.spawnIdentity?.system == rejected.systemIdentity)
  #expect(firstPolice.physical?.spawnIdentity?.visit == rejected.commander.flightSimulation.visit)
  for body in rejected.bodies where body.energy > 0 && body.missionInstanceID != nil {
    let bodyID = body.id
    #expect(throws: Never.self, Comment(rawValue: "Native binding for mission body \(bodyID)")) {
      _ = try rejected.currentMissionNativeBinding(bodyID: bodyID)
    }
  }
  var restoreProbe = rejected
  #expect(throws: Never.self) { try restoreProbe.restoreScriptActors() }
  await runtime.setControls(firing, expectedEpoch: trial.ecmControl.epoch)
  let fired = await runtime.advance(delta: 0.1)
  let flashAfterCurrentControl = fired.laserFlash
  let firedMessage = fired.message
  let dischargeCountBefore = rejected.dischargeAudio.events.count
  let dischargeCountAfter = fired.dischargeAudio.events.count
  #expect(flashAfterCurrentControl > 0, Comment(rawValue: firedMessage))
  #expect(dischargeCountAfter > dischargeCountBefore)
}
@Test func returningToAnEarlierSpeechNamespaceCannotReplayItsOldMessages() {
  var live = Game(executive: false)
  live.screen = .status
  live.commander.speech = true
  live.notify("LIVE MESSAGE")
  var feed = SpeechFeed()
  #expect(feed.update(live, busy: false) == "LIVE MESSAGE")
  for index in 0..<70 {
    var trial = Game(executive: false)
    trial.screen = .status
    trial.commander.speech = true
    trial.notify("TRIAL \(index)")
    #expect(feed.update(trial, busy: false) == "TRIAL \(index)")
    #expect(feed.update(live, busy: false) == nil)
  }
  live.notify("NEW LIVE MESSAGE")
  #expect(feed.update(live, busy: false) == "NEW LIVE MESSAGE")
}

@Test func taggedTrialSavesCannotReplaceTheLiveGameOrImportLiveDataIntoATrial() async throws {
  let folder = try galleryFolder()
  defer { try? FileManager.default.removeItem(at: folder) }
  let courier = try galleryPack("scripted-courier")
  var game = Game(executive: false)
  game.screen = .status
  game.scriptPacks = [courier]
  _ = try game.acceptScriptMission(courier)
  game.openGallery()
  let mainFile = folder.appendingPathComponent("live.json")
  let runtime = GameRuntime(game: game, saveURL: mainFile)
  try await runtime.save(to: mainFile)
  let live = await runtime.snapshot().commander
  let liveBytes = try Data(contentsOf: mainFile)
  try await runtime.startScriptGalleryTrial(packDigest: courier.digest)
  let trialNamespace = await runtime.gallerySaveDirectory()
  let namespace = try #require(trialNamespace)
  defer { try? FileManager.default.removeItem(at: namespace) }
  let saved = try await runtime.saveForInterface()
  let trialBytes = try Data(contentsOf: saved.url)
  let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: trialBytes)
  let (stored, _) = try ScriptSaveStore.read(trialBytes, from: saved.url)
  let savedTrial = await runtime.snapshot().commander
  #expect(stored == savedTrial)
  #expect(pointer.scope == "gallery" && pointer.schemaVersion == 26)
  let trial = await runtime.snapshot()
  let clone = GameRuntime(game: trial, saveURL: mainFile)
  let cloneDirectory = await clone.gallerySaveDirectory()
  let cloneNamespace = try #require(cloneDirectory)
  defer { try? FileManager.default.removeItem(at: cloneNamespace) }
  await #expect(throws: MissionPackError.self) { try await clone.save(to: mainFile) }
  let copied = namespace.appendingPathComponent("copied-live.json")
  try FileManager.default.copyItem(at: mainFile, to: copied)
  try FileManager.default.copyItem(
    at: mainFile.appendingPathExtension("missions"), to: copied.appendingPathExtension("missions"))
  await #expect(throws: MissionPackError.self) { try await runtime.loadForInterface(from: copied) }
  try await runtime.returnFromScriptGalleryTrial()
  await #expect(throws: MissionPackError.self) {
    try await runtime.loadForInterface(from: saved.url)
  }
  let returned = await runtime.snapshot()
  let returnedLiveBytes = try Data(contentsOf: mainFile)
  #expect(returned.commander == live && returnedLiveBytes == liveBytes)
}
@Test func aSavedFaultStaysSuspendedAfterReloadUntilExplicitGalleryRetry() async throws {
  let folder = try galleryFolder()
  defer { try? FileManager.default.removeItem(at: folder) }
  let directory = folder.appendingPathComponent("pack")
  try FileManager.default.copyItem(
    at: galleryExamples.appendingPathComponent("scripted-courier"), to: directory)
  let module = directory.appendingPathComponent("scripts/main.lua")
  var source = try String(contentsOf: module, encoding: .utf8)
  try #require(source.components(separatedBy: "  local commands = {}\n  if data.phase").count == 3)
  source = source.replacingOccurrences(
    of: "  local commands = {}\n  if data.phase",
    with:
      "  if world.free_tonnes < 1 then error('Make room before retrying') end\n  local commands = {}\n  if data.phase"
  )
  try source.write(to: module, atomically: true, encoding: .utf8)
  let pack = try ScriptPackLibrary.read(directory)
  var game = Game(executive: false)
  game.screen = .status
  game.scriptPacks = [pack]
  let id = try game.acceptScriptMission(pack)
  game.commander.system = 129
  let accepted = try #require(game.commander.scriptState.instances[id])
  try #require(accepted.payloads == ["supplies": 1] && accepted.digest == pack.digest)
  let capacity = game.commander.tradeCargoCapacity
  let reserved = game.commander.cargoTonnes
  try #require(!game.commander.unlimitedCargo && capacity == game.commander.standardCargoCapacity)
  try #require(capacity > reserved && reserved == 1 && game.commander.cargo.allSatisfy { $0 == 0 })
  try #require(Commodity.all[0].name == "Food" && Commodity.all[0].unit == "t")
  let food = capacity - reserved
  game.commander.cargo[0] = food
  #expect(game.commander.cargoTonnes == capacity)
  #expect(game.scriptSnapshot.object?["free_tonnes"] == .integer(0))
  let file = folder.appendingPathComponent("live.json")
  let runtime = GameRuntime(game: game, saveURL: file)
  let beforeContact = await runtime.snapshot()
  try #require(beforeContact.commander.tradeCargoCapacity == capacity)
  try #require(beforeContact.commander.cargoTonnes == capacity)
  #expect(beforeContact.scriptSnapshot.object?["free_tonnes"] == .integer(0))
  #expect(beforeContact.commander.scriptState.instances[id]?.payloads == accepted.payloads)
  await runtime.key("contacts-open")
  let fault = await runtime.snapshot()
  #expect(fault.commander.scriptState.instances[id]?.suspension?.contains("Make room") == true)
  let pendingContact = try #require(
    fault.commander.scriptState.pendingEvents.first {
      $0.instance == id && $0.kind == "contact.requested"
    })
  let suspended = try #require(fault.commander.scriptState.instances[id])
  #expect(!suspended.hasAcknowledged(pendingContact.sequence))
  #expect(fault.commander.cargoTonnes == capacity && fault.commander.cargo[0] == food)
  #expect(fault.commander.scriptState.instances[id]?.payloads == accepted.payloads)
  let liveNamespace = await runtime.gallerySaveDirectory()
  #expect(!fault.isMissionTrial && liveNamespace == nil)
  let faultBytes = try Data(contentsOf: file)
  let faultPointer = try JSONDecoder().decode(ScriptSavePointer.self, from: faultBytes)
  #expect(faultPointer.schemaVersion == 26 && faultPointer.scope == "commander")
  #expect(faultPointer.valueCodec == ScriptValueStorage.codec)
  let (faultStored, faultWorld) = try ScriptSaveStore.read(faultBytes, from: file)
  #expect(
    faultStored == fault.commander && faultWorld.valid && faultWorld.consistent(with: faultStored))
  let loaded = GameRuntime(game: game)
  try await loaded.load(from: file)
  _ = await loaded.advance(delta: 0.1)
  let reloaded = await loaded.snapshot()
  #expect(reloaded.commander.scriptState.instances[id]?.suspension != nil)
  #expect(reloaded.commander.scriptState.instances[id] == fault.commander.scriptState.instances[id])
  #expect(
    reloaded.commander.scriptState.pendingEvents
      == fault.commander.scriptState.pendingEvents)
  let loadedNamespace = await loaded.gallerySaveDirectory()
  #expect(!reloaded.isMissionTrial && loadedNamespace == nil)
  #expect(reloaded.commander.cargoTonnes == capacity)
  await loaded.key("screen:7")
  let market = await loaded.snapshot()
  try #require(market.screen == .buy && market.selection == 0)
  let layout = MarketLayout(
    game: market, width: market.viewportWidth, height: market.viewportHeight)
  await loaded.marketClick(x: layout.sell.x + 1, y: layout.sell.y + 1)
  let selling = await loaded.snapshot()
  try #require(selling.screen == .sell)
  await loaded.marketClick(x: layout.trade.x + 1, y: layout.trade.y + 1)
  let sold = await loaded.snapshot()
  #expect(sold.commander.cargo[0] == food - 1)
  #expect(sold.commander.credits == market.commander.credits + market.market[0].bidPrice)
  #expect(sold.market[0].quantity == market.market[0].quantity + 1)
  #expect(sold.commander.scriptState.payloadTonnes == market.commander.scriptState.payloadTonnes)
  #expect(sold.commander.scriptState.instances[id] == market.commander.scriptState.instances[id])
  #expect(sold.commander.cargoTonnes == capacity - 1)
  #expect(sold.commander.tradeCargoCapacity == capacity)
  #expect(sold.scriptSnapshot.object?["free_tonnes"] == .integer(1))
  #expect(sold.commander.scriptState.pendingEvents == fault.commander.scriptState.pendingEvents)
  #expect(sold.commander.scriptState.instances[id] == reloaded.commander.scriptState.instances[id])
  await loaded.key("gallery-open")
  let opened = await loaded.snapshot()
  try #require(opened.screen == .gallery && !opened.gallery.detail)
  let matches = opened.missionCatalogue.indices.filter {
    opened.missionCatalogue[$0].savedInstance == id
  }
  try #require(matches.count == 1)
  let selected = try #require(matches.first)
  try #require(opened.gallery.selection <= selected)
  for _ in opened.gallery.selection..<selected { await loaded.key("down") }
  let ready = await loaded.snapshot()
  #expect(ready.selectedGalleryMission?.savedInstance == id)
  #expect(ready.selectedGalleryMission?.trialDigest == pack.digest)
  #expect(ready.canRetrySelectedMission)
  #expect(ready.commander.scriptState.instances[id] == sold.commander.scriptState.instances[id])
  #expect(ready.commander.scriptState.pendingEvents == fault.commander.scriptState.pendingEvents)
  await loaded.key("r")
  let resumed = await loaded.snapshot()
  #expect(resumed.commander.scriptState.instances[id]?.suspension == nil)
  #expect(resumed.commander.scriptState.instances[id]?.dialogue?.id == "delivery")
  let resumedInstance = try #require(resumed.commander.scriptState.instances[id])
  #expect(resumedInstance.id == id && resumedInstance.digest == pack.digest)
  #expect(resumedInstance.payloads == accepted.payloads)
  #expect(resumedInstance.hasAcknowledged(pendingContact.sequence))
  #expect(
    !resumed.commander.scriptState.pendingEvents.contains { $0.sequence == pendingContact.sequence }
  )
  #expect(
    resumed.commander.cargo[0] == food - 1 && resumed.commander.credits == sold.commander.credits)
  #expect(resumed.commander.cargoTonnes == capacity - 1 && !resumed.isMissionTrial)
  let savedBytes = try Data(contentsOf: file)
  let savedPointer = try JSONDecoder().decode(ScriptSavePointer.self, from: savedBytes)
  #expect(savedPointer.schemaVersion == 26 && savedPointer.scope == "commander")
  #expect(savedPointer.valueCodec == ScriptValueStorage.codec)
  let (saved, savedWorld) = try ScriptSaveStore.read(savedBytes, from: file)
  #expect(saved == resumed.commander && savedWorld.valid && savedWorld.consistent(with: saved))
  #expect(saved.scriptState.instances[id]?.suspension == nil)
  #expect(
    saved.credits == resumed.commander.credits
      && saved.scriptState.instances[id]?.outcome == .active)
}
@Test func standaloneTrialsAndUnsupportedEntriesCannotReplaceTheLiveNamespace() async throws {
  let folder = try galleryFolder()
  defer { try? FileManager.default.removeItem(at: folder) }
  let directory = folder.appendingPathComponent("pack")
  try FileManager.default.copyItem(
    at: galleryExamples.appendingPathComponent("scripted-courier"), to: directory)
  let manifest = directory.appendingPathComponent("manifest.toml")
  let original = try String(contentsOf: manifest, encoding: .utf8)
  try original.replacingOccurrences(of: "\"cargo-v2\"]", with: "\"cargo-v2\", \"world-actors-v1\"]")
    .write(to: manifest, atomically: true, encoding: .utf8)
  let unsupported = try ScriptPackLibrary.read(directory)
  var game = Game(executive: false)
  game.screen = .status
  game.scriptPacks = [unsupported]
  game.openGallery()
  let runtime = GameRuntime(game: game)
  let before = await runtime.snapshot().commander
  await #expect(throws: MissionPackError.self) {
    try await runtime.startScriptGalleryTrial(packDigest: unsupported.digest)
  }
  #expect(await runtime.gallerySaveDirectory() == nil)
  #expect(await runtime.snapshot().commander == before)
  let pack = try galleryPack("scripted-courier")
  game.scriptPacks = [pack]
  let live = GameRuntime(game: game)
  let standalone = try await live.scriptGalleryTrial(packDigest: pack.digest)
  let namespace = try #require(await standalone.gallerySaveDirectory())
  defer { try? FileManager.default.removeItem(at: namespace) }
  await #expect(throws: MissionPackError.self) {
    try await standalone.returnFromScriptGalleryTrial()
  }
}

@Test func restartingTrialRestoresItsInitialSeedLoadoutAndKeepsTheParent() async throws {
  let pack = try galleryPack("scripted-passengers")
  var game = Game(executive: false)
  game.screen = .status
  game.commander.name = "PARENT"
  game.scriptPacks = [pack]
  game.openGallery()
  let runtime = GameRuntime(game: game)
  try await runtime.startScriptGalleryTrial(packDigest: pack.digest, seed: 99)
  let namespace = try #require(await runtime.gallerySaveDirectory())
  defer { try? FileManager.default.removeItem(at: namespace) }
  let old = await runtime.snapshot().commander.scriptState.instances.keys.first
  _ = await runtime.advance(delta: 0.1)
  await runtime.key("trial-restart")
  let restarted = await runtime.snapshot()
  #expect(restarted.isMissionTrial && restarted.commander.credits == 90000)
  #expect(restarted.commander.scriptState.instances.values.first?.randomState == 99)
  #expect(restarted.commander.scriptState.instances.keys.first != old)
  #expect(restarted.commander.accommodation.people.count == 1)
  await runtime.key("trial-return")
  #expect(await runtime.snapshot().commander.name == "PARENT")
}

@Test func fileDialogResultsFromAnotherPresentationCannotSaveOrLoadTheCurrentCommander()
  async throws
{
  let folder = try galleryFolder()
  defer { try? FileManager.default.removeItem(at: folder) }
  let pack = try galleryPack("scripted-courier")
  var game = Game(executive: false)
  game.screen = .status
  game.scriptPacks = [pack]
  game.openGallery()
  let runtime = GameRuntime(game: game)
  let parentEpoch = await runtime.snapshot().ecmControl.epoch
  try await runtime.startScriptGalleryTrial(packDigest: pack.digest)
  let namespace = try #require(await runtime.gallerySaveDirectory())
  defer { try? FileManager.default.removeItem(at: namespace) }
  let target = namespace.appendingPathComponent("late-dialog.json")
  let before = await runtime.snapshot().commander
  await #expect(throws: MissionPackError.self) {
    try await runtime.saveForInterface(to: target, expectedEpoch: parentEpoch)
  }
  #expect(!FileManager.default.fileExists(atPath: target.path))
  let own = try await runtime.saveForInterface()
  await #expect(throws: MissionPackError.self) {
    try await runtime.loadForInterface(from: own.url, expectedEpoch: parentEpoch)
  }
  #expect(await runtime.snapshot().commander == before)
}

@Test func trialLossRestartsTheAuthoredSceneInsteadOfCreatingANormalCommander() async throws {
  let pack = try galleryPack("scripted-passengers")
  var library = Game(executive: false)
  library.scriptPacks = [pack]
  var lost = try library.makeScriptTrial(packDigest: pack.digest, seed: 17)
  lost.screen = .gameOver
  lost.energy = 0
  let runtime = GameRuntime(game: lost)
  let namespace = try #require(await runtime.gallerySaveDirectory())
  defer { try? FileManager.default.removeItem(at: namespace) }
  await runtime.key(" ")
  let restarted = await runtime.snapshot()
  #expect(restarted.isMissionTrial && restarted.screen == .status)
  #expect(
    restarted.commander.credits == 90000 && restarted.commander.accommodation.people.count == 1)
  #expect(restarted.commander.scriptState.instances.values.first?.randomState == 17)
  #expect(restarted.energy > 0)
  let receipt = try await runtime.saveForInterface()
  #expect(receipt.isTrial)
}
