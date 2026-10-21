import Foundation
import Testing

@testable import EliteCore

struct ScriptFinanceTestFixture {
  let storage: NativeStationTestStorage
  let pack: ScriptPack
  init(edits: [(String, String)] = [], example: String = "finance-obligation") throws {
    storage = try NativeStationTestStorage()
    let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/" + example)
    let target = storage.root.appendingPathComponent("pack")
    do {
      try FileManager.default.copyItem(at: source, to: target)
      let manifest = target.appendingPathComponent("manifest.toml")
      var text = try String(contentsOf: manifest, encoding: .utf8)
      for (old, new) in edits { text = text.replacingOccurrences(of: old, with: new) }
      try text.write(to: manifest, atomically: true, encoding: .utf8)
      pack = try ScriptPackLibrary.read(target)
    } catch {
      storage.clean()
      throw error
    }
  }
  func runtime(credits: Int = 1000) async throws -> GameRuntime {
    let terms = try #require(pack.manifest.loans?.first)
    var game = Game(executive: false)
    game.commander.galaxy = terms.galaxy
    game.commander.system = terms.system
    game.systems = Universe.systemsIncludingPlugh(number: terms.galaxy)
    game.selectedSystem = terms.system
    game.screen = .status
    game.scriptPacks = [pack]
    game.commander.credits = credits
    game.launch()
    try #require(!game.docked && game.commander.valid)
    game.market[0].quantity = 10
    try #require(game.commander.originalMarkets.valid)
    try Self.approachMain(&game)
    let runtime = GameRuntime(game: game, saveURL: storage.url)
    try await Self.enterMain(runtime)
    await runtime.key("contacts-open")
    try #require(await runtime.snapshot().scriptAvailablePackDigest == pack.digest)
    await runtime.key("return")
    try #require(await runtime.snapshot().commander.scriptState.financeLedger?.records.count == 1)
    try #require(await runtime.snapshot().commander.valid)
    return runtime
  }
  static func approachMain(_ game: inout Game) throws {
    let station = try #require(game.bodies.first { $0.id == 0 })
    let old = game.commander.flightSimulation.pose
    var pose = ShipPose()
    pose.position = old.systemPoint(station.entrancePosition + station.entranceNormal * 2)
    pose.orientation.y = old.orientation.apply(station.entranceUp)
    pose.orientation.z = old.orientation.apply(station.entranceNormal) * -1
    pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
    NativeStationTestFixture.reframe(&game, to: pose)
    game.speed = 3
  }
  static func enterMain(_ runtime: GameRuntime) async throws {
    for _ in 0..<100 {
      if await runtime.snapshot().docked { break }
      _ = await runtime.advance(delta: 0.05)
    }
    let game = await runtime.snapshot()
    try #require(game.docked && game.dockedAtMainStation)
    let receipt = try #require(game.commander.nativeStations?.currentMainDock)
    try #require(game.nativeMainStationArrivalContext(for: receipt.station) != nil)
  }
  static func review(_ runtime: GameRuntime) async throws -> ScriptPagePresentation {
    await runtime.key("contracts-open")
    let game = await runtime.snapshot()
    let index = try #require(game.contractBoard.rows.firstIndex { $0.finance != nil })
    for _ in 0..<abs(index - game.contractBoard.selection) {
      await runtime.key(index < game.contractBoard.selection ? "up" : "down")
    }
    let list = await runtime.snapshot().scriptPagePresentation
    await runtime.scriptPageKey("return", expected: list)
    try #require(await runtime.snapshot().contractBoard.detail)
    return await runtime.snapshot().scriptPagePresentation
  }
  static func confirm(_ runtime: GameRuntime, decline: Bool = false) async throws {
    let page = try await review(runtime)
    await runtime.scriptPageKey("right", expected: page)
    if decline { await runtime.scriptPageKey("right", expected: page) }
    await runtime.scriptPageKey("return", expected: page)
  }
  static func files(_ directory: URL) throws -> [String: Data] {
    let entries = try #require(FileManager.default.enumerator(atPath: directory.path))
    var files: [String: Data] = [:]
    for case let path as String in entries {
      let file = directory.appendingPathComponent(path)
      if try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
        files[path] = try Data(contentsOf: file)
      }
    }
    return files
  }
}

