import Foundation
import Testing

@testable import L337Core

struct TrialEquipmentQuoteScenario: Sendable {
  let pledge: Bool
  let scene: Bool
  static let cases = [false, true].flatMap { pledge in
    [false, true].map { TrialEquipmentQuoteScenario(pledge: pledge, scene: $0) }
  }
}

private struct TrialEquipmentQuoteFixture {
  let directory: URL
  let pack: ScriptPack
  var save: URL { directory.appendingPathComponent("live.json") }

  init(_ scenario: TrialEquipmentQuoteScenario) throws {
    let scene = """
      [trial]
      ship = "SH023"
      galaxy = 0
      system = 7
      credits = 100000
      cabins = 0
      flight = false
      offer = 0
      """
    let edit: ((String) -> String)? =
      scenario.scene ? nil : { $0.replacingOccurrences(of: scene, with: "") }
    if scenario.pledge {
      let fixture = try PledgeFixture(manifestEdit: edit)
      directory = fixture.directory
      pack = fixture.pack
    } else {
      let fixture = try CourierFixture(manifestEdit: edit)
      directory = fixture.root
      pack = fixture.pack
    }
  }

  func clean() { try? FileManager.default.removeItem(at: directory) }
}

private func reviewPinnedCourierEquipmentTrial(_ runtime: GameRuntime) async throws {
  let initial = await runtime.snapshot()
  let declined = try #require(initial.contractBoard.quote)
  #expect(!declined.allowed)
  #expect(
    declined.issues == [
      "Frozen itinerary has no deadline headroom. This listing cannot be accepted."
    ])
  await #expect(throws: MissionPackError.self) { try await runtime.confirmContract(declined) }
  let afterRefusal = await runtime.snapshot().commander
  #expect(afterRefusal == initial.commander)
  let board = try #require(initial.commander.contracts.boards[declined.board])
  let pinned = try #require(board.offers.indices.contains(4) ? board.offers[4] : nil)
  let terms = try #require(pinned.courier)
  try #require(terms.row == 4 && terms.calendarLowerBoundSeconds < terms.duration)
  // Navigate the same published board. No refresh, reroll, altered pack or deadline extension.
  await runtime.key("escape")
  for _ in 0..<initial.contractBoard.rows.count {
    let selected = await runtime.snapshot().contractBoard.selected?.offer?.id
    if selected == pinned.id { break }
    await runtime.key("down")
  }
  let selected = await runtime.snapshot().contractBoard.selected?.offer?.id
  try #require(selected == pinned.id)
  await runtime.key("return")
  let reviewed = await runtime.snapshot()
  #expect(reviewed.contractBoard.quote?.offer == pinned.id)
  #expect(reviewed.commander.contracts.boards[declined.board] == board)
}

private func usePublishedTrialQuote(
  _ runtime: GameRuntime, quote: ContractAcceptanceQuote, pledge: Bool
) async throws -> Commander {
  let before = await runtime.snapshot().commander
  if !quote.allowed {
    await #expect(throws: MissionPackError.self) { try await runtime.confirmContract(quote) }
    #expect(await runtime.snapshot().commander == before)
    return before
  }
  let identity = try await runtime.confirmContract(quote)
  let accepted = await runtime.snapshot().commander
  #expect(accepted.scriptState.instances.count == 1)
  if pledge {
    #expect(accepted.scriptState.pledgeLedger?.receipts.count == 1)
    #expect(accepted.scriptState.pledgeLedger?.receipt(instance: identity) != nil)
  } else {
    #expect(accepted.scriptState.instances[identity]?.courier?.terminal == nil)
    #expect(accepted.scriptState.instances[identity]?.contract?.offer.id == quote.offer)
  }
  #expect(accepted.equipmentInventory == before.equipmentInventory)
  #expect(accepted.equipmentPurchaseHistory == before.equipmentPurchaseHistory)
  let repeated = try await runtime.confirmContract(quote)
  let afterRepeat = await runtime.snapshot().commander
  #expect(repeated == identity && afterRepeat == accepted)
  return accepted
}

