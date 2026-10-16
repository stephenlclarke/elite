import AppKit
import Testing

@testable import EliteCore
@testable import EliteMac

@MainActor func paintPledgeView(_ view: GameView) throws {
  try paintCampaignGalleryView(view)
}

@MainActor func clickPledgeView(_ view: GameView, x: Double, y: Double) throws {
  let point = view.convert(NSPoint(x: x, y: y), to: nil)
  let event = try #require(
    NSEvent.mouseEvent(
      with: .leftMouseDown, location: point,
      modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
      eventNumber: 0, clickCount: 1, pressure: 1))
  view.mouseDown(with: event)
}

@MainActor private func capturePledgeState(_ game: Game, name: String) throws {
  for (width, height, scale) in [(512, 518, 1), (1512, 982, 2)] {
    var shown = game
    shown.viewportWidth = Double(width)
    shown.viewportHeight = Double(height)
    let frame = Display.presentation(shown, width: Double(width), height: Double(height))
    #expect(
      frame.labels.allSatisfy {
        $0.bounds.x >= 0 && $0.bounds.maxX <= Double(width)
          && $0.bounds.y >= 0 && $0.bounds.maxY <= Double(height)
      })
    let image = try #require(imageForGame(shown, width: width, height: height, scale: scale))
    if let path = ProcessInfo.processInfo.environment["ELITE_UI_EVIDENCE_DIRECTORY"] {
      let folder = URL(fileURLWithPath: path)
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let bytes = try #require(
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
      try bytes.write(to: folder.appendingPathComponent("pledge-\(name)-\(width).png"))
    }
  }
}

@MainActor private final class PledgeInputHarness {
  let fixture: PledgeFixture
  let delegate: AppDelegate
  let preferences: UserDefaults
  var view: GameView
  var window: NSWindow?
  let originalMenu: NSMenu?
  init(cash: Int = 100000, food: Int = 5) async throws {
    fixture = try PledgeFixture()
    preferences = try #require(UserDefaults(suiteName: fixture.directory.lastPathComponent))
    delegate = AppDelegate(
      restoreOnLaunch: false,
      saves: CommanderSaveSession(preferences: preferences, defaultURL: fixture.save),
      windowSize: .init(width: 512, height: 518))
    view = GameView(frame: NSRect(x: 0, y: 0, width: 512, height: 518))
    originalMenu = NSApp?.mainMenu
    var game = fixture.game(cash: cash, food: food)
    game.viewportWidth = 512
    game.viewportHeight = 518
    let initial = game
    await delegate.runtime.nativeCommand { @Sendable candidate in candidate = initial }
    try await delegate.runtime.save(to: fixture.save)
  }
  func frame() async throws {
    view.game = await delegate.runtime.snapshot()
    try paintPledgeView(view)
  }
  func press(_ key: String) throws {
    let codes: [String: UInt16] = [
      "return": 36, "escape": 53, "right": 124,
      "left": 123, "up": 126, "down": 125, "tab": 48, "pagedown": 121, "t": 17,
    ]
    let text = key == "return" ? "\r" : key == "escape" ? "\u{1b}" : key.count == 1 ? key : ""
    let keyCode = try #require(codes[key])
    let event = try #require(
      NSEvent.keyEvent(
        with: .keyDown, location: .zero,
        modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
        characters: text, charactersIgnoringModifiers: text, isARepeat: false,
        keyCode: keyCode))
    view.keyDown(with: event)
  }
  func drain() async { await delegate.processPendingCommands(in: view) }
  func review(tier: Int = 1, variant: ScriptPledgeVariant = .credits) async throws {
    await delegate.runtime.key("contracts-open")
    let game = await delegate.runtime.snapshot()
    let index = try #require(
      game.contractBoard.rows.firstIndex {
        $0.offer?.key == variant.rawValue + "-" + String(tier)
      })
    for _ in 0..<index { await delegate.runtime.key("down") }
    await delegate.runtime.key("return")
  }
  func launchMenus() async throws {
    _ = NSApplication.shared
    let before = await delegate.runtime.snapshot()
    delegate.applicationDidFinishLaunching(
      Notification(name: NSApplication.didFinishLaunchingNotification))
    let loop = try #require(delegate.loop)
    loop.cancel()
    await loop.value
    window = delegate.window
    _ = try #require(window)
    view = try #require(window?.contentView as? GameView)
    await delegate.runtime.nativeCommand { @Sendable candidate in candidate = before }
  }
  func clean() {
    delegate.windowWillClose(Notification(name: NSWindow.willCloseNotification))
    window?.orderOut(nil)
    if let originalMenu { NSApp.mainMenu = originalMenu }
    preferences.removePersistentDomain(forName: fixture.directory.lastPathComponent)
    fixture.clean()
  }
}

