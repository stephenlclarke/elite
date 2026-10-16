import Foundation
import Testing

@testable import EliteCore

struct CourierFixture {
  let root: URL
  let pack: ScriptPack
  var save: URL { root.appendingPathComponent("commander.json") }
  init(scriptEdit: ((String) -> String)? = nil, manifestEdit: ((String) -> String)? = nil) throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "courier-" + UUID().uuidString)
    let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/generated-couriers")
    try FileManager.default.copyItem(at: source, to: root)
    if let scriptEdit {
      let file = root.appendingPathComponent("scripts/main.lua")
      try scriptEdit(String(contentsOf: file, encoding: .utf8)).write(
        to: file, atomically: true, encoding: .utf8)
    }
    if let manifestEdit {
      let file = root.appendingPathComponent("manifest.toml")
      try manifestEdit(String(contentsOf: file, encoding: .utf8)).write(
        to: file, atomically: true, encoding: .utf8)
    }
    pack = try ScriptPackLibrary.read(root)
  }
  func clean() { try? FileManager.default.removeItem(at: root) }
  func game(system: Int = 7) -> Game {
    var game = Game(executive: false)
    game.screen = .status
    game.scriptPacks = [pack]
    game.scriptDurabilityAvailable = true
    game.commander.credits = 100000
    game.commander.system = system
    return game
  }
  func offer(_ game: inout Game, row: Int = 0) throws -> (String, ScriptContractOffer) {
    let key = try game.ensureContractBoard(pack)
    return (key, try #require(game.commander.contracts.boards[key]?.offers[row]))
  }
  func usable(_ game: inout Game, variant: ScriptCourierVariant = .data) throws -> (
    String, ScriptContractOffer
  ) {
    // Select an actual board epoch with an eligible frozen row; never rewrite a generated row.
    for _ in 0..<128 {
      let key = try game.ensureContractBoard(pack)
      let offers = try #require(game.commander.contracts.boards[key]?.offers)
      if let offer = offers.first(where: {
        $0.courier?.variant == variant
          && game.contractAcceptanceQuote(board: key, offer: $0.id).allowed
      }) {
        return (key, offer)
      }
      game.commander.scriptState.calendarSeconds += 3600
      game.commander.scriptState.missionCalendar?.seconds += 3600
    }
    throw MissionPackError("Fixture could not find a usable actual frozen courier row.")
  }
  func accept(_ game: inout Game, variant: ScriptCourierVariant = .data) throws -> UUID {
    let (key, offer) = try usable(&game, variant: variant)
    return try game.confirmContract(game.contractAcceptanceQuote(board: key, offer: offer.id))
  }
  func requestContact(_ game: inout Game, id: UUID) throws {
    game.emitScriptEvent("contact.requested", only: id)
    let shown = game.showScriptDialogue(only: id)
    #expect(shown)
    #expect(!game.scriptConfirmSelected)
  }
  func travel(_ game: inout Game, id: UUID) throws {
    let terms = try #require(game.commander.scriptState.instances[id]?.contract?.offer.courier)
    for destination in terms.path.dropFirst() {
      game.screen = .status
      game.launch()
      #expect(!game.docked)
      // Remove unrelated traffic/celestials in this deterministic travel fixture, not mission evidence.
      game.bodies = []
      game.celestials = []
      game.selectedSystem = destination
      game.beginHyperspace()
      #expect(game.jumpCountdown != nil)
      #expect(game.commander.scriptState.calendarLedger?.pendingJourney?.destination == destination)
      while game.jumpCountdown != nil { game.tick(delta: 0.1) }
      #expect(game.commander.system == destination)
      game.dock()
      if destination != terms.destination {
        game.selection = try #require(Equipment.all.firstIndex { $0.name == "Fuel" })
        game.purchase()
        #expect(game.commander.fuel == game.commander.fuelCapacity)
      }
    }
  }
}

@Test func courierSixFrozenRowsAndQuotesPreserveProperty() throws {
  let fixture = try CourierFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let (key, _) = try fixture.offer(&game)
  let board = try #require(game.commander.contracts.boards[key])
  #expect(board.valid && game.commander.valid)
  #expect(
    board.offers.map(\.key) == [
      "data-1", "package-1", "data-2", "package-2", "data-3", "package-3",
    ])
  let before = game.commander
  for offer in board.offers {
    let quote = game.contractAcceptanceQuote(board: key, offer: offer.id)
    #expect(quote.courier != nil)
    #expect(
      offer.courier?.calendarLowerBoundSeconds
        == offer.courier?.generation.calendarCost(offer.courier!.path))
  }
  #expect(game.commander == before)
  #expect(try game.ensureContractBoard(fixture.pack) == key)
  #expect(game.commander == before)
}

