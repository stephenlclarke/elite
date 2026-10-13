import Foundation
import Testing

@testable import EliteCore

private func blackjackGame() -> Game {
  var game = Game(executive: false)
  game.commander.galaxy = 1
  game.systems = Universe.galaxy(number: 1)
  game.commander.system = 241
  game.selectedSystem = 241
  game.screen = .status
  game.dock()
  game.key("return")
  return game
}
private func visit(_ game: inout Game, _ system: Int) {
  if game.screen == .handoff { game.key("escape") }
  game.selectedSystem = system
  game.arrive()
  game.dock()
}
private func defeat(_ game: inout Game, _ role: BlackjackTarget, player: Bool = false) throws
  -> SpaceBody
{
  if game.screen == .handoff { game.key("escape") }
  game.selectedSystem = role.system
  game.arrive()
  game.docked = false
  game.restoreBlackjackEncounter()
  let index = try #require(game.bodies.firstIndex { $0.blackjackRole == role })
  game.bodies[index].energy = 0
  game.bodies[index].destroyedByPlayer = player
  let target = game.bodies[index]
  game.resolveDestroyed()
  return target
}
private func afterRobbery() throws -> Game {
  var game = blackjackGame()
  _ = try defeat(&game, .bolts)
  visit(&game, 233)
  game.key("return")
  game.key("b")
  game.key("return")
  visit(&game, 127)
  game.key("return")
  return game
}

