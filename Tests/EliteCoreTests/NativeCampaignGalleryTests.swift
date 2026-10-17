import AppKit
import Testing

@testable import EliteCore
@testable import EliteMac

// Join the existing serialized native suite; AppKit menus and windows are process-wide.
extension NativeViewTests {
  @MainActor @Test func nativeGalleryWheelRequiresCurrentPaintAndPreservesLinkSelectionSemantics()
    async throws
  {
    let harness = try await CampaignGalleryInputHarness()
    defer { harness.clean() }
    try await harness.selectChild()
    await harness.delegate.runtime.nativeCommand { game in
      game.gallery.campaignLinks = true
      game.gallery.campaignLinkSelection = 1
    }
    harness.view.game = await harness.delegate.runtime.snapshot()
    try #require(harness.view.game.campaignGalleryLinks.count >= 2)
    let downCG = try #require(
      CGEvent(
        scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: -1, wheel2: 0, wheel3: 0)
    )
    let down = try #require(NSEvent(cgEvent: downCG))
    harness.view.scrollWheel(with: down)
    #expect(harness.view.pending.isEmpty)

    try await harness.frame()
    let captured = try #require(harness.view.paintedMissionMenuPresentation)
    let upCG = try #require(
      CGEvent(
        scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: 1, wheel2: 0, wheel3: 0))
    let up = try #require(NSEvent(cgEvent: upCG))
    harness.view.scrollWheel(with: up)
    try #require(harness.view.pending.last?.hasPrefix("script-page-gallery-scroll:") == true)
    var differentPage = await harness.delegate.runtime.snapshot()
    let second = try #require(harness.second)
    try harness.fixture.select(second.1, game: &differentPage)
    differentPage.gallery.campaignLinks = true
    differentPage.gallery.campaignLinkSelection = 1
    let configured = differentPage
    await harness.delegate.runtime.nativeCommand { game in game = configured }
    let changed = await harness.delegate.runtime.snapshot()
    try #require(captured != changed.scriptPagePresentation)
    var unguarded = changed
    unguarded.key("gallery-scroll:-1")
    try #require(unguarded.gallery.campaignLinkSelection == 0)
    await harness.drain()
    #expect(await harness.delegate.runtime.snapshot().gallery.campaignLinkSelection == 1)
    harness.view.setFrameSize(.init(width: 768, height: 768))
    harness.view.scrollWheel(with: down)
    #expect(harness.view.pending.isEmpty)

    await harness.delegate.runtime.setViewport(width: 768, height: 768)
    try await harness.frame()
    harness.view.scrollWheel(with: up)
    await harness.drain()
    #expect(await harness.delegate.runtime.snapshot().gallery.campaignLinkSelection == 0)
    harness.view.pending.append("gallery-scroll:1")
    await harness.drain()
    #expect(await harness.delegate.runtime.snapshot().gallery.campaignLinkSelection == 0)
  }

  @MainActor @Test func nativeCampaignGalleryRendersRelationshipsAndTrialReviewAtBothSizes() throws
  {
    let fixture = try CampaignGalleryFixture()
    defer { fixture.clean() }
    var game = fixture.game()
    let (parent, child) = try fixture.start(&game)
    let before = game.commander
    for (width, height, scale) in [(512, 518, 1), (1512, 982, 2)] {
      game.viewportWidth = Double(width)
      game.viewportHeight = Double(height)
      for (name, id) in [("parent", parent), ("child", child)] {
        try fixture.select(id, game: &game)
        game.gallery.campaignLinks = false
        game.gallery.scroll = 0
        try capture(game, name: name, width: width, height: height, scale: scale)
        game.key("pagedown")
        #expect(game.gallery.scroll > 0 || width == 1512)
        if game.gallery.scroll > 0 {
          try capture(game, name: name + "-scrolled", width: width, height: height, scale: scale)
        }
        game.key("return")
        try capture(game, name: name + "-links", width: width, height: height, scale: scale)
      }
      game.openCampaignTrialReview()
      #expect(game.gallery.campaignReview?.root == parent)
      #expect(!game.gallery.campaignStartSelected)
      try capture(game, name: "root-review", width: width, height: height, scale: scale)
      game.key("escape")
    }
    #expect(game.commander == before)
  }

  @MainActor private func capture(
    _ game: Game, name: String, width: Int, height: Int, scale: Int
  ) throws {
    let frame = Display.gallery(game, width: Double(width), height: Double(height))
    #expect(
      frame.labels.allSatisfy {
        $0.bounds.x >= 0 && $0.bounds.maxX <= Double(width)
          && $0.bounds.y >= 0 && $0.bounds.maxY <= Double(height)
      })
    let image = try #require(imageForGame(game, width: width, height: height, scale: scale))
    #expect(image.width == width * scale && image.height == height * scale)
    if let path = ProcessInfo.processInfo.environment["ELITE_UI_EVIDENCE_DIRECTORY"] {
      let directory = URL(fileURLWithPath: path, isDirectory: true)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let bytes = try #require(
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
      try bytes.write(to: directory.appendingPathComponent("campaign-gallery-\(name)-\(width).png"))
    }
  }
}

