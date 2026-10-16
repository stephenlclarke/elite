import Foundation
import Testing

@testable import EliteCore

struct GearScriptFixture {
  let root: URL
  let pack: ScriptPack
  init(
    name: String = "E.C.M. System", quantity: Int = 1, loan: Bool = true,
    policy: String = "all", requiredReturn: Bool = true,
    accepted: String = "{op='gear.issue',id='issue',gear='kit',fit=true}",
    contact: String = "", confirm: String = "", observeReturn: Bool = false
  ) throws {
    let temporaryRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
      "script-gear-" + UUID().uuidString)
    root = temporaryRoot
    var ready = false
    defer { if !ready { try? FileManager.default.removeItem(at: temporaryRoot) } }
    let original = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(
        "docs/mission-packs/scripted-courier")
    let directory = root.appendingPathComponent("pack")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: original, to: directory)
    let manifest = directory.appendingPathComponent("manifest.toml")
    var text = try String(contentsOf: manifest, encoding: .utf8)
    text = text.replacingOccurrences(
      of: "\"cargo-v2\"]", with: "\"cargo-v2\", \"owned-equipment-v2\"]")
    if requiredReturn {
      text = text.replacingOccurrences(
        of: "milestones =", with: "requiredEquipmentReturns = [\"kit\"]\nmilestones =")
    }
    text +=
      "\n[[equipment]]\nid=\"kit\"\nname=\"\(name)\"\nquantity=\(quantity)\nloan=\(loan)\nreturnPolicy=\"\(policy)\"\n"
    if observeReturn {
      text += "\n[[handlers]]\nevent=\"equipment.returned\"\nfunction=\"returned\"\n"
    }
    try text.write(to: manifest, atomically: true, encoding: .utf8)
    let source = """
      return {
        accepted=function(e,w,d) return {data=d,commands={\(accepted)}} end,
        contact=function(e,w,d) return {data=d,commands={\(contact)}} end,
        confirm=function(e,w,d) return {data=d,commands={\(confirm)}} end,
        returned=function(e,w,d) d.actual_returns=#e.items; d.spent=e.consumed; return {data=d,commands={}} end
      }
      """
    try source.write(
      to: directory.appendingPathComponent("scripts/main.lua"), atomically: true, encoding: .utf8)
    pack = try ScriptPackLibrary.read(directory)
    ready = true
  }
  func game() throws -> Game {
    var game = Game(executive: false)
    game.screen = .status
    game.scriptPacks = [pack]
    _ = try game.acceptScriptMission(pack)
    return game
  }
  func clean() { try? FileManager.default.removeItem(at: root) }
}

@Test func authoredEquipmentExampleTravelsByNativeHyperspaceDocksAndReturnsTheOriginalUnit()
  async throws
{
  let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(
      "docs/mission-packs/scripted-equipment")
  let pack = try ScriptPackLibrary.read(directory)
  var game = Game(executive: false)
  game.screen = .status
  game.commander.installTargetingComputer(.docking)
  game.selectedSystem = 129
  game.scriptPacks = [pack]
  let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
    "loan-voyage-" + UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: folder) }
  let runtime = GameRuntime(game: game, saveURL: folder.appendingPathComponent("commander.json"))
  await runtime.key("contacts-open")
  await runtime.key("return")
  let id = try #require(await runtime.snapshot().commander.scriptState.instances.keys.first)
  let unit = try #require(
    await runtime.snapshot().commander.scriptState.instances[id]?.gearIssues["ecm-kit"]?.items.first
  )
  await runtime.key("0")
  var throttle = Controls()
  throttle.throttle = 1
  await runtime.setControls(throttle)
  var scene = await runtime.snapshot()
  for _ in 0..<200 where scene.massLocked { scene = await runtime.advance(delta: 0.1) }
  await runtime.setControls(Controls())
  await runtime.key("h")
  #expect(await runtime.snapshot().jumpCountdown != nil)
  for _ in 0..<200 {
    scene = await runtime.advance(delta: 0.1)
    if scene.commander.system == 129 { break }
  }
  #expect(scene.commander.system == 129 && scene.commander.fuel < 70)
  #expect(scene.commander.equipmentInventory?.items.contains { $0.id == unit } == true)
  for _ in 0..<8 {
    await runtime.key("r")
    if await runtime.snapshot().autoPilot.targetID == 0 { break }
  }
  for _ in 0..<10000 where !scene.docked { scene = await runtime.advance(delta: 0.02) }
  #expect(scene.docked && scene.dockedAtMainStation)
  let cash = scene.commander.credits
  await runtime.key("contacts-open")
  await runtime.key("return")
  let returned = await runtime.snapshot().commander
  #expect(
    returned.scriptState.instances[id]?.outcome == .complete && returned.credits == cash + 500)
  #expect(returned.equipmentInventory?.items.contains { $0.id == unit } == false)
}