@Test func blackjackUsesExactGalaxySystemsAndNoScoreGate() {
  let galaxy = Universe.galaxy(number: 1)
  for (id, name) in [
    (241, "Telace"), (88, "Gerebied"), (233, "Tegete"), (127, "Ceinerxe"), (99, "Edater"),
    (67, "Esdi"),
  ] {
    #expect(galaxy[id].name == name.uppercased())
  }
  var game = Game(executive: false)
  game.commander.system = 241
  game.dock()
  #expect(game.commander.blackjack.stage == .notStarted)
  game.commander.galaxy = 1
  game.systems = galaxy
  game.commander.system = 88
  game.dock()
  #expect(game.commander.blackjack.stage == .notStarted)
  game.commander.system = 241
  game.dock(atMainStation: false)
  #expect(game.commander.blackjack.stage == .notStarted)
  game.dock()
  #expect(game.commander.kills == 0 && game.commander.blackjack.stage == .huntBolts)
  #expect(game.screen == .handoff && game.blackjackOffer?.action == .introduction)
  game.key("escape")
  #expect(game.commander.blackjack.transfers == [.contact] && game.commander.valid)
}
@Test func blackjackCampaignAnyKillerRewardsAndAllSevenMilestonesCompleteOnce() throws {
  var game = blackjackGame()
  #expect(game.blackjackGalleryMission.completed == 1)
  let target = try defeat(&game, .bolts)
  #expect(game.commander.cargo[13] == 20 && game.commander.kills == 0)
  #expect(game.commander.blackjack.stage == .reportBolts && game.commander.valid)
  game.blackjackTargetDestroyed(target)
  #expect(game.commander.cargo[13] == 20)
  visit(&game, 7)
  game.key("return")
  #expect(game.commander.blackjack.stage == .collectFirearm)
  visit(&game, 233)
  game.key("return")
  #expect(game.commander.blackjack.stage == .deliverFirearm && game.commander.cargo[10] == 1)
  visit(&game, 127)
  game.key("return")
  #expect(game.commander.blackjack.stage == .huntWitness && game.commander.cargo[10] == 0)
  #expect(game.commander.legal == 64 && game.commander.valid)
  let witness = try defeat(&game, .witness)
  #expect(game.commander.blackjack.stage == .reportWitness)
  visit(&game, 67)
  let cash = game.commander.credits
  game.key("return")
  #expect(game.commander.credits == cash + 95000 && game.commander.legal == 0)
  #expect(
    game.commander.blackjack.stage == .complete && game.blackjackGalleryMission.completed == 7)
  #expect(game.commander.blackjack.transfers == Set(BlackjackTransfer.allCases))
  game.blackjackTargetDestroyed(witness)
  game.commander.legal = 123
  game.dock()
  game.key("b")
  game.confirmBlackjackHandoff()
  #expect(game.commander.credits == cash + 95000 && game.commander.legal == 123)
  #expect(game.commander.valid && game.blackjackGalleryMission.status == .complete)
}
@Test func blackjackTransfersRequireExactStationAndBackHasNoTransferEffects() throws {
  var game = blackjackGame()
  _ = try defeat(&game, .bolts)
  visit(&game, 88)
  let before = game.commander
  game.key("right")
  game.key("return")
  #expect(game.commander == before && game.screen == .status)
  game.key("b")
  game.commander.system = 7
  game.confirmBlackjackHandoff()
  #expect(
    game.commander.blackjack.stage == .reportBolts && game.message == "CONTACT NO LONGER AVAILABLE")
  game.commander.system = 88
  game.dockedAtMainStation = false
  game.confirmBlackjackHandoff()
  #expect(game.commander.blackjack.stage == .reportBolts)
  game.dockedAtMainStation = true
  game.commander.galaxy = 0
  game.confirmBlackjackHandoff()
  #expect(game.commander.blackjack.stage == .reportBolts)
  game.commander.galaxy = 1
  game.confirmBlackjackHandoff()
  for system in [7, 88, 127, 99, 67, 241] {
    visit(&game, system)
    #expect(game.screen != .handoff && game.commander.blackjack.stage == .collectFirearm)
  }
  visit(&game, 233)
  game.key("return")
  for system in [7, 88, 233, 99, 67, 241] {
    visit(&game, system)
    #expect(game.commander.blackjack.stage == .deliverFirearm && game.commander.cargo[10] == 1)
  }
}
@Test func blackjackFullHoldBlocksPickupAndPreservesMissionCargoAcrossTradeAndEscape() throws {
  var game = blackjackGame()
  _ = try defeat(&game, .bolts)
  visit(&game, 233)
  game.key("return")
  game.key("b")
  game.commander.cargo[0] = 20
  let before = game.commander
  game.key("return")
  #expect(
    game.commander == before && game.screen == .handoff && game.message.contains("FREE TONNE"))
  game.key("escape")
  game.commander.cargo[0] = 19
  game.key("b")
  game.key("return")
  #expect(game.commander.cargoTonnes == 20 && game.commander.markedFirearms == 1)
  #expect(!game.commander.canCarryMissionCargo(capacity: 19))
  game.screen = .sell
  game.selection = 10
  game.trade(buy: false)
  #expect(game.commander.cargo[10] == 1 && game.message == "MISSION FIREARM RESERVED")
  #expect(game.marketAvailability(10) == "RESERVED")
  game.commander.cargo[0] -= 1
  game.commander.cargo[10] += 1
  game.trade(buy: false)
  #expect(game.commander.cargo[10] == 1)
  game.commander.credits = 100000
  game.autoTrade()
  #expect(game.commander.cargo[10] >= 1 && game.commander.markedFirearms == 1)
  game.commander.equipment.insert("Escape Pod")
  game.launch()
  game.escapePod()
  #expect(game.commander.cargo[10] == 1 && game.commander.valid)
  #expect(game.commander.canCarryMissionCargo(capacity: 20))
  visit(&game, 127)
  game.key("return")
  #expect(game.commander.cargo[10] == 0)
}
@Test func blackjackGoldFitsATonneFullHoldAndNumericCapacityDefersRatherThanLosesReward() throws {
  var game = blackjackGame()
  game.commander.cargo[0] = 20
  _ = try defeat(&game, .bolts)
  #expect(game.commander.cargoTonnes == 20 && game.commander.cargo[13] == 20)
  game = blackjackGame()
  game.commander.cargo[13] = Int.max / 17 - 10
  let target = try defeat(&game, .bolts)
  #expect(game.commander.blackjack.pendingGold && game.commander.valid)
  visit(&game, 7)
  let before = game.commander
  game.key("return")
  #expect(game.commander == before && game.blackjackOffer?.action == .collectGold)
  game.commander.cargo[13] -= 10
  game.key("return")
  #expect(game.commander.cargo[13] == Int.max / 17 && !game.commander.blackjack.pendingGold)
  game.blackjackTargetDestroyed(target)
  #expect(game.commander.cargo[13] == Int.max / 17)
}
@Test func blackjackWitnessCannotAdvanceWrongStageIdentityOrGalaxyAndWantedDoesNotReduceOffences()
  throws
{
  var game = try afterRobbery()
  game.selectedSystem = 99
  game.arrive()
  game.docked = false
  game.restoreBlackjackEncounter()
  var witness = try #require(game.bodies.first { $0.blackjackRole == .witness })
  witness.energy = 0
  var rogue = witness
  rogue.blackjackIdentity = UUID()
  game.blackjackTargetDestroyed(rogue)
  #expect(game.commander.blackjack.stage == .huntWitness)
  game.commander.galaxy = 0
  game.blackjackTargetDestroyed(witness)
  #expect(game.commander.blackjack.stage == .huntWitness)
  game.commander.galaxy = 1
  game.commander.system = 7
  game.blackjackTargetDestroyed(witness)
  #expect(game.commander.blackjack.stage == .huntWitness)
  game.commander.system = 99
  game.commander.legal = 200
  game.dock()
  #expect(game.commander.legal == 200)
  game.blackjackTargetDestroyed(witness)
  #expect(game.commander.blackjack.stage == .reportWitness)
  visit(&game, 7)
  #expect(game.commander.legal == 200 && game.screen != .handoff)
  visit(&game, 67)
  game.commander.credits = 4_294_967_295
  game.key("return")
  #expect(game.commander.blackjack.stage == .reportWitness && game.commander.legal == 200)
  game.commander.credits -= 95000
  game.key("return")
  #expect(game.commander.credits == 4_294_967_295 && game.commander.legal == 0)
}
@Test func blackjackDamageAmmoIdentityAndStationRelativePoseSurviveReloadAndReentry() async throws {
  var game = blackjackGame()
  game.selectedSystem = 88
  game.docked = false
  game.arrive()
  let index = try #require(game.bodies.firstIndex { $0.blackjackRole == .bolts })
  game.bodies[index].energy = 123
  game.bodies[index].missiles = 1
  game.bodies[index].blackjackLaserCooldown = 0.2
  game.bodies[index].position = .init(100, 50, 1700)
  game.bodies[index].orientation.rotate(pitch: 0.2, roll: 0.3, yaw: 0.4)
  let id = game.bodies[index].blackjackIdentity
  game.persistBlackjackTargets()
  let saved = try #require(game.commander.blackjack.bolts)
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: url) }
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: url)
  try await runtime.load(from: url)
  await runtime.key("0")
  let restored = await runtime.snapshot()
  let body = try #require(restored.bodies.first { $0.blackjackRole == .bolts })
  #expect(
    body.blackjackIdentity == id && body.energy == 123 && body.missiles == 1
      && body.blackjackLaserCooldown == 0.2)
  let station = try #require(restored.bodies.first { $0.hull == .station })
  #expect((body.position - station.position - saved.body.position).length < 0.0001)
  #expect(body.orientation == saved.body.orientation)
  game.selectedSystem = 7
  game.arrive()
  game.selectedSystem = 88
  game.arrive()
  #expect(game.bodies.filter { $0.blackjackIdentity == id }.count == 1)
  #expect(game.bodies.first { $0.blackjackIdentity == id }?.missiles == 1)
}
@Test func blackjackSaveFinalisesPendingDeathAndCannotMintGoldOrPayoutAgain() async throws {
  var game = blackjackGame()
  game.selectedSystem = 88
  game.docked = false
  game.arrive()
  let index = try #require(game.bodies.firstIndex { $0.blackjackRole == .bolts })
  game.bodies[index].energy = -5
  game.bodies[index].destroyedByPlayer = true
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: url) }
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: url)
  try await runtime.load(from: url)
  #expect(await runtime.snapshot().commander.cargo[13] == 20)
  #expect(await runtime.snapshot().commander.blackjack.stage == .reportBolts)
  await runtime.key("0")
  #expect(await runtime.snapshot().bodies.allSatisfy { $0.blackjackRole != .bolts })
  try await runtime.save(to: url)
  try await runtime.load(from: url)
  #expect(await runtime.snapshot().commander.cargo[13] == 20)
}
@Test func blackjackNativeNPCUsesFiniteSourceStatsAndDeadActorsCannotRecharge() throws {
  var game = blackjackGame()
  game.selectedSystem = 88
  game.docked = false
  game.arrive()
  let index = try #require(game.bodies.firstIndex { $0.blackjackRole == .bolts })
  #expect(
    game.bodies[index].energy == 300 && game.bodies[index].missiles == 3
      && game.bodies[index].ecmEnabled)
  #expect(BlackjackTarget.bolts.cargoCapacity == 55 && BlackjackTarget.witness.cargoCapacity == 5)
  game.bodies[index].energy = 100
  for _ in 0..<512 { game.navalTactics() }
  #expect(game.bodies[index].missiles == 0 && game.bodies.filter(\.enemyMissile).count == 3)
  let before = game.bodies[index].position.length
  game.advanceBlackjackNPC(index: index, delta: 0.1)
  #expect(abs(game.bodies[index].energy - 100.4) < 0.0001)
  #expect(abs(before - game.bodies[index].position.length - 39) < 0.0001)
  game.bodies[index].energy = 0
  game.tick(delta: 0.1)
  #expect(!game.bodies.contains { $0.blackjackRole == .bolts })
  #expect(game.commander.blackjack.stage == .reportBolts)
}
@Test func blackjackRangeRemovalReencountersSameLivingTargetWithoutAmmoOrGoldRegeneration() throws {
  var game = blackjackGame()
  game.selectedSystem = 88
  game.docked = false
  game.arrive()
  let index = try #require(game.bodies.firstIndex { $0.blackjackRole == .bolts })
  let identity = game.bodies[index].blackjackIdentity
  game.bodies[index].position.z = 50000
  game.bodies[index].energy = 42
  game.bodies[index].missiles = 0
  game.tick(delta: 0.01)
  #expect(game.commander.blackjack.stage == .huntBolts && game.commander.cargo[13] == 0)
  game.selectedSystem = 7
  game.arrive()
  game.selectedSystem = 88
  game.arrive()
  let body = try #require(game.bodies.first { $0.blackjackIdentity == identity })
  #expect(body.missiles == 0 && body.energy < 43 && !body.leavesLocalBubble)
}
@Test func blackjackStateValidationAcceptsOldCommandersAndRejectsInvalidProfilesCustodyAndActors()
  throws
{
  let old = try JSONDecoder().decode(Commander.self, from: JSONEncoder().encode(Commander()))
  #expect(old.blackjack == BlackjackMission() && old.valid)
  var game = blackjackGame()
  _ = try defeat(&game, .bolts)
  visit(&game, 233)
  game.key("return")
  game.key("b")
  game.key("return")
  game.commander.cargo[10] = 0
  #expect(!game.commander.valid)
  game.commander.cargo[10] = 1
  game.commander.blackjack.profileRevision = "unsupported"
  #expect(!game.commander.valid)
  game.commander.blackjack.profileRevision = BlackjackMission.revision
  game.commander.blackjack.bolts?.body.missiles = 4
  #expect(!game.commander.valid)
  game.commander.blackjack.bolts?.body.missiles = 1
  game.commander.blackjack.bolts?.body.orientation.x = .init(0, 0, 0)
  #expect(!game.commander.valid)
}
@Test func blackjackGalleryReflectsEveryActualMilestoneAndNativeHandoffsStayInsideSmallWindows()
  throws
{
  var game = blackjackGame()
  for action in [
    BlackjackAction.introduction, .report, .collectFirearm, .robbery, .finalReport, .collectGold,
  ] {
    game.blackjackOffer = .init(action: action, galaxy: 1, system: 241)
    for width in [512.0, 768, 1512] {
      let frame = Display.blackjackHandoff(game, width: width, height: 518)
      for label in frame.labels {
        #expect(label.bounds.x >= 0 && label.bounds.maxX <= width && label.bounds.maxY <= 518)
      }
    }
  }
  game.blackjackOffer = .init(action: .introduction, galaxy: 1, system: 241)
  game.screen = .handoff
  let time = game.time
  game.tick(delta: 0.1)
  #expect(game.time == time)
  game.key("k")
  #expect(game.screen == .help && game.helpReturn == .handoff)
  game.key("k")
  #expect(game.screen == .handoff)
  game.viewportWidth = 512
  game.viewportHeight = 518
  game.blackjackHandoffClick(x: 300, y: 470)
  #expect(game.screen == .status)
  game.key("b")
  #expect(game.screen == .status)
  #expect(
    game.blackjackGalleryMission.status == .active && game.blackjackGalleryMission.completed == 1)
  game.commander.blackjack = BlackjackMission()
  game.commander.galaxy = 0
  #expect(game.blackjackGalleryMission.status == .locked)
  game.commander.galaxy = 1
  #expect(game.blackjackGalleryMission.status == .available)
}