@MainActor
func paintCampaignGalleryView(_ view: GameView) throws {
  let bitmap = try #require(
    NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: Int(view.bounds.width),
      pixelsHigh: Int(view.bounds.height),
      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
  let context = try #require(NSGraphicsContext(bitmapImageRep: bitmap))
  NSGraphicsContext.saveGraphicsState()
  defer { NSGraphicsContext.restoreGraphicsState() }
  NSGraphicsContext.current = context
  view.draw(view.bounds)
}

@MainActor
private final class CampaignGalleryInputHarness {
  let fixture: CampaignGalleryFixture
  let first: (UUID, UUID)
  let second: (UUID, UUID)?
  let preferences: UserDefaults
  let delegate: AppDelegate
  var view: GameView
  var window: NSWindow?
  let originalMenu: NSMenu?

  init(retryFault: Bool = false, contractRoot: Bool = false) async throws {
    fixture = try CampaignGalleryFixture(parentOnly: contractRoot, retryFault: retryFault)
    preferences = try #require(UserDefaults(suiteName: fixture.directory.lastPathComponent))
    delegate = AppDelegate(
      restoreOnLaunch: false,
      saves: CommanderSaveSession(preferences: preferences, defaultURL: fixture.save),
      windowSize: .init(width: 512, height: 518))
    view = GameView(frame: NSRect(x: 0, y: 0, width: 512, height: 518))
    originalMenu = NSApp?.mainMenu
    var game = fixture.game()
    if contractRoot {
      let campaign = try fixture.startContractCampaign(&game)
      first = (campaign.root, campaign.child)
      second = nil
    } else {
      first = try fixture.start(&game)
      second = try fixture.start(&game, parent: fixture.parents[1])
    }
    game.viewportWidth = 512
    game.viewportHeight = 518
    let configured = game
    await delegate.runtime.nativeCommand { @Sendable candidate in candidate = configured }
    try await delegate.runtime.save(to: fixture.save)
  }

  func selectChild() async throws {
    var game = await delegate.runtime.snapshot()
    try fixture.select(first.1, game: &game)
    let selected = game
    await delegate.runtime.nativeCommand { @Sendable candidate in candidate = selected }
  }

  func frame() async throws {
    view.game = await delegate.runtime.snapshot()
    try paintCampaignGalleryView(view)
  }