@Test func declaredLaserAndTankLoansUseActualMountsStorageAndFuelWithoutARefill() throws {
  for name in ["Beam Laser", FuelStorage.equipmentName] {
    let laser = name == "Beam Laser"
    let fixture = try GearScriptFixture(
      name: name,
      accepted: "{op='gear.issue',id='issue',gear='kit',fit=false}",
      contact: "{op='gear.refit',id='refit',gear='kit',index=0\(laser ? ",mount='rear'" : "")}",
      confirm:
        "{op='gear.store',id='store',gear='kit',index=0},{op='gear.return',id='return',gear='kit'}")
    defer { fixture.clean() }
    var game = try fixture.game()
    game.emitScriptEvent("contact.requested")
    #expect(game.commander.valid && game.commander.fuel == 70)
    if laser {
      #expect(game.commander.laser(on: .rear) == .beam)
    } else {
      #expect(game.commander.fuelStorageUnits == 1 && game.commander.fuelCapacity == 140)
    }
    game.emitScriptEvent("dialogue.confirmed")
    #expect(
      game.commander.scriptState.instances.values.first?.gearIssues["kit"]?.status == .returned)
    #expect(game.commander.fuelStorageUnits == 0 && game.commander.laser(on: .rear) == nil)
    #expect(game.commander.valid && game.commander.fuel == 70)
  }
  for name in ["Fuel", PassengerCabin.equipmentName, "Unknown Device"] {
    #expect(throws: MissionPackError.self) { try GearScriptFixture(name: name) }
  }
}

@Test func malformedDeclarationsAndIssueRequestsCannotAcquireAnyEquipment() throws {
  for quantity in [0, 33] {
    #expect(throws: MissionPackError.self) { try GearScriptFixture(quantity: quantity) }
  }
  #expect(throws: MissionPackError.self) { try GearScriptFixture(policy: "pretend-returned") }
  for commands in [
    "{op='gear.issue',id='issue',gear='kit',fit='yes'}",
    "{op='gear.issue',id='issue',gear='kit',overwrite=true}",
    "{op='gear.return',id='return',gear='kit'}",
    "{op='gear.refit',id='refit',gear='kit',index=0}",
  ] {
    let fixture = try GearScriptFixture(accepted: commands)
    defer { fixture.clean() }
    var game = Game(executive: false)
    game.scriptPacks = [fixture.pack]
    let before = game.commander
    #expect(throws: MissionPackError.self) { try game.acceptScriptMission(fixture.pack) }
    #expect(game.commander == before)
  }
  let fixture = try GearScriptFixture()
  defer { fixture.clean() }
  let manifest = fixture.root.appendingPathComponent("pack/manifest.toml")
  let text = try String(contentsOf: manifest, encoding: .utf8)
  for invalid in [
    text + "mount='front'\n", text.replacingOccurrences(of: ", \"owned-equipment-v2\"", with: ""),
  ] {
    try invalid.write(to: manifest, atomically: true, encoding: .utf8)
    #expect(throws: MissionPackError.self) {
      try ScriptPackLibrary.read(fixture.root.appendingPathComponent("pack"))
    }
  }
}