@Test(arguments: TrialEquipmentQuoteScenario.cases)
func publishedTrialQuotesBindCanonicalEquipmentAcrossSaveLoadRestartAndReturn(
  scenario: TrialEquipmentQuoteScenario
) async throws {
  let fixture = try TrialEquipmentQuoteFixture(scenario)
  defer { fixture.clean() }
  try #require((fixture.pack.manifest.trial != nil) == scenario.scene)
  var game = Game(executive: false)
  game.screen = .status
  game.scriptPacks = [fixture.pack]
  game.commander.name = "KEEP PROPERTY"
  game.commander.credits = 543210
  game.commander.cargo[0] = 2
  game.openGallery()
  try #require(game.commander.valid)
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  try await runtime.save(to: fixture.save)
  let live = await runtime.snapshot().commander
  let bytes = try Data(contentsOf: fixture.save)
  try await runtime.startScriptGalleryTrial(packDigest: fixture.pack.digest, seed: 42)
  let namespace = try #require(await runtime.gallerySaveDirectory())
  defer { try? FileManager.default.removeItem(at: namespace) }
  if scenario.scene && !scenario.pledge { try await reviewPinnedCourierEquipmentTrial(runtime) }
  let published = await runtime.snapshot()
  let quote = try #require(published.contractBoard.quote)
  let inventory = try #require(published.commander.equipmentInventory)
  #expect(published.isMissionTrial && published.commander.valid)
  #expect(published.commander.savedEquipmentVersion == 3)
  #expect(quote.resources == published.commander.contractQuoteResources)
  #expect(inventory.items.allSatisfy { $0.provenance == .standard })
  let rounds = inventory.items.filter { $0.node == EquipmentRuntimeCatalog.standardMissile }
  #expect(rounds.count == 3 && published.commander.missiles == 3)
  #expect(
    Set(rounds.compactMap { $0.location?.slot })
      == Set(
        (0..<3).map {
          ComponentFittingSlot.missilePylon($0)
        }))
  let expectedShip = scenario.scene ? "SH023" : "SH025"
  let expectedFuel = scenario.scene ? 70 : 130
  let expectedCash = scenario.scene ? 100000 : 7200
  let expectedAllowed = scenario.scene || scenario.pledge
  #expect(published.commander.shipID == expectedShip && published.commander.credits == expectedCash)
  #expect(published.commander.fuel == expectedFuel && !published.commander.unlimitedMissiles)
  let expectedIssues: [String]
  if scenario.scene {
    expectedIssues = []
  } else if scenario.pledge {
    // The approved fresh commander's 720.0 CR can fund the first full 500.0 CR donation.
    expectedIssues = []
    let pledge = try #require(quote.pledge)
    #expect(pledge.before.cash == 7200 && pledge.amount == 5000)
  } else {
    // Removing the scene changes the digest and this pinned courier's frozen itinerary.
    expectedIssues = ["Frozen itinerary has no deadline headroom. This listing cannot be accepted."]
    let courier = try #require(quote.courier)
    #expect(courier.terms.calendarLowerBoundSeconds >= courier.terms.duration)
  }
  #expect(quote.allowed == expectedAllowed)
  #expect(
    quote.issues == expectedIssues,
    Comment(rawValue: "Published trial quote issues: " + quote.issues.joined(separator: "; ")))
  let accepted = try await usePublishedTrialQuote(runtime, quote: quote, pledge: scenario.pledge)
  let saved = try await runtime.saveForInterface()
  #expect(saved.isTrial && saved.url == namespace.appendingPathComponent("commander.json"))
  let (stored, world) = try ScriptSaveStore.read(Data(contentsOf: saved.url), from: saved.url)
  #expect(stored == accepted && world.valid && world.consistent(with: stored))
  let loaded = try await runtime.loadForInterface()
  #expect(loaded.isTrial && loaded.url == saved.url)
  #expect(await runtime.snapshot().commander == accepted)
  #expect(try Data(contentsOf: fixture.save) == bytes)

  try await runtime.restartScriptGalleryTrial()
  if scenario.scene && !scenario.pledge { try await reviewPinnedCourierEquipmentTrial(runtime) }
  let restarted = await runtime.snapshot()
  let restartQuote = try #require(restarted.contractBoard.quote)
  let nextInventory = try #require(restarted.commander.equipmentInventory)
  #expect(await runtime.gallerySaveDirectory() == namespace)
  #expect(restarted.commander.scriptState.instances.isEmpty)
  #expect(restartQuote.resources == restarted.commander.contractQuoteResources)
  #expect(restartQuote.allowed == quote.allowed && restartQuote.issues == expectedIssues)
  #expect(
    nextInventory.owner != inventory.owner && nextInventory.activeHull != inventory.activeHull)
  #expect(Set(nextInventory.items.map(\.id)).isDisjoint(with: inventory.items.map(\.id)))
  #expect(nextInventory.items.allSatisfy { $0.provenance == .standard })
  let beforeOldQuote = restarted.commander
  await #expect(throws: MissionPackError.self) { try await runtime.confirmContract(quote) }
  #expect(await runtime.snapshot().commander == beforeOldQuote)
  _ = try await usePublishedTrialQuote(runtime, quote: restartQuote, pledge: scenario.pledge)
  _ = try await runtime.saveForInterface()
  #expect(try Data(contentsOf: fixture.save) == bytes)
  try await runtime.returnFromScriptGalleryTrial()
  #expect(await runtime.snapshot().commander == live)
  #expect(await runtime.gallerySaveDirectory() == nil)
  #expect(try Data(contentsOf: fixture.save) == bytes)
}