  func press(_ key: String) throws {
    let codes: [String: UInt16] = [
      "return": 36, "down": 125, "up": 126, "escape": 53, "t": 17, "r": 15, "l": 37,
    ]
    let text = key == "return" ? "\r" : key == "escape" ? "\u{1b}" : key.count == 1 ? key : ""
    let event = try #require(
      NSEvent.keyEvent(
        with: .keyDown, location: .zero,
        modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
        characters: text, charactersIgnoringModifiers: text, isARepeat: false,
        keyCode: codes[key] ?? 0))
    view.keyDown(with: event)
  }

  func click(x: Double, y: Double) throws {
    let point = view.convert(NSPoint(x: x, y: y), to: nil)
    let event = try #require(
      NSEvent.mouseEvent(
        with: .leftMouseDown, location: point,
        modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
        eventNumber: 0, clickCount: 1, pressure: 1))
    view.mouseDown(with: event)
  }

  func clickStart() throws {
    try click(x: view.bounds.width * 0.75, y: view.bounds.height - 65)
  }

  func drain() async { await delegate.processPendingCommands(in: view) }

  func launchMenus() async throws {
    _ = NSApplication.shared
    let before = await delegate.runtime.snapshot()
    delegate.applicationDidFinishLaunching(
      Notification(name: NSApplication.didFinishLaunchingNotification))
    let loop = try #require(delegate.loop)
    loop.cancel()
    await loop.value
    let activeWindow = try #require(delegate.window)
    window = activeWindow
    view = try #require(activeWindow.contentView as? GameView)
    await delegate.runtime.nativeCommand { @Sendable candidate in candidate = before }
  }

  func menuItem(_ command: String) throws -> (NSMenu, Int) {
    let menu = try #require(NSApp.mainMenu?.item(withTitle: "Game")?.submenu)
    let index = try #require(menu.items.firstIndex { ($0.representedObject as? String) == command })
    return (menu, index)
  }

  func clean() {
    delegate.windowWillClose(Notification(name: NSWindow.willCloseNotification))
    window?.orderOut(nil)
    if let originalMenu { NSApp.mainMenu = originalMenu }
    preferences.removePersistentDomain(forName: fixture.directory.lastPathComponent)
    fixture.clean()
  }
}