@Test func failedLoanReturnPublicationKeepsTheOriginalGoodsDialogueAndRewardForRetry() async throws
{
  let fixture = try GearScriptFixture(
    contact: "{op='dialogue.offer',id='delivery'}",
    confirm:
      "{op='dialogue.commit',id='delivery',token=e.token},{op='gear.return',id='return',gear='kit'},{op='credits',id='reward',amount=100},{op='milestone.ensure',index=0},{op='milestone.ensure',index=1},{op='mission.finish',outcome='complete'}"
  )
  defer { fixture.clean() }
  let directory = fixture.root.appendingPathComponent("save")
  let file = directory.appendingPathComponent("commander.json")
  let runtime = GameRuntime(game: try fixture.game(), saveURL: file)
  await runtime.key("contacts-open")
  let before = await runtime.snapshot().commander
  let bytes = try Data(contentsOf: file)
  let backup = fixture.root.appendingPathComponent("backup")
  try FileManager.default.moveItem(at: directory, to: backup)
  try Data("blocked".utf8).write(to: directory)
  await runtime.key("return")
  #expect(await runtime.snapshot().commander == before)
  #expect(try Data(contentsOf: backup.appendingPathComponent("commander.json")) == bytes)
  try FileManager.default.removeItem(at: directory)
  try FileManager.default.moveItem(at: backup, to: directory)
  await runtime.key("return")
  let completed = await runtime.snapshot().commander
  #expect(
    completed.credits == before.credits + 100
      && completed.scriptState.instances.values.first?.outcome == .complete)
  #expect(try completed.equipmentIssueObligations().allSatisfy { !$0.loan || $0.status != .issued })
  let restored = GameRuntime()
  try await restored.load(from: file)
  #expect(await restored.snapshot().commander == completed)
  await runtime.key("contacts-open")
  await runtime.key("return")
  #expect(await runtime.snapshot().commander.credits == completed.credits)
}

@Test func invalidGearRequestsCannotTakeForeignItemsDuplicateFitsOrMutateAnyProperty() throws {
  for request in [
    "{op='gear.return',id='return',gear='foreign'}",
    "{op='gear.refit',id='refit',gear='kit',index=0}",
    "{op='gear.store',id='store',gear='kit',index=99}",
    "{op='gear.store',id='store',gear='kit',index=0,mount='unknown'}",
    "{op='gear.store',id='store',gear='kit',index=0,item='foreign-uuid'}",
    "{op='gear.store',id='store',gear='kit',index=0},{op='gear.store',id='store-again',gear='kit',index=0}",
  ] {
    let fixture = try GearScriptFixture(contact: request)
    defer { fixture.clean() }
    var game = try fixture.game()
    let before = game.commander
    game.emitScriptEvent("contact.requested")
    #expect(
      game.commander.equipmentInventory == before.equipmentInventory
        && game.commander.credits == before.credits)
    #expect(
      game.commander.scriptState.instances.values.first?.suspension != nil && game.commander.valid)
  }
}

@Test func stationAndOriginGuardsPreserveBorrowedEquipmentAcrossHullChangesAndMissingContent()
  async throws
{
  let fixture = try GearScriptFixture(contact: "{op='gear.return',id='return',gear='kit'}")
  defer { fixture.clean() }
  var game = try fixture.game()
  let id = try #require(game.commander.scriptState.instances.keys.first)
  let issue = try #require(game.commander.scriptState.instances[id]?.gearIssues["kit"])
  game.commander.credits = 10_000_000
  game.key("6")
  game.showroom.selection = "SH013"
  game.key("showroom-trade")
  game.key("right")
  game.key("return")
  #expect(game.commander.shipID == "SH013")
  #expect(
    game.commander.equipmentInventory?.items.first { $0.id == issue.items[0] }?.provenance
      == .missionIssue(mission: id, resource: "kit", index: 0, packDigest: fixture.pack.digest))
  let file = fixture.root.appendingPathComponent("commander.json")
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: file)
  let missing = GameRuntime(game: Game(executive: false))
  try await missing.load(from: file)
  #expect(
    await missing.snapshot().commander.equipmentInventory == game.commander.equipmentInventory)
  _ = await missing.advance(delta: 0.1)
  #expect(await missing.snapshot().commander.scriptState.instances[id]?.suspension != nil)
  game.launch()
  let property = game.commander.equipmentInventory
  game.emitScriptEvent("contact.requested")
  #expect(game.commander.equipmentInventory == property && game.commander.valid)
  var corrupt = game.commander
  let inventory = try #require(corrupt.equipmentInventory)
  corrupt.savedEquipmentInventory = try .init(
    owner: inventory.owner, activeHull: inventory.activeHull, revision: inventory.revision,
    items: inventory.items.filter { $0.id != issue.items[0] })
  corrupt.equipment.remove("E.C.M. System")
  #expect(!corrupt.valid)
}