@Test(arguments: [ScriptCourierVariant.data, .package])
func courierNativeIssuanceTravelContactAndPaymentAreUnique(variant: ScriptCourierVariant) throws {
  let fixture = try CourierFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let id = try fixture.accept(&game, variant: variant)
  let original = try #require(game.commander.scriptState.instances[id])
  #expect(
    original.courier?.terminal == nil
      && original.courier?.item == ScriptCourierCustody.itemIdentity(id))
  #expect(game.commander.cargoTonnes == variant.tonnes && game.commander.valid)
  try fixture.travel(&game, id: id)
  let cash = game.commander.credits
  try fixture.requestContact(&game, id: id)
  #expect(game.courierContactActionLabel == "Deliver")
  let before = game.commander
  game.key("return")  // Back is selected.
  #expect(game.commander == before)
  try fixture.requestContact(&game, id: id)
  game.key("left")
  game.key("return")
  let completed = try #require(game.commander.scriptState.instances[id])
  #expect(completed.outcome == .complete && completed.courier?.terminal?.cause == .delivered)
  #expect(game.commander.credits == cash + original.contract!.offer.reward)
  #expect(
    game.commander.cargoTonnes == 0 && game.commander.valid && game.scriptCourierAdmission == nil)
  game.emitScriptEvent("dialogue.confirmed", only: id)
  #expect(game.commander.credits == cash + original.contract!.offer.reward)
}

@Test func courierAbandonmentRequiresOriginConfirmationAndPaysNothing() throws {
  let fixture = try CourierFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let id = try fixture.accept(&game, variant: .package)
  try fixture.requestContact(&game, id: id)
  #expect(game.courierContactActionLabel == "Abandon")
  let before = game.commander
  game.key("escape")
  #expect(game.commander == before)
  try fixture.requestContact(&game, id: id)
  game.key("left")
  game.key("return")
  #expect(game.commander.scriptState.instances[id]?.outcome == .abandoned)
  #expect(game.commander.scriptState.instances[id]?.courier?.terminal?.amount == 0)
  #expect(
    game.commander.cargoTonnes == 0 && game.commander.credits == before.credits
      && game.commander.valid)
}

@Test func courierCannotIssueFromDelayedOrMissingAcceptedCommand() throws {
  let fixture = try CourierFixture(scriptEdit: {
    $0.replacingOccurrences(of: "{op = \"courier.issue\", id = \"issue-consignment\"}", with: "")
  })
  defer { fixture.clean() }
  var game = fixture.game()
  let (key, offer) = try fixture.offer(&game)
  let before = game.commander
  #expect(throws: MissionPackError.self) { try game.acceptContract(board: key, offer: offer.id) }
  #expect(game.commander == before && game.scriptCourierAdmission == nil)
}

@Test func courierOneTonneUsesRealHoldAndDataNeedsNoSpareTonne() throws {
  let fixture = try CourierFixture()
  defer { fixture.clean() }
  for variant in [ScriptCourierVariant.data, .package] {
    var game = fixture.game()
    game.commander.cargo[0] = game.commander.standardCargoCapacity
    let (key, offer) = try fixture.usable(&game)
    let board = try #require(game.commander.contracts.boards[key])
    let selected = try #require(
      board.offers.first {
        $0.courier?.variant == variant && $0.courier!.calendarLowerBoundSeconds < $0.duration
      })
    let quote = game.contractAcceptanceQuote(board: key, offer: selected.id)
    #expect(quote.allowed == (variant == .data))
    if variant == .data {
      _ = try game.confirmContract(quote)
    } else {
      game.commander.cargo[0] -= 1
      let exact = game.contractAcceptanceQuote(board: key, offer: selected.id)
      #expect(exact.allowed)
      _ = try game.confirmContract(exact)
    }
    #expect(
      game.commander.cargoTonnes == game.commander.standardCargoCapacity && game.commander.valid)
    #expect(offer.courier != nil)
  }
}