extension NativeViewTests {
  @MainActor @Test func nativeCampaignGallerySavedContractChildRefusesKeyboardMenuAndPointerTrial()
    async throws
  {
    let harness = try await CampaignGalleryInputHarness(contractRoot: true)
    defer { harness.clean() }
    try await harness.launchMenus()
    try await harness.selectChild()
    try await harness.frame()
    let before = harness.view.game
    let bytes = try Data(contentsOf: harness.fixture.save)
    #expect(before.commander.valid)
    #expect(before.campaignTrialRoot?.id == harness.first.0)
    #expect(before.campaignImmediateOwner == harness.first.0)
    #expect(before.campaignTrialReview == nil && !before.canReviewSelectedCampaignTrial)
    #expect(
      before.campaignTrialUnavailableReason
        == "Trials of saved contract assignments are not supported.")
    let (menu, trialIndex) = try harness.menuItem("gallery-trial")
    let trialTarget = try #require(menu.items[trialIndex].target as? NativeMissionMenu)
    #expect(!trialTarget.validateMenuItem(menu.items[trialIndex]))
    // Even a queued menu command must fail closed against this actual painted page.
    harness.view.enqueueGalleryCommand("gallery-trial")
    try harness.press("t")
    await harness.drain()
    #expect(await harness.delegate.runtime.snapshot().gallery.campaignReview == nil)
    try await harness.frame()
    try harness.press("return")
    await harness.drain()
    await harness.delegate.runtime.nativeCommand { @Sendable game in
      game.message = "Awaiting pointer"
    }
    try await harness.frame()
    #expect(harness.view.game.gallery.campaignLinks)
    #expect(harness.view.game.campaignGalleryLinks[1].title == "Try campaign")
    let layout = GalleryLayout(width: 512, height: 518)
    try harness.click(x: 20, y: layout.listTop + layout.linkHeight + 1)
    await harness.drain()
    let refused = await harness.delegate.runtime.snapshot()
    #expect(refused.message == "Trials of saved contract assignments are not supported.")
    #expect(refused.gallery.campaignReview == nil && !refused.isMissionTrial)
    #expect(refused.ecmControl.epoch == before.ecmControl.epoch)
    #expect(refused.commander == before.commander)
    #expect(await harness.delegate.runtime.gallerySaveDirectory() == nil)
    #expect(try Data(contentsOf: harness.fixture.save) == bytes)
    try await harness.frame()
    try harness.press("up")
    try harness.press("return")
    await harness.drain()
    #expect(
      await harness.delegate.runtime.snapshot().selectedGalleryMission?.savedInstance
        == harness.first.0)
    #expect(await harness.delegate.runtime.snapshot().commander == before.commander)
    #expect(try Data(contentsOf: harness.fixture.save) == bytes)
  }

  @MainActor @Test func nativeCampaignGalleryRejectsUnseenPagesAndConfirmsOnePaintedReview()
    async throws
  {
    let harness = try await CampaignGalleryInputHarness()
    defer { harness.clean() }
    try await harness.frame()
    try await harness.selectChild()
    harness.view.game = await harness.delegate.runtime.snapshot()
    let before = harness.view.game.commander
    try harness.press("t")
    await harness.drain()
    #expect(await harness.delegate.runtime.snapshot().gallery.campaignReview == nil)
    try await harness.frame()
    try harness.press("t")
    try harness.press("return")
    await harness.drain()
    #expect(
      await harness.delegate.runtime.snapshot().gallery.campaignReview?.root == harness.first.0)
    #expect(await harness.delegate.runtime.gallerySaveDirectory() == nil)
    harness.view.game = await harness.delegate.runtime.snapshot()
    try harness.clickStart()
    await harness.drain()
    #expect(await harness.delegate.runtime.gallerySaveDirectory() == nil)
    try await harness.frame()
    try harness.press("down")
    try harness.press("return")
    try harness.press("return")
    await harness.drain()
    let namespace = try #require(await harness.delegate.runtime.gallerySaveDirectory())
    defer { try? FileManager.default.removeItem(at: namespace) }
    let trial = await harness.delegate.runtime.snapshot()
    #expect(trial.isMissionTrial && trial.trialDigest == harness.fixture.parents[0].digest)
    #expect(trial.commander.scriptState.instances.count == 2)
    await harness.delegate.runtime.key("gallery-open")
    let rootIndex = try #require(
      trial.missionCatalogue.firstIndex {
        $0.trialDigest == harness.fixture.parents[0].digest
      })
    for _ in 0..<rootIndex { await harness.delegate.runtime.key("down") }
    await harness.delegate.runtime.key("return")
    try await harness.frame()
    let trialFrame = Display.gallery(harness.view.game, width: 512, height: 518)
    #expect(trialFrame.labels.contains { $0.text == "Trial - live commander unchanged" })
    try capture(harness.view.game, name: "trial-context", width: 512, height: 518, scale: 1)
    await harness.delegate.runtime.key("trial-return")
    #expect(await harness.delegate.runtime.snapshot().commander == before)
    harness.view.game = await harness.delegate.runtime.snapshot()
    try harness.press("down")
    try harness.press("return")
    await harness.drain()
    #expect(await harness.delegate.runtime.gallerySaveDirectory() == nil)
  }

  @MainActor @Test func nativeCampaignGalleryPointerConfirmationUsesItsPaintedTargetOnce()
    async throws
  {
    let harness = try await CampaignGalleryInputHarness()
    defer { harness.clean() }
    try await harness.selectChild()
    try await harness.frame()
    let bytes = try Data(contentsOf: harness.fixture.save)
    try harness.press("t")
    await harness.drain()
    try await harness.frame()
    try harness.clickStart()
    try harness.clickStart()
    await harness.drain()
    let namespace = try #require(await harness.delegate.runtime.gallerySaveDirectory())
    defer { try? FileManager.default.removeItem(at: namespace) }
    #expect(
      await harness.delegate.runtime.snapshot().trialDigest == harness.fixture.parents[0].digest)
    #expect(try Data(contentsOf: harness.fixture.save) == bytes)
    await harness.delegate.runtime.key("trial-return")
    #expect(try Data(contentsOf: harness.fixture.save) == bytes)
  }

  @MainActor @Test func nativeCampaignGalleryRejectsScrolledResizedReloadedAndReorderedControls()
    async throws
  {
    let harness = try await CampaignGalleryInputHarness()
    defer { harness.clean() }
    try await harness.selectChild()
    try await harness.frame()
    await harness.delegate.runtime.key("down")
    harness.view.game = await harness.delegate.runtime.snapshot()
    try harness.click(x: 20, y: 453)
    await harness.drain()
    #expect(await harness.delegate.runtime.snapshot().gallery.campaignLinks == false)
    try await harness.frame()
    await harness.delegate.runtime.setViewport(width: 1512, height: 982)
    harness.view.setFrameSize(NSSize(width: 1512, height: 982))
    harness.view.game = await harness.delegate.runtime.snapshot()
    try harness.click(x: 540, y: 917)
    await harness.drain()
    #expect(await harness.delegate.runtime.snapshot().gallery.campaignLinks == false)
    try await harness.frame()
    let old = harness.view.game.scriptPagePresentation
    let unavailableDigest = harness.fixture.parents[1].digest
    await harness.delegate.runtime.nativeCommand { @Sendable game in
      game.scriptPacks.removeAll { $0.digest == unavailableDigest }
    }
    harness.view.game = await harness.delegate.runtime.snapshot()
    try harness.press("t")
    await harness.drain()
    #expect(await harness.delegate.runtime.snapshot().gallery.campaignReview == nil)
    #expect(
      await harness.delegate.runtime.snapshot().selectedGalleryMission?.savedInstance
        == harness.first.1)
    #expect(await harness.delegate.runtime.snapshot().scriptPagePresentation != old)
    try await harness.delegate.runtime.load(from: harness.fixture.save, persistMigrations: false)
    await harness.delegate.runtime.scriptPageKey("t", expected: old)
    #expect(await harness.delegate.runtime.gallerySaveDirectory() == nil)
  }

  @MainActor @Test func nativeCampaignGalleryMalformedAndUnscopedPacketsHaveNoFallback()
    async throws
  {
    let harness = try await CampaignGalleryInputHarness()
    defer { harness.clean() }
    try await harness.selectChild()
    try await harness.frame()
    let before = harness.view.game.commander
    let bytes = try JSONEncoder().encode(harness.view.game.scriptPagePresentation)
    try #require(bytes.count < 1024)
    let token = bytes.base64EncodedString()
    let padded = (Data(repeating: 32, count: 1025 - bytes.count) + bytes).base64EncodedString()
    #expect(padded.utf8.count <= 1400)
    var malformed = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    var page = try #require(malformed["page"] as? [String: Any])
    var gallery = try #require(page["gallery"] as? [String: Any])
    var payload = try #require(gallery["_0"] as? [String: Any])
    payload["mode"] = "unknown"
    gallery["_0"] = payload
    page["gallery"] = gallery
    malformed["page"] = page
    let unknown = try JSONSerialization.data(withJSONObject: malformed).base64EncodedString()
    harness.view.pending = [
      "script-page-key:%%%:t", "script-page-click:%%%:1:1",
      "script-page-key:" + String(repeating: "A", count: 1401) + ":t",
      "script-page-key:" + padded + ":t", "script-page-key:" + unknown + ":t",
      "script-page-key:" + token + ":t:extra",
      "script-page-key:" + token + ":trial-return",
      "script-page-key:" + token + ":commander-save-default",
      "script-page-click:" + token + ":nan:453", "script-page-click:" + token + ":1:inf",
      "script-page-click:" + token + ":1", "gallery-click:400:453",
    ]
    await harness.drain()
    #expect(await harness.delegate.runtime.snapshot().commander == before)
    #expect(await harness.delegate.runtime.snapshot().gallery.campaignReview == nil)
    #expect(await harness.delegate.runtime.gallerySaveDirectory() == nil)
  }

  @MainActor @Test func nativeCampaignGalleryMenusUseTheSamePaintedTrialAndRetryProofs()
    async throws
  {
    let harness = try await CampaignGalleryInputHarness(retryFault: true)
    defer { harness.clean() }
    try await harness.launchMenus()
    try await harness.frame()
    try await harness.selectChild()
    harness.view.game = await harness.delegate.runtime.snapshot()
    let (menu, trialIndex) = try harness.menuItem("gallery-trial")
    let trialTarget = try #require(menu.items[trialIndex].target as? NativeMissionMenu)
    #expect(!trialTarget.validateMenuItem(menu.items[trialIndex]))
    menu.performActionForItem(at: trialIndex)
    await harness.drain()
    #expect(await harness.delegate.runtime.snapshot().gallery.campaignReview == nil)
    try await harness.frame()
    #expect(trialTarget.validateMenuItem(menu.items[trialIndex]))
    #expect(menu.items[trialIndex].title == "Try Campaign")
    menu.performActionForItem(at: trialIndex)
    await harness.drain()
    #expect(
      await harness.delegate.runtime.snapshot().gallery.campaignReview?.root == harness.first.0)
    await harness.delegate.runtime.key("escape")
    let childID = harness.first.1
    await harness.delegate.runtime.nativeCommand { @Sendable game in
      game.emitScriptEvent("contact.requested", only: childID)
    }
    let fault = await harness.delegate.runtime.snapshot()
    #expect(
      fault.commander.scriptState.instances[harness.first.1]?.suspension?.contains(
        "working capital") == true)
    await harness.delegate.runtime.nativeCommand { @Sendable game in game.commander.credits = 3000 }
    try await harness.frame()
    let (retryMenu, retryIndex) = try harness.menuItem("mission-resume")
    let retryTarget = try #require(retryMenu.items[retryIndex].target as? NativeMissionMenu)
    #expect(retryTarget.validateMenuItem(retryMenu.items[retryIndex]))
    retryMenu.performActionForItem(at: retryIndex)
    retryMenu.performActionForItem(at: retryIndex)
    await harness.drain()
    #expect(
      await harness.delegate.runtime.snapshot().commander.scriptState.instances[harness.first.1]?
        .suspension == nil)
    harness.view.game = await harness.delegate.runtime.snapshot()
    #expect(!retryTarget.validateMenuItem(retryMenu.items[retryIndex]))
  }
}