@Test func stationConfirmedLoansHaveRealIdentityStorageReturnsAndDurableCompletion() async throws {
  let fixture = try GearScriptFixture(
    contact: "{op='gear.store',id='store',gear='kit',index=0},{op='dialogue.offer',id='delivery'}",
    confirm:
      "{op='dialogue.commit',id='delivery',token=e.token},{op='gear.refit',id='refit',gear='kit',index=0},{op='gear.return',id='return',gear='kit'},{op='milestone.ensure',index=0},{op='milestone.ensure',index=1},{op='mission.finish',outcome='complete'}"
  )
  defer { fixture.clean() }
  let file = fixture.root.appendingPathComponent("commander.json")
  let runtime = GameRuntime(game: try fixture.game(), saveURL: file)
  let accepted = await runtime.snapshot().commander
  let state = try #require(accepted.scriptState.instances.values.first)
  let original = try #require(state.gearIssues["kit"]?.items.first)
  let item = try #require(accepted.equipmentInventory?.items.first { $0.id == original })
  #expect(
    item.provenance
      == .missionIssue(
        mission: state.id, resource: "kit", index: 0, packDigest: fixture.pack.digest))
  #expect(item.location?.slot == .utility(.ecm))
  await runtime.key("contacts-open")
  #expect(
    await runtime.snapshot().commander.equipmentInventory?.items.first { $0.id == item.id }?
      .location == nil)
  await runtime.key("return")
  let completed = await runtime.snapshot().commander
  #expect(completed.scriptState.instances[state.id]?.outcome == .complete)
  #expect(completed.scriptState.instances[state.id]?.gearIssues["kit"]?.status == .returned)
  #expect(completed.equipmentInventory?.items.contains { $0.id == item.id } == false)
  #expect(!completed.equipment.contains("E.C.M. System") && completed.valid)
  let restored = GameRuntime(game: Game(executive: false))
  try await restored.load(from: file)
  #expect(await restored.snapshot().commander == completed)
}

@Test func aStoryFlagCannotCompleteAnOutstandingLoanOrARequiredPhysicalReturn() throws {
  for loan in [true, false] {
    let fixture = try GearScriptFixture(
      loan: loan,
      contact:
        "{op='milestone.ensure',index=0},{op='milestone.ensure',index=1},{op='mission.finish',outcome='complete'}"
    )
    defer { fixture.clean() }
    var game = try fixture.game()
    let before = game.commander
    let id = try #require(before.scriptState.instances.keys.first)
    game.emitScriptEvent("contact.requested")
    #expect(game.commander.scriptState.instances[id]?.outcome == .active)
    #expect(game.commander.scriptState.instances[id]?.milestones.isEmpty == true)
    #expect(game.commander.scriptState.instances[id]?.suspension != nil)
    #expect(game.commander.equipmentInventory == before.equipmentInventory && game.commander.valid)
  }
}