@Test func blackjackReloadDoesNotConfirmStationTransfersOrReplacePersonalEquipment() async throws {
  var game = blackjackGame()
  _ = try defeat(&game, .bolts)
  visit(&game, 233)
  game.key("return")
  game.key("b")
  game.commander.installLaser(.military, on: .rear)
  game.commander.missiles = 2
  let equipment = game.commander.equipment
  let mounts = game.commander.laserMounts
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: url) }
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: url)
  try await runtime.load(from: url)
  #expect(await runtime.snapshot().screen == .status)
  #expect(await runtime.snapshot().commander.blackjack.stage == .collectFirearm)
  #expect(await runtime.snapshot().commander.cargo[10] == 0)
  await runtime.key("b")
  await runtime.key("return")
  await runtime.key("b")
  await runtime.key("return")
  #expect(await runtime.snapshot().commander.cargo[10] == 1)
  #expect(await runtime.snapshot().commander.equipment == equipment)
  #expect(await runtime.snapshot().commander.laserMounts == mounts)
  #expect(await runtime.snapshot().commander.missiles == 2)
  try await runtime.save(to: url)
  try await runtime.load(from: url)
  #expect(await runtime.snapshot().commander.markedFirearms == 1)
}

@Test func blackjackContactWaitsForNavalMessagesAndCannotLaunchFromModal() {
  var game = Game(executive: false)
  game.commander.galaxy = 1
  game.systems = Universe.galaxy(number: 1)
  game.commander.system = 241
  game.commander.kills = 256
  game.dock()
  #expect(game.screen == .mission && game.commander.blackjack.stage == .notStarted)
  game.tick(delta: 2)
  for _ in 0..<30 { game.tick(delta: 0.1) }
  for _ in 0..<8 where game.screen == .mission { game.key("return") }
  #expect(game.commander.blackjack.stage == .huntBolts)
  game.key("b")
  let before = game.commander
  game.key("0")
  game.key("l")
  game.key("x")
  #expect(game.screen == .handoff && game.commander == before && game.docked)
  game.blackjackHandoffClick(x: -1, y: -1)
  #expect(game.screen == .handoff)
  game.blackjackHandoffClick(x: 100, y: game.viewportHeight - 40)
  #expect(game.screen == .status && game.commander == before)
}

@Test func blackjackAllMilestonesReflectTransfersAndPendingGoldRatherThanClueVisits() throws {
  var game = blackjackGame()
  func check(_ game: Game, _ completed: Int) {
    #expect(game.blackjackGalleryMission.completed == completed)
    #expect(
      game.blackjackGalleryMission.milestones.filter { $0.state == "Complete" }.count == completed)
    #expect(game.commander.valid)
  }
  check(game, 1)
  _ = try defeat(&game, .bolts)
  check(game, 2)
  visit(&game, 7)
  game.key("return")
  check(game, 3)
  visit(&game, 233)
  game.key("return")
  check(game, 4)
  visit(&game, 127)
  game.key("return")
  check(game, 5)
  _ = try defeat(&game, .witness)
  check(game, 6)
  visit(&game, 67)
  game.key("return")
  check(game, 7)
}