// AppKit windows and menus are process-wide, so retain the existing serialized suite.
extension NativeViewTests {
  @MainActor @Test func nativePledgeAllSixPaintedReviewsDonateOnceWithDefaultBack() async throws {
    for tier in 1...3 {
      for variant in [ScriptPledgeVariant.credits, .food] {
        let harness = try await PledgeInputHarness()
        defer { harness.clean() }
        try await harness.review(tier: tier, variant: variant)
        try await harness.frame()
        let before = harness.view.game.commander
        let quote = try #require(harness.view.game.contractBoard.quote)
        let pledge = try #require(quote.pledge)
        #expect(harness.view.game.contractBoard.action == .back)
        #expect(
          Display.contractBoard(harness.view.game, width: 512, height: 518).labels.contains {
            $0.text == "  Donate"
          })
        try harness.press("right")
        try harness.press("return")
        try harness.press("return")
        await harness.drain()
        let completed = await harness.delegate.runtime.snapshot()
        #expect(completed.commander.valid)
        #expect(completed.commander.scriptState.instances.count == 1)
        #expect(completed.commander.scriptState.pledgeLedger?.receipts.count == 1)
        #expect(
          completed.commander.credits == before.credits - (variant == .credits ? pledge.amount : 0))
        #expect(
          completed.commander.cargo[Game.pledgeFood] == before.cargo[Game.pledgeFood]
            - (variant == .food ? pledge.amount : 0))
        let loaded = GameRuntime(game: harness.fixture.game())
        try await loaded.load(from: harness.fixture.save)
        #expect(await loaded.snapshot().commander == completed.commander)
      }
    }
  }

  @MainActor @Test func nativePledgeUnseenDetailAndStaleResourceOrGeometryCannotDonate()
    async throws
  {
    let harness = try await PledgeInputHarness()
    defer { harness.clean() }
    await harness.delegate.runtime.key("contracts-open")
    try await harness.frame()
    await harness.delegate.runtime.key("return")
    harness.view.game = await harness.delegate.runtime.snapshot()
    let before = harness.view.game.commander
    try harness.press("right")
    try harness.press("return")
    await harness.drain()
    #expect(await harness.delegate.runtime.snapshot().commander == before)
    try await harness.frame()
    let painted = harness.view.game.scriptPagePresentation
    await harness.delegate.runtime.nativeCommand { @Sendable game in game.commander.credits -= 1 }
    harness.view.game = await harness.delegate.runtime.snapshot()
    try harness.press("right")
    try harness.press("return")
    await harness.drain()
    #expect(await harness.delegate.runtime.snapshot().commander.scriptState.pledgeLedger == nil)
    await harness.delegate.runtime.scriptPageKey("right", expected: painted)
    await harness.delegate.runtime.scriptPageKey("return", expected: painted)
    #expect(await harness.delegate.runtime.snapshot().commander.scriptState.instances.isEmpty)
    try await harness.frame()
    harness.view.setFrameSize(NSSize(width: 1512, height: 982))
    try clickPledgeView(harness.view, x: 40, y: 932)
    await harness.drain()
    #expect(await harness.delegate.runtime.snapshot().commander.scriptState.pledgeLedger == nil)
    // A paint at new view bounds before the actor viewport changes must also reject.
    try paintPledgeView(harness.view)
    try clickPledgeView(harness.view, x: 40, y: 932)
    await harness.drain()
    #expect(await harness.delegate.runtime.snapshot().commander.scriptState.pledgeLedger == nil)
    await harness.delegate.runtime.setViewport(width: 1512, height: 982)
    await harness.delegate.runtime.key("contract-refresh")
    await harness.delegate.runtime.key("return")
    try await harness.frame()
    let action = try #require(
      ContractBoardLayout(width: 1512, height: 982).actions.first { $0.0 == .accept }?.1)
    try clickPledgeView(harness.view, x: action.x + 8, y: action.y + 8)
    try clickPledgeView(harness.view, x: action.x + 8, y: action.y + 8)
    await harness.drain()
    #expect(
      await harness.delegate.runtime.snapshot().commander.scriptState.pledgeLedger?.receipts.count
        == 1)
  }

  @MainActor @Test func nativePledgeRawMalformedOldEpochAndMenuPacketsDoNotBorrowReviews()
    async throws
  {
    let harness = try await PledgeInputHarness()
    defer { harness.clean() }
    try await harness.launchMenus()
    await harness.delegate.runtime.key("gallery-open")
    try await harness.frame()
    let menu = try #require(NSApp.mainMenu?.item(withTitle: "Game")?.submenu)
    let item = try #require(
      menu.items.firstIndex { ($0.representedObject as? String) == "contracts-open" })
    menu.performActionForItem(at: item)
    try harness.press("return")
    try harness.press("right")
    try harness.press("return")
    await harness.drain()
    #expect(await harness.delegate.runtime.snapshot().screen == .contracts)
    #expect(await harness.delegate.runtime.snapshot().commander.scriptState.instances.isEmpty)
    try await harness.review()
    try await harness.frame()
    let before = harness.view.game.commander
    let proof = harness.view.game.scriptPagePresentation
    let data = try JSONEncoder().encode(proof)
    #expect(data.count <= 1024)
    let token = data.base64EncodedString()
    #expect(token.utf8.count <= 1400)
    harness.view.pending = [
      "contract-click:\(proof.epoch):none:1:40:460", "contract-scroll:1",
      "script-page-click:%%%:40:460", "script-page-key:%%%:return",
      "script-page-key:" + String(repeating: "A", count: 1401) + ":return",
      "script-page-click:" + token + ":nan:460",
      "script-page-key:" + token + ":trial-return",
      "script-page-key:" + token + ":commander-save-default",
    ]
    await harness.drain()
    #expect(await harness.delegate.runtime.snapshot().commander == before)
    try await harness.delegate.runtime.save(to: harness.fixture.save)
    try await harness.delegate.runtime.load(from: harness.fixture.save, persistMigrations: false)
    await harness.delegate.runtime.scriptPageKey("right", expected: proof)
    await harness.delegate.runtime.scriptPageKey("return", expected: proof)
    #expect(await harness.delegate.runtime.snapshot().commander == before)
    #expect(await harness.delegate.runtime.snapshot().contractBoard.action == .back)
  }

  @MainActor @Test func nativePledgeCompactAndRetinaTermsScrollAndRetainRealContext() async throws {
    let harness = try await PledgeInputHarness()
    defer { harness.clean() }
    try await harness.review(tier: 3, variant: .food)
    let before = await harness.delegate.runtime.snapshot().commander
    for (width, height, scale) in [(512, 518, 1), (1512, 982, 2)] {
      await harness.delegate.runtime.setViewport(width: Double(width), height: Double(height))
      let game = await harness.delegate.runtime.snapshot()
      let frame = Display.contractBoard(game, width: Double(width), height: Double(height))
      #expect(
        frame.labels.allSatisfy {
          $0.bounds.x >= 0 && $0.bounds.maxX <= Double(width)
            && $0.bounds.y >= 0 && $0.bounds.maxY <= Double(height)
        })
      let image = try #require(imageForGame(game, width: width, height: height, scale: scale))
      #expect(image.width == width * scale && image.height == height * scale)
      if let path = ProcessInfo.processInfo.environment["ELITE_UI_EVIDENCE_DIRECTORY"] {
        let folder = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let bytes = try #require(
          NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try bytes.write(to: folder.appendingPathComponent("pledge-food-review-\(width).png"))
      }
      await harness.delegate.runtime.key("pagedown")
      #expect(await harness.delegate.runtime.snapshot().contractBoard.scroll > 0 || width == 1512)
    }
    #expect(await harness.delegate.runtime.snapshot().commander == before)
  }

  @MainActor @Test func nativePledgeRealTrialPaintSaveAndReturnPreserveLivePreferences()
    async throws
  {
    let harness = try await PledgeInputHarness()
    defer { harness.clean() }
    try await harness.review()
    try await harness.frame()
    try capturePledgeState(harness.view.game, name: "credit-review")
    try harness.press("right")
    try harness.press("return")
    await harness.drain()
    let live = await harness.delegate.runtime.snapshot().commander
    let bytes = try Data(contentsOf: harness.fixture.save)
    let preferences =
      harness.preferences.persistentDomain(forName: harness.fixture.directory.lastPathComponent)
      ?? [:]
    let activeURL = harness.delegate.saves.activeURL
    await harness.delegate.runtime.key("gallery-open")
    let gallery = await harness.delegate.runtime.snapshot()
    let savedIndex = try #require(
      gallery.missionCatalogue.firstIndex {
        $0.savedInstance != nil && $0.name.contains("Station Aid")
      })
    for _ in 0..<savedIndex { await harness.delegate.runtime.key("down") }
    await harness.delegate.runtime.key("return")
    try capturePledgeState(await harness.delegate.runtime.snapshot(), name: "completed-receipt")
    await harness.delegate.runtime.key("pagedown")
    try capturePledgeState(
      await harness.delegate.runtime.snapshot(), name: "completed-receipt-scrolled")
    let providerIndex = try #require(
      gallery.missionCatalogue.firstIndex {
        $0.savedInstance == nil && $0.trialDigest == harness.fixture.pack.digest
      })
    await harness.delegate.runtime.nativeCommand { @Sendable game in
      game.gallery.selection = providerIndex
      game.gallery.detail = true
      game.pinGallerySelection()
    }
    try await harness.frame()
    try harness.press("t")
    await harness.drain()
    let trial = await harness.delegate.runtime.snapshot()
    let namespace = try #require(await harness.delegate.runtime.gallerySaveDirectory())
    defer { try? FileManager.default.removeItem(at: namespace) }
    #expect(trial.isMissionTrial && trial.commander.scriptState.instances.isEmpty)
    #expect(trial.commander.scriptState.pledgeLedger == nil && trial.contractBoard.action == .back)
    try capturePledgeState(trial, name: "trial-review")
    try await harness.frame()
    #expect(
      Display.contractBoard(harness.view.game, width: 512, height: 518).labels.contains {
        $0.text == "Trial - live commander unchanged"
      })
    try harness.press("right")
    try harness.press("return")
    await harness.drain()
    harness.view.pending = ["commander-save-default"]
    await harness.drain()
    let donated = await harness.delegate.runtime.snapshot()
    #expect(donated.commander.scriptState.pledgeLedger?.receipts.count == 1)
    _ = try await harness.delegate.runtime.loadForInterface(expectedEpoch: donated.ecmControl.epoch)
    #expect(await harness.delegate.runtime.snapshot().commander == donated.commander)
    try await harness.delegate.runtime.restartScriptGalleryTrial()
    #expect(await harness.delegate.runtime.snapshot().commander.scriptState.pledgeLedger == nil)
    try await harness.delegate.runtime.returnFromScriptGalleryTrial()
    #expect(await harness.delegate.runtime.snapshot().commander == live)
    #expect(try Data(contentsOf: harness.fixture.save) == bytes)
    #expect(harness.delegate.saves.activeURL == activeURL)
    #expect(
      NSDictionary(
        dictionary: harness.preferences.persistentDomain(
          forName: harness.fixture.directory.lastPathComponent) ?? [:]
      ).isEqual(to: preferences))
  }

  @MainActor @Test func nativePledgeUnavailableFullTermsRemainReadableWithoutResources()
    async throws
  {
    let harness = try await PledgeInputHarness(cash: 0, food: 0)
    defer { harness.clean() }
    try await harness.review(tier: 3, variant: .food)
    try await harness.frame()
    let before = harness.view.game.commander
    #expect(harness.view.game.contractBoard.quote?.allowed == false)
    #expect(harness.view.game.contractBoard.quote?.pledge?.amount == 5)
    try capturePledgeState(harness.view.game, name: "unavailable-food")
    try harness.press("right")
    try harness.press("return")
    await harness.drain()
    #expect(await harness.delegate.runtime.snapshot().commander == before)
  }
}