struct ScriptFinanceTests {
  @Test(arguments: [false, true])
  func closedHistoryRemainsReadOnlyWithoutLiveDockOrWriter(paid: Bool) async throws {
    let fixture = try ScriptFinanceTestFixture()
    defer { fixture.storage.clean() }
    let writer = try await fixture.runtime()
    try await ScriptFinanceTestFixture.confirm(writer, decline: !paid)
    if paid { try await ScriptFinanceTestFixture.confirm(writer) }
    var history = await writer.snapshot()
    history.nativeMainStationDockEvidence = nil
    history.scriptPacks = []
    let runtime = GameRuntime(game: history)
    let before = await runtime.snapshot().commander
    let files = try ScriptFinanceTestFixture.files(fixture.storage.directory)
    let page = try await ScriptFinanceTestFixture.review(runtime)
    let shown = await runtime.snapshot()
    let quote = try #require(shown.contractBoard.financeQuote)
    #expect(!shown.scriptDurabilityAvailable && !shown.nativeMainStationDockEvidenceIsCurrent)
    #expect(quote.issues.isEmpty && quote.context == nil)
    #expect(quote.row.operation == nil && !quote.allowed && !quote.canDecline)
    #expect(shown.contractBoard.selected?.reason == nil)
    #expect(shown.financeDetail.contains(where: { $0.contains("Workshop loan") }))
    #expect(shown.financeDetail.contains(where: { $0.contains("Last receipt:") }))
    #expect(
      shown.financeDetail.contains(where: {
        $0.contains(paid ? "Closed history: paid" : "Closed history: declined")
      }))
    _ = Display.contractBoard(shown, width: 768, height: 768)
    await runtime.scriptPageKey("right", expected: page)
    await runtime.scriptPageKey("return", expected: page)
    #expect(await runtime.snapshot().commander == before)
    try await ScriptFinanceTestFixture.confirm(runtime, decline: true)
    #expect(await runtime.snapshot().commander == before)
    #expect(try ScriptFinanceTestFixture.files(fixture.storage.directory) == files)
  }

  @Test(arguments: ["profile", "principal", "duplicate", "capability", "unknown", "system"])
  func unsupportedOrMalformedLoanDeclarationsAreRefused(field: String) throws {
    let edit: (String, String)
    switch field {
    case "profile": edit = ("fixed-principal-v1", "gse-short-balance-close")
    case "principal": edit = ("principal = 2000", "principal = -1")
    case "duplicate":
      edit = (
        "[trial]",
        "[[loans]]\nid = \"workshop\"\nprofile = \"fixed-principal-v1\"\ncreditor = \"example.other\"\ntitle = \"Other\"\nprincipal = 1\ngalaxy = 0\nsystem = 237\n\n[trial]"
      )
    case "capability": edit = ("\"finance-obligations-basic-v2\", ", "")
    case "unknown": edit = ("principal = 2000", "principal = 2000\ninterest = 0.1")
    default: edit = ("system = 237", "system = 257")
    }
    #expect(throws: (any Error).self) { try ScriptFinanceTestFixture(edits: [edit]) }
  }

  @Test(arguments: [-1, 0, 255, 256, 257])
  func declarationsFollowCanonicalSystemBounds(system: Int) {
    let definition = ScriptFinanceDefinition(
      id: "loan", profile: "fixed-principal-v1", creditor: "example.lender", title: "Loan",
      principal: 10, galaxy: 0, system: system)
    #expect(definition.valid == (0...256).contains(system))
  }

  @Test func fullBalanceRefusesBorrowButAllowsAnExactlyOnceNativeDecline() async throws {
    let fixture = try ScriptFinanceTestFixture()
    defer { fixture.storage.clean() }
    let runtime = try await fixture.runtime(credits: 4_294_967_295)
    let page = try await ScriptFinanceTestFixture.review(runtime)
    let before = await runtime.snapshot().commander
    #expect(await runtime.snapshot().contractBoard.financeQuote?.allowed == false)
    #expect(await runtime.snapshot().contractBoard.financeQuote?.canDecline == true)
    await runtime.scriptPageKey("right", expected: page)
    await runtime.scriptPageKey("return", expected: page)
    #expect(await runtime.snapshot().commander == before)
    try await ScriptFinanceTestFixture.confirm(runtime, decline: true)
    let declined = await runtime.snapshot().commander
    #expect(declined.credits == before.credits)
    #expect(declined.scriptState.financeLedger?.records[0].status == .declined)
    #expect(declined.scriptState.financeLedger?.receiptCount == 1)
    await runtime.scriptPageKey("return", expected: page)
    #expect(await runtime.snapshot().commander == declined)
  }
  @Test func nativeBorrowPartialAndFinalRepaymentUseActualMarketResourcesOnce() async throws {
    let fixture = try ScriptFinanceTestFixture()
    defer { fixture.storage.clean() }
    let runtime = try await fixture.runtime(credits: 100)
    let initialGame = await runtime.snapshot()
    let initial = initialGame.commander
    let ask = initialGame.market[0].price
    let bid = initialGame.market[0].bidPrice
    try #require(initial.credits < ask && ask - initial.credits < bid && bid < ask)
    let afterPurchase = initial.credits + 2000 - ask
    let remainingPrincipal = ask - initial.credits
    let page = try await ScriptFinanceTestFixture.review(runtime)
    #expect(await runtime.snapshot().contractBoard.financeQuote?.allowed == true)
    #expect(await runtime.snapshot().contractBoard.quote == nil)
    #expect(await runtime.snapshot().contractBoard.rrsQuote == nil)
    await runtime.scriptPageKey("right", expected: page)
    await runtime.scriptPageKey("return", expected: page)
    let borrowed = await runtime.snapshot().commander
    #expect(
      borrowed.credits == initial.credits + 2000
        && borrowed.scriptState.financeLedger?.records[0].remaining == 2000)
    #expect(borrowed.scriptState.financeLedger?.receiptCount == 1)
    await runtime.scriptPageKey("return", expected: page)
    #expect(await runtime.snapshot().commander == borrowed)
    // Actual native market purchase reduces real cash below the outstanding principal.
    await runtime.key("escape")
    await runtime.key("7")
    await runtime.key("right")
    #expect(await runtime.snapshot().commander.credits == afterPurchase)
    #expect(await runtime.snapshot().commander.cargo[0] == initial.cargo[0] + 1)
    try await ScriptFinanceTestFixture.confirm(runtime)
    let partial = await runtime.snapshot().commander
    #expect(
      partial.credits == 0
        && partial.scriptState.financeLedger?.records[0].remaining == remainingPrincipal)
    #expect(partial.scriptState.financeLedger?.records[0].status == .outstanding)
    #expect(partial.scriptState.financeLedger?.receiptCount == 2)
    await runtime.key("escape")
    await runtime.key("7")
    await runtime.key("left")
    #expect(await runtime.snapshot().commander.credits == bid)
    try await ScriptFinanceTestFixture.confirm(runtime)
    let paid = await runtime.snapshot().commander
    #expect(paid.credits == initial.credits - ask + bid && paid.cargo == initial.cargo)
    #expect(paid.scriptState.financeLedger?.records[0].remaining == 0)
    #expect(paid.scriptState.financeLedger?.records[0].status == .paid)
    #expect(paid.scriptState.financeLedger?.receiptCount == 3 && paid.valid)
    try await ScriptFinanceTestFixture.confirm(runtime)
    #expect(await runtime.snapshot().commander == paid)
  }

  @Test func readHelpBackPaintingAndCompatibilityClickNeverIssuePrincipal() async throws {
    let fixture = try ScriptFinanceTestFixture()
    defer { fixture.storage.clean() }
    let runtime = try await fixture.runtime()
    let before = await runtime.snapshot().commander
    let files = try ScriptFinanceTestFixture.files(fixture.storage.directory)
    _ = try await ScriptFinanceTestFixture.review(runtime)
    for _ in 0..<3 {
      _ = Display.contractBoard(await runtime.snapshot(), width: 768, height: 768)
    }
    let game = await runtime.snapshot()
    let layout = ContractBoardLayout(width: game.viewportWidth, height: game.viewportHeight)
    let bounds = try #require(layout.actions.first { $0.0 == .accept }?.1)
    await runtime.contractClick(
      x: bounds.x + 10, y: bounds.y + 10, expectedOffer: nil, detail: true,
      epoch: game.ecmControl.epoch)
    #expect(await runtime.snapshot().commander == before)
    await runtime.key("k")
    await runtime.key("k")
    await runtime.key("escape")
    #expect(await runtime.snapshot().commander == before)
    #expect(try ScriptFinanceTestFixture.files(fixture.storage.directory) == files)
  }

  @Test(arguments: ["cash", "epoch", "writer", "dock", "parent", "pack", "owner"])
  func changedNativeReviewCannotBorrow(reason: String) async throws {
    let fixture = try ScriptFinanceTestFixture()
    defer { fixture.storage.clean() }
    let runtime = try await fixture.runtime()
    let page = try await ScriptFinanceTestFixture.review(runtime)
    var game = await runtime.snapshot()
    let quote = try #require(game.contractBoard.financeQuote)
    switch reason {
    case "cash": game.commander.credits += 1
    case "epoch": game.invalidateNativeStationAuthority()
    case "writer": game.scriptDurabilityAvailable = false
    case "dock": game.nativeMainStationDockEvidence = nil
    case "parent": game.commander.scriptState.instances.removeAll()
    case "pack": game.scriptPacks = []
    default:
      game.commander.scriptState.financeLedger = .init(owner: UUID())
    }
    let before = game.commander
    #expect(throws: (any Error).self) { try game.confirmFinance(quote) }
    #expect(throws: (any Error).self) { try game.confirmFinance(quote, declining: true) }
    #expect(game.commander == before)
    if reason == "cash" {
      let changed = GameRuntime(game: game, saveURL: fixture.storage.url)
      await changed.scriptPageKey("right", expected: page)
      await changed.scriptPageKey("return", expected: page)
      #expect(await changed.snapshot().commander == before)
    }
  }

  @Test func declinedLoanIsFinalAndRepaymentSurvivesActualParentCompletion() async throws {
    let fixture = try ScriptFinanceTestFixture()
    defer { fixture.storage.clean() }
    let runtime = try await fixture.runtime()
    try await ScriptFinanceTestFixture.confirm(runtime)
    await runtime.key("escape")
    await runtime.key("contacts-open")
    #expect(
      await runtime.snapshot().commander.scriptState.instances.values.first?.outcome == .complete)
    #expect(
      await runtime.snapshot().commander.scriptState.financeLedger?.records[0].status
        == .outstanding)
    try await ScriptFinanceTestFixture.confirm(runtime)
    #expect(
      await runtime.snapshot().commander.scriptState.financeLedger?.records[0].status == .paid)
    let other = try ScriptFinanceTestFixture()
    defer { other.storage.clean() }
    let declined = try await other.runtime()
    try await ScriptFinanceTestFixture.confirm(declined, decline: true)
    let before = await declined.snapshot().commander
    #expect(
      before.credits == 1000 && before.scriptState.financeLedger?.records[0].status == .declined)
    try await ScriptFinanceTestFixture.confirm(declined)
    #expect(await declined.snapshot().commander == before)
  }

  @Test func nativeArithmeticRefusesOverflowZeroRepaymentAndReplayedReceipt() async throws {
    let fixture = try ScriptFinanceTestFixture()
    defer { fixture.storage.clean() }
    let runtime = try await fixture.runtime()
    let game = await runtime.snapshot()
    let ledger = try #require(game.commander.scriptState.financeLedger)
    let record = try #require(ledger.records.first)
    let dock = try #require(game.commander.nativeStations?.currentMainDock)
    let token = UUID()
    #expect(throws: (any Error).self) {
      try ledger.applying(
        .borrow, to: record.id, token: token, cash: 4_294_967_295,
        dock: dock, calendarSeconds: game.commander.scriptState.calendarSeconds,
        epoch: game.nativeStationRuntimeEpoch)
    }
    let borrowed = try ledger.applying(
      .borrow, to: record.id, token: token, cash: 0,
      dock: dock, calendarSeconds: game.commander.scriptState.calendarSeconds,
      epoch: game.nativeStationRuntimeEpoch)
    for operation in [ScriptFinanceOperation.borrow, .repay] {
      #expect(throws: (any Error).self) {
        try borrowed.ledger.applying(
          operation, to: record.id, token: token, cash: 2000,
          dock: dock, calendarSeconds: game.commander.scriptState.calendarSeconds,
          epoch: game.nativeStationRuntimeEpoch)
      }
    }
    #expect(throws: (any Error).self) {
      try borrowed.ledger.applying(
        .repay, to: record.id, token: UUID(), cash: 0,
        dock: dock, calendarSeconds: game.commander.scriptState.calendarSeconds,
        epoch: game.nativeStationRuntimeEpoch)
    }
    #expect(ledger == game.commander.scriptState.financeLedger)
  }
}