extension NativeViewTests {
  @MainActor @Test func nativeCampaignGalleryQueuedOpenAndTrialRetainTheOldFrameAbsence()
    async throws
  {
    let harness = try await CampaignGalleryInputHarness()
    defer { harness.clean() }
    try await harness.selectChild()
    await harness.delegate.runtime.key("l")
    try await harness.frame()
    #expect(harness.view.game.screen == .status)
    try harness.press("l")
    try harness.press("t")
    await harness.drain()
    #expect(await harness.delegate.runtime.snapshot().screen == .gallery)
    #expect(
      await harness.delegate.runtime.snapshot().selectedGalleryMission?.savedInstance
        == harness.first.1)
    #expect(await harness.delegate.runtime.snapshot().gallery.campaignReview == nil)
    #expect(await harness.delegate.runtime.gallerySaveDirectory() == nil)
  }

  @MainActor @Test func nativeCampaignGalleryProofUsesActualPaintedBoundsDuringResize() async throws
  {
    let harness = try await CampaignGalleryInputHarness()
    defer { harness.clean() }
    try await harness.selectChild()
    try await harness.frame()
    harness.view.setFrameSize(NSSize(width: 1512, height: 982))
    // Paint new native bounds while the simulation still has its previous viewport.
    try await harness.frame()
    try harness.press("t")
    await harness.drain()
    #expect(await harness.delegate.runtime.snapshot().gallery.campaignReview == nil)
    await harness.delegate.runtime.setViewport(width: 1512, height: 982)
    try await harness.frame()
    try harness.press("t")
    await harness.drain()
    #expect(
      await harness.delegate.runtime.snapshot().gallery.campaignReview?.root == harness.first.0)
  }
}