@Test func repeatedIssueCannotRefillStockAndRemainingReturnSeparatesRealItemsFromSpentAmmo() throws
{
  let fixture = try GearScriptFixture(
    name: "Missile", policy: "remaining",
    contact: "{op='gear.issue',id='another-issue',gear='kit',fit=true}",
    confirm: "{op='gear.return',id='return',gear='kit'}", observeReturn: true)
  defer { fixture.clean() }
  var game = try fixture.game()
  let id = try #require(game.commander.scriptState.instances.keys.first)
  let issued = try #require(game.commander.scriptState.instances[id]?.gearIssues["kit"])
  #expect(game.commander.missiles == 4)
  game.emitScriptEvent("contact.requested")
  #expect(
    game.commander.missiles == 4
      && game.commander.scriptState.instances[id]?.gearIssues["kit"] == issued)
  game.launch()
  var target = SpaceBody(id: 1, hull: .viper, position: .init(0, 0, 800))
  target.ecmEnabled = true
  game.bodies = [target]
  game.missileArmed = true
  let fired = game.fireMissile()
  #expect(fired && game.commander.missiles == 3 && game.commander.valid)
  #expect(
    game.commander.scriptState.instances[id]?.gearIssues["kit"]?.consumed == Set(issued.items))
  game.dock()
  game.emitScriptEvent("dialogue.confirmed")
  #expect(game.commander.scriptState.instances[id]?.gearIssues["kit"]?.status == .returned)
  game.drainScriptEvents()
  #expect(game.commander.scriptState.instances[id]?.data["actual_returns"] == .integer(0))
  #expect(game.commander.scriptState.instances[id]?.data["spent"] == .integer(1))
  #expect(game.commander.valid)
}

@Test func spentAllItemLoansCannotBeSettledWithNewlyPurchasedSubstitutes() throws {
  let fixture = try GearScriptFixture(
    name: "Missile", contact: "{op='gear.return',id='return',gear='kit'}")
  defer { fixture.clean() }
  var game = try fixture.game()
  let id = try #require(game.commander.scriptState.instances.keys.first)
  let original = try #require(
    game.commander.scriptState.instances[id]?.gearIssues["kit"]?.items.first)
  game.launch()
  game.bodies = [SpaceBody(id: 1, hull: .sidewinder, position: .init(0, 0, 800))]
  game.missileArmed = true
  _ = game.fireMissile()
  game.dock()
  game.selection = Equipment.all.firstIndex { $0.name == "Missile" }!
  game.purchase()
  #expect(game.commander.missiles == 4)
  #expect(game.commander.equipmentInventory?.items.contains { $0.id == original } == false)
  let property = game.commander.equipmentInventory
  game.emitScriptEvent("contact.requested")
  #expect(game.commander.scriptState.instances[id]?.suspension != nil)
  #expect(game.commander.scriptState.instances[id]?.gearIssues["kit"]?.status == .issued)
  #expect(game.commander.equipmentInventory == property && game.commander.valid)
}

@Test func loanReleaseIsExplicitAndCannotSatisfyARequiredReturn() throws {
  for required in [false, true] {
    let fixture = try GearScriptFixture(
      requiredReturn: required,
      contact:
        "{op='gear.release',id='release',gear='kit'},{op='milestone.ensure',index=0},{op='milestone.ensure',index=1},{op='mission.finish',outcome='complete'}"
    )
    defer { fixture.clean() }
    var game = try fixture.game()
    let id = try #require(game.commander.scriptState.instances.keys.first)
    game.emitScriptEvent("contact.requested")
    #expect(game.commander.scriptState.instances[id]?.outcome == (required ? .active : .complete))
    #expect(
      game.commander.scriptState.instances[id]?.gearIssues["kit"]?.status
        == (required ? .issued : .released))
    #expect(
      try game.commander.equipmentIssueObligations().first { $0.source.mission == id }?.status
        == (required ? .issued : .released))
    #expect(game.commander.valid)
  }
}

@Test func deniedEquipmentFitAndLaterDeniedCommandsRollbackTheWholeMissionAcceptance() throws {
  for commands in [
    "{op='gear.issue',id='issue',gear='kit',fit=true}",
    "{op='gear.issue',id='issue',gear='kit',fit=false},{op='credits',id='debit',amount=-100000}",
  ] {
    let fixture = try GearScriptFixture(quantity: 2, accepted: commands)
    defer { fixture.clean() }
    var game = Game(executive: false)
    game.scriptPacks = [fixture.pack]
    let before = game.commander
    #expect(throws: MissionPackError.self) { try game.acceptScriptMission(fixture.pack) }
    #expect(
      game.commander == before && game.commander.equipmentInventory == before.equipmentInventory)
  }
}
