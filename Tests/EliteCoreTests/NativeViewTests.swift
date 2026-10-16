import AppKit
import EliteCore
import Testing

@testable import EliteMac

// AppKit has one application and event loop; keep native integration work sequential.
@Suite(.serialized)
struct NativeViewTests {
  @MainActor @Test
  func nativeOldFramesCannotAcceptNewOffersOrQuestionsButSamePageArrowConfirmWorks() async throws {
    let harness = try await HeadlessScriptInput()
    defer { harness.clean() }
    await harness.frame()
    try harness.press("b")
    try harness.press("return")
    await harness.drain()
    #expect(await harness.delegate.runtime.snapshot().commander.scriptState.instances.isEmpty)
    #expect(await harness.delegate.runtime.snapshot().scriptAvailablePackDigest != nil)
    try harness.press("return")
    await harness.drain()
    #expect(await harness.delegate.runtime.snapshot().commander.scriptState.instances.isEmpty)
    await harness.frame()
    try harness.press("return")
    await harness.drain()
    let owner = try #require(
      await harness.delegate.runtime.snapshot().commander.scriptState.instances.keys.first)
    try harness.press("b")
    try harness.press("return")
    await harness.drain()
    #expect(
      await harness.delegate.runtime.snapshot().commander.scriptState.instances[owner]?
        .conversationReceipts.isEmpty == true)
    await harness.frame()
    try harness.press("down")
    try harness.press("return")
    await harness.drain()
    let receipts = await harness.delegate.runtime.snapshot().commander.scriptState.instances[owner]?
      .conversationReceipts
    #expect(receipts?.count == 1 && receipts?.values.first?.choice == "details")
  }

  @MainActor @Test
  func nativeOldMouseClicksCannotConfirmAnUndisplayedChainedQuestion() async throws {
    let harness = try await HeadlessScriptInput()
    defer { harness.clean() }
    let owner = try await harness.question()
    try harness.clickConfirm()
    try harness.clickConfirm()
    await harness.drain()
    #expect(
      await harness.delegate.runtime.snapshot().commander.scriptState.instances[owner]?
        .conversationReceipts.count == 1)
    try harness.clickConfirm()
    await harness.drain()
    #expect(
      await harness.delegate.runtime.snapshot().commander.scriptState.instances[owner]?
        .conversationReceipts.count == 1)
    await harness.frame()
    try harness.clickConfirm()
    await harness.drain()
    #expect(
      await harness.delegate.runtime.snapshot().commander.scriptState.instances[owner]?
        .conversationReceipts.count == 2)
  }

  @MainActor @Test
  func nativeMalformedPagePacketsAndReloadedCommanderEpochCannotConfirmTheOldPage() async throws {
    let harness = try await HeadlessScriptInput()
    defer { harness.clean() }
    let owner = try await harness.question()
    let before = await harness.delegate.runtime.snapshot()
    let token = try JSONEncoder().encode(before.scriptPagePresentation).base64EncodedString()
    harness.view.pending = [
      "script-page-key:%%%:return",
      "script-page-key:" + String(repeating: "A", count: 1401) + ":return",
      "script-page-click:%%%:1:1", "script-page-key:" + token + ":return:extra",
      "script-page-click:" + token + ":nan:1", "script-page-click:" + token + ":1",
    ]
    await harness.drain()
    #expect(await harness.delegate.runtime.snapshot().commander == before.commander)
    try await harness.delegate.runtime.load(from: harness.file, persistMigrations: false)
    let restored = await harness.delegate.runtime.snapshot()
    #expect(restored.ecmControl.epoch != before.ecmControl.epoch)
    try harness.press("return")
    await harness.drain()
    #expect(await harness.delegate.runtime.snapshot().commander == restored.commander)
    try harness.press("b")
    try harness.press("return")
    await harness.drain()
    #expect(
      await harness.delegate.runtime.snapshot().commander.scriptState.instances[owner]?
        .conversationReceipts.isEmpty == true)
    await harness.frame()
    try harness.press("return")
    await harness.drain()
    #expect(
      await harness.delegate.runtime.snapshot().commander.scriptState.instances[owner]?
        .conversationReceipts.count == 1)
  }

  @MainActor @Test
  func nativeQueuedReturnsCannotAnswerAnUndisplayedNextScriptQuestion() async throws {
    let id = UUID().uuidString
    let preferences = try #require(UserDefaults(suiteName: id))
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(id)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer {
      preferences.removePersistentDomain(forName: id)
      try? FileManager.default.removeItem(at: folder)
    }
    let file = folder.appendingPathComponent("commander.json")
    try JSONEncoder().encode(Commander()).write(to: file)
    let saves = CommanderSaveSession(preferences: preferences, defaultURL: file)
    let delegate = AppDelegate(restoreOnLaunch: false, saves: saves)
    try await delegate.runtime.load(from: file, persistMigrations: false)
    let example = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(
        "docs/mission-packs/station-conversation")
    try await delegate.runtime.installScriptPack(
      from: example,
      destination: folder.appendingPathComponent("packs"))
    await delegate.runtime.key("contacts-open")
    await delegate.runtime.key("return")
    await delegate.runtime.key("contacts-open")
    // No NSWindow or app activation: exercise the real event/queue/actor path without taking focus.
    let view = GameView(frame: NSRect(x: 0, y: 0, width: 512, height: 518))
    view.game = await delegate.runtime.snapshot()
    view.updateLayer()
    let instance = try #require(view.game.scriptOffer)
    let shown = try #require(view.game.scriptPresentedDialogue)
    let enter = try #require(
      NSEvent.keyEvent(
        with: .keyDown, location: .zero,
        modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
        characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
    view.keyDown(with: enter)
    view.keyDown(with: enter)
    #expect(view.pending.count == 2)
    await delegate.processPendingCommands(in: view)
    let answered = await delegate.runtime.snapshot()
    let count = answered.commander.scriptState.instances[instance]?.conversationReceipts.count
    #expect(count == 1)
    guard count == 1 else { return }
    #expect(answered.scriptPresentedDialogue?.token != shown.token)
    // The model was updated by the command pump, but the next page has not been painted yet.
    view.keyDown(with: enter)
    await delegate.processPendingCommands(in: view)
    #expect(
      await delegate.runtime.snapshot().commander.scriptState.instances[instance]?
        .conversationReceipts.count == 1)
    view.game = await delegate.runtime.snapshot()
    view.updateLayer()
    view.keyDown(with: enter)
    await delegate.processPendingCommands(in: view)
    #expect(
      await delegate.runtime.snapshot().commander.scriptState.instances[instance]?
        .conversationReceipts.count == 2)
  }

  @MainActor @Test
  func nativeMaterialQuoteUsesRealPurchasedUnitsAndOrderedTrialSaveWithoutTouchingTheOwner()
    async throws
  {
    let id = UUID().uuidString
    let preferences = try #require(UserDefaults(suiteName: id))
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(id)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer {
      preferences.removePersistentDomain(forName: id)
      try? FileManager.default.removeItem(at: folder)
    }
    let file = folder.appendingPathComponent("commander.json")
    try JSONEncoder().encode(Commander()).write(to: file)
    let saves = CommanderSaveSession(preferences: preferences, defaultURL: file)
    let delegate = AppDelegate(restoreOnLaunch: false, saves: saves)
    try await delegate.runtime.load(from: file, persistMigrations: false)
    let example = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(
        "docs/mission-packs/material-collection")
    try await delegate.runtime.installScriptPack(
      from: example,
      destination: folder.appendingPathComponent("packs"))
    let notification = Notification(name: NSApplication.didFinishLaunchingNotification)
    delegate.applicationDidFinishLaunching(notification)
    let window = try #require(delegate.window)
    let loop = try #require(delegate.loop)
    loop.cancel()
    await loop.value
    defer {
      delegate.windowWillClose(notification)
      window.orderOut(nil)
    }
    window.setContentSize(NSSize(width: 512, height: 518))
    let view = try #require(window.contentView as? GameView)
    await delegate.runtime.setViewport(width: 512, height: 518)
    await delegate.runtime.key("gallery-open")
    let original = await delegate.runtime.snapshot().commander
    let originalBytes = try Data(contentsOf: file)
    let pack = try ScriptPackLibrary.read(example)
    try await delegate.runtime.startScriptGalleryTrial(packDigest: pack.digest)
    let namespace = try #require(await delegate.runtime.gallerySaveDirectory())
    defer { try? FileManager.default.removeItem(at: namespace) }
    // Buy through the real native market; the trial does not start with gifted materials.
    let market = await delegate.runtime.snapshot().market
    #expect(market[2].quantity > 0 && market[14].quantity > 0)
    await delegate.runtime.key("1")
    await delegate.runtime.key("down")
    await delegate.runtime.key("down")
    await delegate.runtime.key("return")
    for _ in 0..<12 { await delegate.runtime.key("down") }
    await delegate.runtime.key("return")
    await delegate.runtime.key("8")
    let acquired = await delegate.runtime.snapshot().commander
    #expect(acquired.cargo[2] == 1 && acquired.cargo[14] == 1)
    // Gallery scenarios already accepted the mission when creating their isolated starting state.
    await delegate.runtime.key("contacts-open")
    await delegate.processFrame(in: view, delta: { 0 })
    let preview = await delegate.runtime.snapshot()
    let instance = try #require(preview.commander.scriptState.instances.keys.first)
    let quote = try #require(preview.scriptPresentedDialogue?.collectionQuote)
    #expect(quote.items.first?.quantity == 1 && quote.items.last?.quantity == 1)
    #expect(quote.items.last?.unit == "kg" && quote.items.last?.requested == 1)
    let evidence = ProcessInfo.processInfo.environment["ELITE_UI_EVIDENCE_DIRECTORY"]
    for (width, height, scale) in [(512, 518, 1), (1512, 982, 2)] {
      let image = try #require(imageForGame(preview, width: width, height: height, scale: scale))
      #expect(image.width == width * scale && image.height == height * scale)
      if let evidence {
        let directory = URL(fileURLWithPath: evidence, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let bytes = try #require(
          NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try bytes.write(to: directory.appendingPathComponent("material-quote-\(width).png"))
      }
    }
    #expect(await delegate.runtime.snapshot().commander == preview.commander)
    let saved = namespace.appendingPathComponent("commander.json")
    view.pending = ["return", "commander-save:\(saved.path)"]
    await delegate.processPendingCommands(in: view)
    let delivered = await delegate.runtime.snapshot().commander
    let collection = try #require(
      delivered.scriptState.instances[instance]?.collections["materials"])
    #expect(collection.lots.count == 1 && collection.lots.values.first?.massGrams == 1_001_000)
    #expect(delivered.cargo[2] == 0 && delivered.cargo[14] == 0)
    #expect(delivered.credits == acquired.credits)
    try await delegate.runtime.load(from: saved, persistMigrations: false)
    #expect(await delegate.runtime.snapshot().commander == delivered)
    try await delegate.runtime.returnFromScriptGalleryTrial()
    #expect(await delegate.runtime.snapshot().commander == original)
    #expect(try Data(contentsOf: file) == originalBytes)
  }

  @MainActor @Test
  func nativeReferenceLibraryMenuClicksAndOrderedSaveKeepReadingSeparateFromMissions() async throws
  {
    let id = UUID().uuidString
    let preferences = try #require(UserDefaults(suiteName: id))
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(id)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer {
      preferences.removePersistentDomain(forName: id)
      try? FileManager.default.removeItem(at: folder)
    }
    let file = folder.appendingPathComponent("commander.json")
    try JSONEncoder().encode(Commander()).write(to: file)
    let saves = CommanderSaveSession(preferences: preferences, defaultURL: file)
    let delegate = AppDelegate(restoreOnLaunch: false, saves: saves)
    try await delegate.runtime.load(from: file, persistMigrations: false)
    let example = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(
        "docs/mission-packs/reference-book")
    try await delegate.runtime.installScriptPack(
      from: example, destination: folder.appendingPathComponent("packs"))
    let notification = Notification(name: NSApplication.didFinishLaunchingNotification)
    delegate.applicationDidFinishLaunching(notification)
    let window = try #require(delegate.window)
    let loop = try #require(delegate.loop)
    loop.cancel()
    await loop.value
    defer {
      delegate.windowWillClose(notification)
      window.orderOut(nil)
    }
    window.setContentSize(NSSize(width: 512, height: 518))
    let view = try #require(window.contentView as? GameView)
    await delegate.runtime.setViewport(width: 512, height: 518)
    await delegate.runtime.key("contacts-open")
    await delegate.runtime.key("return")
    await delegate.runtime.key("contacts-open")
    await delegate.runtime.key("return")
    let granted = await delegate.runtime.snapshot().commander
    #expect(granted.scriptState.books.count == 1)
    await delegate.processFrame(in: view, delta: { 0 })
    let menu = try #require(NSApp.mainMenu?.item(withTitle: "Game")?.submenu)
    let item = try #require(menu.items.firstIndex { $0.title == "Mission Library" })
    menu.performActionForItem(at: item)
    await delegate.processPendingCommands(in: view)
    await delegate.processFrame(in: view, delta: { 0 })
    #expect(view.game.screen == .library && view.game.library.mode == .books)
    let click = try #require(
      NSEvent.mouseEvent(
        with: .leftMouseDown,
        location: .init(x: 50, y: view.bounds.height - 100), modifierFlags: [], timestamp: 0,
        windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)
    )
    view.mouseDown(with: click)
    #expect(view.pending.first?.hasPrefix("library-click:") == true)
    await delegate.processPendingCommands(in: view)
    #expect(await delegate.runtime.snapshot().library.mode == .contents)
    let evidence = ProcessInfo.processInfo.environment["ELITE_UI_EVIDENCE_DIRECTORY"]
    for page in ["contents", "reading", "source"] {
      if page == "reading" {
        await delegate.runtime.key("down")
        await delegate.runtime.key("return")
      }
      if page == "source" { await delegate.runtime.key("i") }
      let actual = await delegate.runtime.snapshot()
      #expect(actual.commander == granted)
      for (width, height, scale) in [(512, 518, 1), (1512, 982, 2)] {
        let image = try #require(imageForGame(actual, width: width, height: height, scale: scale))
        #expect(image.width == width * scale && image.height == height * scale)
        if let evidence {
          let directory = URL(fileURLWithPath: evidence, isDirectory: true)
          try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
          let bytes = try #require(
            NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
          try bytes.write(to: directory.appendingPathComponent("library-\(page)-\(width).png"))
        }
      }
    }
    await delegate.runtime.key("i")
    view.pending = ["down", "commander-save:\(file.path)"]
    await delegate.processPendingCommands(in: view)
    let loaded = GameRuntime()
    try await loaded.load(from: file, persistMigrations: false)
    let restored = await loaded.snapshot()
    #expect(
      restored.screen == .library && restored.library.mode == .reading
        && restored.library.scroll > 0)
    #expect(restored.commander == granted)
  }

  @MainActor @Test func nativeRepeatableConversationUsesRealAnswersInItsOwnGallerySave()
    async throws
  {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let example = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/station-conversation")
    let owner = GameRuntime(game: Game(executive: false))
    try await owner.installScriptPack(from: example, destination: root)
    let original = await owner.snapshot()
    let pack = try ScriptPackLibrary.read(example)
    let trial = try await owner.scriptGalleryTrial(packDigest: pack.digest)
    let namespace = try #require(await trial.gallerySaveDirectory())
    defer { try? FileManager.default.removeItem(at: namespace) }
    await trial.key("contacts-open")
    await trial.key("return")
    await trial.key("down")
    let preview = await trial.snapshot()
    let id = try #require(preview.commander.scriptState.instances.keys.first)
    #expect(preview.commander.scriptState.instances[id]?.conversationReceipts.count == 1)
    let evidence = ProcessInfo.processInfo.environment["ELITE_UI_EVIDENCE_DIRECTORY"]
    for (width, height, scale) in [(512, 518, 1), (1512, 982, 2)] {
      let image = try #require(imageForGame(preview, width: width, height: height, scale: scale))
      #expect(image.width == width * scale && image.height == height * scale)
      if let evidence {
        let directory = URL(fileURLWithPath: evidence, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let bytes = try #require(
          NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try bytes.write(to: directory.appendingPathComponent("conversation-details-\(width).png"))
      }
    }
    #expect(await trial.snapshot().commander == preview.commander)
    await trial.key("k")
    #expect(
      PlayerHelp.pages(for: await trial.snapshot()).flatMap(\.rows).contains(
        "READING / BACK DOES NOT ANSWER"))
    await trial.key("escape")
    await trial.key("return")
    await trial.key("down")
    await trial.key("down")
    await trial.key("return")
    let complete = await trial.snapshot()
    #expect(complete.commander.scriptState.instances[id]?.outcome == .complete)
    #expect(complete.commander.scriptState.instances[id]?.conversationReceipts.count == 3)
    #expect(complete.commander.credits == preview.commander.credits)
    try await trial.load(from: namespace.appendingPathComponent("commander.json"))
    #expect(await trial.snapshot().commander == complete.commander)
    #expect(await owner.snapshot().commander == original.commander)
  }

  @MainActor @Test func nativeStationChoicesRenderDistinctSelectionsWithoutCommittingABranch()
    async throws
  {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let example = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/branch-choice")
    let runtime = GameRuntime(game: Game(executive: false))
    try await runtime.installScriptPack(from: example, destination: root)
    let pack = try ScriptPackLibrary.read(example)
    let trial = try await runtime.scriptGalleryTrial(packDigest: pack.digest)
    let namespace = try #require(await trial.gallerySaveDirectory())
    defer { try? FileManager.default.removeItem(at: namespace) }
    await trial.key("contacts-open")
    let first = await trial.snapshot()
    #expect(first.screen == .handoff && first.scriptChoiceSelection == 0)
    let origin = try #require(first.commander.scriptState.instances.values.first)
    let evidence = ProcessInfo.processInfo.environment["ELITE_UI_EVIDENCE_DIRECTORY"]
    for (index, name) in [(0, "patrol"), (1, "courier")] {
      if index == 1 { await trial.key("down") }
      let actual = await trial.snapshot()
      #expect(actual.scriptChoiceSelection == index && actual.commander == first.commander)
      let frame = Display.presentation(actual, width: 512, height: 518)
      #expect(frame.labels.contains { $0.text.contains("Choose the work") })
      #expect(frame.labels.contains { $0.text.contains("Arrows: choose") })
      #expect(actual.commander.scriptState.instances[origin.id]?.choiceReceipts.isEmpty == true)
      for (width, height, scale) in [(512, 518, 1), (1512, 982, 2)] {
        let image = try #require(imageForGame(actual, width: width, height: height, scale: scale))
        #expect(image.width == width * scale && image.height == height * scale)
        let pixels = try #require(image.dataProvider?.data) as Data
        let white = stride(from: 0, to: pixels.count - 3, by: 4).filter { offset in
          pixels[offset] == 255 && pixels[offset + 1] == 255
            && pixels[offset + 2] == 255 && pixels[offset + 3] == 255
        }.count
        #expect(white > 1000)  // Retain the briefing and key guide while the choice changes.
        if let evidence {
          let directory = URL(fileURLWithPath: evidence, isDirectory: true)
          try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
          let bytes = try #require(
            NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
          try bytes.write(to: directory.appendingPathComponent("choice-\(name)-\(width).png"))
        }
      }
    }
    await trial.key("escape")
    #expect(await trial.snapshot().commander == first.commander)
  }

  @MainActor @Test func nativeGalleryDisplaysIndependentServiceAfterAuthorizationCompletes()
    async throws
  {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let example = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/station-maintenance")
    let pack = try ScriptPackLibrary.read(example)
    let runtime = GameRuntime(game: Game(executive: false))
    try await runtime.installScriptPack(from: example, destination: root)
    let trial = try await runtime.scriptGalleryTrial(packDigest: pack.digest, seed: 72)
    let namespace = try #require(await trial.gallerySaveDirectory())
    defer { try? FileManager.default.removeItem(at: namespace) }
    var actual = await trial.snapshot()
    let origin = try #require(actual.commander.scriptState.instances.values.first)
    #expect(origin.outcome == .complete && actual.commander.scriptState.worldJobs.count == 1)
    actual.openGallery()
    actual.gallery.selection = try #require(
      actual.missionCatalogue.firstIndex { $0.savedInstance == origin.id })
    actual.gallery.detail = true
    #expect(actual.missionCatalogue[actual.gallery.selection].status == .complete)
    #expect(
      actual.missionCatalogue[actual.gallery.selection].briefing.contains(
        "Station training patrol service: Active"))
    let evidence = ProcessInfo.processInfo.environment["ELITE_UI_EVIDENCE_DIRECTORY"]
    for (width, height, scale) in [(512, 518, 1), (1512, 982, 2)] {
      actual.gallery.scroll = width == 512 ? 6 : 0
      let image = try #require(imageForGame(actual, width: width, height: height, scale: scale))
      #expect(image.width == width * scale && image.height == height * scale)
      if let evidence {
        let directory = URL(fileURLWithPath: evidence, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let bytes = try #require(
          NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try bytes.write(to: directory.appendingPathComponent("services-active-\(width).png"))
      }
    }
  }

  @MainActor @Test
  func nativeGalleryShowsActualCampaignAndItsOwnedChildWithoutStartingAnotherTrial() async throws {
    let examples = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(
        "docs/mission-packs")
    let parent = try ScriptPackLibrary.read(examples.appendingPathComponent("scoped-patrol"))
    let child = try ScriptPackLibrary.read(examples.appendingPathComponent("scripted-patrol"))
    var live = Game(executive: false)
    live.screen = .status
    live.scriptPacks = [parent, child]
    let owner = GameRuntime(game: live)
    let original = await owner.snapshot()
    let trial = try await owner.scriptGalleryTrial(packDigest: parent.digest, seed: 91)
    let namespace = try #require(await trial.gallerySaveDirectory())
    defer { try? FileManager.default.removeItem(at: namespace) }
    var actual = await trial.advance(delta: 0.1)
    let before = actual.commander
    actual.openGallery()
    let evidence = ProcessInfo.processInfo.environment["ELITE_UI_EVIDENCE_DIRECTORY"]
    for (kind, digest) in [("parent", parent.digest), ("child", child.digest)] {
      let index = try #require(
        actual.missionCatalogue.firstIndex { entry in
          kind == "parent"
            ? entry.trialDigest == digest : entry.savedInstance != nil && entry.trialDigest == nil
        })
      actual.gallery.selection = index
      actual.gallery.detail = true
      #expect(
        actual.missionCatalogue[index].briefing.contains(
          kind == "parent" ? "Campaign assignments:" : "Owning campaign:"))
      if kind == "child" { #expect(!actual.canTrialSelectedMission) }
      for (width, height, scale) in [(512, 518, 1), (1512, 982, 2)] {
        actual.gallery.scroll = width == 512 ? 7 : 0
        let image = try #require(imageForGame(actual, width: width, height: height, scale: scale))
        #expect(image.width == width * scale && image.height == height * scale)
        if let evidence {
          let directory = URL(fileURLWithPath: evidence, isDirectory: true)
          try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
          let bytes = try #require(
            NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
          try bytes.write(to: directory.appendingPathComponent("campaign-\(kind)-\(width).png"))
        }
      }
    }
    #expect(actual.commander == before)
    #expect(await owner.snapshot().commander == original.commander)
  }

  @MainActor @Test func nativeProfiledShipsRenderMeasuredComponentsAndSourcePanels() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let example = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/profiled-skirmish")
    let pack = try ScriptPackLibrary.read(example)
    let runtime = GameRuntime(game: Game(executive: false))
    try await runtime.installScriptPack(from: example, destination: root)
    let trial = try await runtime.scriptGalleryTrial(packDigest: pack.digest, seed: 56)
    let namespace = try #require(await trial.gallerySaveDirectory())
    defer { try? FileManager.default.removeItem(at: namespace) }
    var actual = await trial.snapshot()
    for _ in 0..<100 {
      actual = await trial.advance(delta: 0.05)
      if actual.bodies.contains(where: {
        $0.scriptNPC?.guns["forward"]?.beamRange != nil
          && ($0.scriptNPC?.guns["forward"]?.cooldown ?? 0) > 0.05
      }) {
        break
      }
    }
    #expect(actual.isMissionTrial)
    #expect(actual.bodies.contains { $0.scriptNPC?.guns["forward"]?.beamRange != nil })
    let body = try #require(actual.bodies.first { $0.scriptNPC != nil })
    let evidence = ProcessInfo.processInfo.environment["ELITE_UI_EVIDENCE_DIRECTORY"]
    if let evidence {
      let directory = URL(fileURLWithPath: evidence)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let image = try #require(imageForGame(actual, width: 1512, height: 982, scale: 2))
      let bytes = try #require(
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
      try bytes.write(to: directory.appendingPathComponent("npc-native-combat-1512.png"))
    }
    for rotated in [false, true] {
      var game = actual
      var body = body
      body.position = .init(0, 0, 450)
      if rotated {
        body.orientation.x = body.orientation.x.rotated(pitch: 0.45, roll: 0.4, yaw: 0.7)
        body.orientation.y = body.orientation.y.rotated(pitch: 0.45, roll: 0.4, yaw: 0.7)
        body.orientation.z = body.orientation.z.rotated(pitch: 0.45, roll: 0.4, yaw: 0.7)
      }
      game.bodies = [body]
      game.commander.shipDisplayStyle = .shadedPanels
      for (width, height, scale) in [(512, 518, 1), (1512, 982, 2)] {
        let image = try #require(imageForGame(game, width: width, height: height, scale: scale))
        #expect(image.width == width * scale && image.height == height * scale)
        if let evidence {
          let directory = URL(fileURLWithPath: evidence)
          try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
          let bytes = try #require(
            NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
          try bytes.write(
            to: directory.appendingPathComponent(
              "npc-\(rotated ? "rotated" : "front")-\(width).png"))
        }
      }
    }
    #expect(await trial.snapshot().bodies == actual.bodies)
  }

  @MainActor @Test func nativeContractBoardUsesExplicitActionsAndSavesThePrecedingAcceptance()
    async throws
  {
    let id = UUID().uuidString
    let preferences = try #require(UserDefaults(suiteName: id))
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(id)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer {
      preferences.removePersistentDomain(forName: id)
      try? FileManager.default.removeItem(at: folder)
    }
    let file = folder.appendingPathComponent("commander.json")
    try JSONEncoder().encode(Commander()).write(to: file)
    let saves = CommanderSaveSession(preferences: preferences, defaultURL: file)
    let delegate = AppDelegate(restoreOnLaunch: false, saves: saves)
    try await delegate.runtime.load(from: file, persistMigrations: false)
    let example = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(
        "docs/mission-packs/scripted-contracts")
    try await delegate.runtime.installScriptPack(
      from: example, destination: folder.appendingPathComponent("packs"))
    let notification = Notification(name: NSApplication.didFinishLaunchingNotification)
    delegate.applicationDidFinishLaunching(notification)
    let window = try #require(delegate.window)
    let loop = try #require(delegate.loop)
    loop.cancel()
    await loop.value
    defer {
      delegate.windowWillClose(notification)
      window.orderOut(nil)
    }
    let view = try #require(window.contentView as? GameView)
    await delegate.processFrame(in: view, delta: { 0 })
    let menu = try #require(NSApp.mainMenu?.item(withTitle: "Game")?.submenu)
    let index = try #require(
      menu.items.firstIndex { ($0.representedObject as? String) == "contracts-open" })
    #expect(delegate.validateMenuItem(menu.items[index]))
    menu.performActionForItem(at: index)
    await delegate.processFrame(in: view, delta: { 0 })
    #expect(view.game.screen == .contracts && view.game.contractBoard.rows.count == 2)
    let before = view.game.commander
    let evidence = ProcessInfo.processInfo.environment["ELITE_UI_EVIDENCE_DIRECTORY"]
    for detail in [false, true] {
      if detail {
        view.pending = ["return"]
        await delegate.processFrame(in: view, delta: { 0 })
      }
      for (width, height, scale) in [(512, 518, 1), (1512, 982, 2)] {
        let image = try #require(
          imageForGame(view.game, width: width, height: height, scale: scale))
        #expect(image.width == width * scale && image.height == height * scale)
        if let evidence {
          let directory = URL(fileURLWithPath: evidence)
          try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
          let data = try #require(
            NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
          try data.write(
            to: directory.appendingPathComponent(
              "contracts-\(detail ? "detail" : "list")-\(width).png"))
        }
      }
    }
    #expect(view.game.commander == before && view.game.contractBoard.action == .back)
    view.pending = ["right"]
    let commanderMenu = try #require(NSApp.mainMenu?.item(withTitle: "Commander")?.submenu)
    commanderMenu.performActionForItem(at: 0)
    await delegate.processFrame(in: view, delta: { 0 })
    let loaded = GameRuntime(game: view.game)
    try await loaded.load(from: file)
    #expect(await loaded.snapshot().contractBoard.detail)
    #expect(await loaded.snapshot().contractBoard.action == .accept)
    #expect(await loaded.snapshot().commander.scriptState.instances.isEmpty)
    let quote = try #require(view.game.contractBoard.quote)
    let rect = try #require(
      ContractBoardLayout(width: view.bounds.width, height: view.bounds.height).actions.first {
        $0.0 == .accept
      }?.1)
    await delegate.runtime.contractClick(
      x: rect.x + 8, y: rect.y + 8, expectedOffer: quote.offer, detail: true, epoch: UUID())
    #expect(await delegate.runtime.snapshot().commander == before)
    try paintPledgeView(view)
    try clickPledgeView(view, x: rect.x + 8, y: rect.y + 8)
    commanderMenu.performActionForItem(at: 0)
    await delegate.processFrame(in: view, delta: { 0 })
    try await loaded.load(from: file)
    let accepted = await loaded.snapshot().commander
    #expect(
      accepted.scriptState.instances.count == 1 && accepted.credits == 900
        && accepted.cargoTonnes > 0)
    #expect(saves.activeURL == file)
  }
  @MainActor @Test func nativeSaveBatchIncludesThePrecedingOwnedEquipmentStorageAction()
    async throws
  {
    let id = UUID().uuidString
    let preferences = try #require(UserDefaults(suiteName: id))
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(id)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer {
      preferences.removePersistentDomain(forName: id)
      try? FileManager.default.removeItem(at: folder)
    }
    let file = folder.appendingPathComponent("commander.json")
    try JSONEncoder().encode(Commander()).write(to: file)
    let saves = CommanderSaveSession(preferences: preferences, defaultURL: file)
    let delegate = AppDelegate(restoreOnLaunch: false, saves: saves)
    try await delegate.runtime.load(from: file, persistMigrations: false)
    let notification = Notification(name: NSApplication.didFinishLaunchingNotification)
    delegate.applicationDidFinishLaunching(notification)
    let window = try #require(delegate.window)
    let loop = try #require(delegate.loop)
    loop.cancel()
    await loop.value
    defer {
      delegate.windowWillClose(notification)
      window.orderOut(nil)
    }
    let view = try #require(window.contentView as? GameView)
    await delegate.runtime.key("3")
    let desired = try #require(Equipment.all.firstIndex { $0.name == "Missile" })
    for _ in Equipment.all.indices {
      if await delegate.runtime.snapshot().selection == desired { break }
      await delegate.runtime.key("down")
    }
    #expect(await delegate.runtime.snapshot().selection == desired)
    view.pending = ["s"]
    let menu = try #require(NSApp.mainMenu?.item(withTitle: "Commander")?.submenu)
    menu.performActionForItem(at: 0)
    await delegate.processPendingCommands(in: view)
    let loaded = GameRuntime()
    try await loaded.load(from: file, persistMigrations: false)
    let commander = await loaded.snapshot().commander
    #expect(
      commander.missiles == 2
        && commander.ownedEquipment?.stored.filter { $0.kind == .missile }.count == 1)
    #expect(commander.credits == 1000 && saves.activeURL == file)
  }
  @MainActor @Test func nativeGalleryTrialSaveKeepsLiveFileAndCommanderPreferences() async throws {
    let id = UUID().uuidString
    let preferences = try #require(UserDefaults(suiteName: id))
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(id)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer {
      preferences.removePersistentDomain(forName: id)
      try? FileManager.default.removeItem(at: folder)
    }
    let liveFile = folder.appendingPathComponent("live.json")
    var commander = Commander()
    commander.name = "KEEP"
    commander.credits = 123456
    let original = try JSONEncoder().encode(commander)
    try original.write(to: liveFile)
    let saves = CommanderSaveSession(preferences: preferences, defaultURL: liveFile)
    saves.didSave(to: liveFile)
    let delegate = AppDelegate(restoreOnLaunch: false, saves: saves)
    try await delegate.runtime.load(from: liveFile, persistMigrations: false)
    let pack = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent().appendingPathComponent("docs/mission-packs/scripted-passengers")
    try await delegate.runtime.installScriptPack(
      from: pack, destination: folder.appendingPathComponent("packs"))
    let notification = Notification(name: NSApplication.didFinishLaunchingNotification)
    delegate.applicationDidFinishLaunching(notification)
    let window = try #require(delegate.window)
    let loop = try #require(delegate.loop)
    loop.cancel()
    await loop.value
    defer {
      delegate.windowWillClose(notification)
      window.orderOut(nil)
    }
    let view = try #require(window.contentView as? GameView)
    await delegate.runtime.key("gallery-open")
    for _ in 0..<3 { await delegate.runtime.key("down") }
    view.game = await delegate.runtime.snapshot()
    try paintCampaignGalleryView(view)
    let menu = try #require(NSApp.mainMenu?.item(withTitle: "Game")?.submenu)
    let trialIndex = try #require(
      menu.items.firstIndex { ($0.representedObject as? String) == "gallery-trial" })
    #expect(delegate.validateMenuItem(menu.items[trialIndex]))
    menu.performActionForItem(at: trialIndex)
    let commanderMenu = try #require(NSApp.mainMenu?.item(withTitle: "Commander")?.submenu)
    commanderMenu.performActionForItem(at: 0)
    await delegate.processFrame(in: view, delta: { 0 })
    let namespace = try #require(await delegate.runtime.gallerySaveDirectory())
    defer { try? FileManager.default.removeItem(at: namespace) }
    #expect(view.game.isMissionTrial && window.title.hasPrefix("MISSION TRIAL"))
    #expect(try Data(contentsOf: liveFile) == original)
    #expect(
      saves.activeURL == liveFile
        && preferences.string(forKey: "lastCommanderSavePath") == liveFile.path)
    let namedTrial = namespace.appendingPathComponent("named-trial.json")
    view.pending = [
      "commander-save-context:" + view.game.ecmControl.epoch.uuidString + ":" + namedTrial.path
    ]
    await delegate.processPendingCommands(in: view)
    #expect(FileManager.default.fileExists(atPath: namedTrial.path) && saves.activeURL == liveFile)

    view.held = [" ", "right"]
    let returnIndex = try #require(
      menu.items.firstIndex { ($0.representedObject as? String) == "trial-return" })
    #expect(delegate.validateMenuItem(menu.items[returnIndex]))
    menu.performActionForItem(at: returnIndex)
    await delegate.processFrame(in: view, delta: { 0 })
    #expect(!view.game.isMissionTrial && view.game.commander.name == "KEEP")
    #expect(view.held.isEmpty && saves.activeURL == liveFile)
    #expect(try Data(contentsOf: liveFile) == original)
  }

  @MainActor @Test func nativeSaveIncludesEarlierQueuedCobraRestore() async throws {
    let id = UUID().uuidString
    let preferences = try #require(UserDefaults(suiteName: id))
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(id + ".json")
    defer {
      preferences.removePersistentDomain(forName: id)
      try? FileManager.default.removeItem(at: url)
    }
    var commander = Commander()
    commander.shipID = "SH013"
    commander.xyzzyActive = true
    commander.autoTrade = false
    commander.credits = 12345
    try JSONEncoder().encode(commander).write(to: url)
    let saves = CommanderSaveSession(preferences: preferences, defaultURL: url)
    // Await fixture validation before testing input order; sanitizer startup may be slow.
    let delegate = AppDelegate(restoreOnLaunch: false, saves: saves)
    try await delegate.runtime.load(from: url, persistMigrations: false)
    #expect(await delegate.runtime.snapshot().commander.shipID == "SH013")
    let notification = Notification(name: NSApplication.didFinishLaunchingNotification)
    delegate.applicationDidFinishLaunching(notification)
    let window = try #require(delegate.window)
    defer {
      delegate.windowWillClose(notification)
      window.orderOut(nil)
    }
    let view = try #require(window.contentView as? GameView)
    // Stop and await the automatic consumer before draining the real menu batch
    // deterministically. Heavy sanitizer workloads can starve a wall-clock poll.
    let loop = try #require(delegate.loop)
    loop.cancel()
    await loop.value
    view.pending = ["x", "y", "z", "z", "y"]
    let menu = try #require(NSApp.mainMenu?.item(withTitle: "Commander")?.submenu)
    menu.performActionForItem(at: 0)
    #expect(view.pending.last == "commander-save-default")
    await delegate.processPendingCommands(in: view)
    #expect(view.pending.isEmpty)
    let persisted = try JSONDecoder().decode(Commander.self, from: Data(contentsOf: url))
    #expect(persisted.shipID == "SH023" && persisted.credits == 12345)
    #expect(persisted.name == "CLARKE" && saves.startupURL == url)
  }

  @MainActor @Test func cancellingNativeStartupBeforeExecutionDoesNotRestoreOrProcessInput()
    async throws
  {
    let id = UUID().uuidString
    let preferences = try #require(UserDefaults(suiteName: id))
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(id + ".json")
    defer {
      preferences.removePersistentDomain(forName: id)
      try? FileManager.default.removeItem(at: url)
    }
    var commander = Commander()
    commander.name = "CANCELLED"
    commander.credits = 98765
    try JSONEncoder().encode(commander).write(to: url)
    let saves = CommanderSaveSession(preferences: preferences, defaultURL: url)
    let delegate = AppDelegate(saves: saves)
    let before = await delegate.runtime.snapshot().commander
    let notification = Notification(name: NSApplication.didFinishLaunchingNotification)
    delegate.applicationDidFinishLaunching(notification)
    let window = try #require(delegate.window)
    defer { window.orderOut(nil) }
    let view = try #require(window.contentView as? GameView)
    view.pending = ["x", "y", "z", "z", "y"]
    let loop = try #require(delegate.loop)
    delegate.windowWillClose(notification)
    await loop.value
    #expect(delegate.loop == nil)
    #expect(await delegate.runtime.snapshot().commander == before)
    #expect(view.pending == ["x", "y", "z", "z", "y"])
  }

  @MainActor @Test func nativeSpinInputRecognizesCirclesRebasesAimAndKeepsForwardThrottleSeparate()
  {
    let view = GameView()
    view.game.launch()
    view.game.key("v")
    for index in 0...40 {
      let angle = -Double(index) * .pi / 20
      view.updateTrackpad(positions: [.init(0.5 + cos(angle) * 0.3, 0.5 + sin(angle) * 0.3)])
    }
    #expect(view.pending == ["spin:cw"])
    #expect(view.controls.pitch == 0 && view.controls.yaw == 0 && view.controls.throttle == 0)
    view.updateTrackpad(positions: [.zero, .zero, .zero])
    #expect(view.controls.spinContacts == 3 && view.controls.throttle == 0)
    view.updateTrackpad(positions: [.init(0.1, 0.1), .init(0.3, 0.1)])
    #expect(view.controls.pitch == 0 && view.controls.yaw == 0)
    view.updateTrackpad(positions: [.init(0.2, 0.2), .init(0.4, 0.2)])
    #expect(view.controls.pitch > 0 && view.controls.yaw > 0 && view.controls.roll == 0)
    view.held = ["-", "right"]
    #expect(view.controls.spinSlower && !view.controls.spinFaster && view.controls.yaw == 1)
    view.held = ["+"]
    #expect(view.controls.spinFaster && !view.controls.spinSlower)
    view.game.key("b")
    #expect(view.trackpad.fingerCount == 0)
  }

  @MainActor @Test func nativeTrackpadHoldsControlsAndClearsOnPauseHelpDockingOrFocusLoss() throws {
    let view = GameView()
    #expect(view.allowedTouchTypes == .indirect && view.wantsRestingTouches)
    view.updateTrackpad(positions: [.init(0.5, 1), .init(0.5, 1)])
    #expect(view.trackpad.fingerCount == 0)
    view.game.launch()
    view.updateTrackpad(positions: [.init(0.5, 1), .init(0.5, 1)])
    #expect(view.controls.pitch == 1 && view.controls.throttle == 0)
    view.held = ["x"]
    #expect(view.controls.pitch == 1)
    view.held = ["s"]
    #expect(view.controls.pitch == 0)
    view.held = []
    view.updateTrackpad(positions: [.init(0.5, 0.5)])
    #expect(view.controls.throttle == -1 && view.controls.pitch == 0)
    view.updateTrackpad(positions: [.zero, .zero, .zero])
    #expect(view.controls.throttle == 1 && view.controls.roll == 0)
    view.game.paused = true
    #expect(view.trackpad.fingerCount == 0 && view.controls.throttle == 0)
    view.game.paused = false
    view.updateTrackpad(positions: [.init(1, 0.5), .init(1, 0.5)])
    #expect(view.controls.roll == -1)
    view.game.key("k")
    #expect(view.trackpad.fingerCount == 0)
    view.game.key("k")
    #expect(view.controls.roll == 0)
    view.game.dockingComputer = true
    view.updateTrackpad(positions: [.zero, .zero, .zero])
    #expect(view.trackpad.fingerCount == 0)
    view.game.dockingComputer = false
    view.updateTrackpad(positions: [.zero, .zero, .zero])
    let cancel = try #require(
      NSEvent.keyEvent(
        with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
        windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
        isARepeat: false, keyCode: 0))
    view.touchesCancelled(with: cancel)
    #expect(view.trackpad.fingerCount == 0)
    view.updateTrackpad(positions: [.zero, .zero, .zero])
    view.game.dock()
    #expect(view.trackpad.fingerCount == 0)
  }

  @MainActor @Test func nativeFrameConversionAndInput() throws {
    let image = try #require(imageFor(Display.render(Game())))
    #expect(image.width == 256 && image.height == 256)
    let view = GameView(frame: NSRect(x: 0, y: 0, width: 768, height: 768))
    #expect(view.acceptsFirstResponder && view.isFlipped)
    let keys: [(UInt16, String, String)] = [
      (36, "\r", "return"), (48, "\t", "tab"), (53, "", "escape"),
      (117, "", "delete"), (119, "", "copy"), (123, "", "left"), (124, "", "right"),
      (125, "", "down"), (126, "", "up"),
      (0, "a", "a"),
    ]
    for (code, text, expected) in keys {
      let event = try #require(
        NSEvent.keyEvent(
          with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
          windowNumber: 0, context: nil, characters: text, charactersIgnoringModifiers: text,
          isARepeat: false, keyCode: code))
      view.keyDown(with: event)
      #expect(nativeQueuedKey(view.pending.last) == expected && view.held.isEmpty)
      view.keyUp(with: event)
      #expect(!view.held.contains(expected))
    }
    view.game.launch()
    view.held = ["x", ",", " ", "a"]
    #expect(
      view.controls.pitch == 1 && view.controls.roll == 1 && view.controls.throttle == 1
        && view.controls.fire)
    view.held = ["s", ".", "/"]
    #expect(view.controls.pitch == -1 && view.controls.roll == -1 && view.controls.throttle == -1)
    view.held = ["<", ">", "?"]
    #expect(view.controls.roll == 0 && view.controls.throttle == -1)
    view.held = []
    #expect(!view.controls.fire)
    weak var released: GameView?
    do {
      let transient = GameView()
      released = transient
      #expect(released != nil)
    }
    #expect(released == nil)
  }

  @MainActor @Test func smoothWireframesPreservePixelTextAndShiftedKeyRelease() throws {
    var game = Game(executive: false)
    game.time = 1.3
    game.screen = .front
    game.bodies = [.init(id: 1, hull: .cobra, position: .init(0, 0, 280))]
    let frame = Display.render(game, rasterizeGraphics: false)
    let smooth = try #require(imageFor(frame, pixelSize: 768))
    #expect(smooth.width == 768 && smooth.height == 768)
    let data = try #require(smooth.dataProvider?.data)
    let bytes = CFDataGetBytePtr(data)!
    let count = CFDataGetLength(data)
    let intermediate = stride(from: 0, to: count, by: 4).filter { bytes[$0] > 0 && bytes[$0] < 255 }
      .count
    #expect(intermediate > 100)
    let view = GameView()
    view.game.launch()
    let down = try #require(
      NSEvent.keyEvent(
        with: .keyDown, location: .zero, modifierFlags: .shift, timestamp: 0,
        windowNumber: 0, context: nil, characters: "<", charactersIgnoringModifiers: ",",
        isARepeat: false, keyCode: 43))
    let up = try #require(
      NSEvent.keyEvent(
        with: .keyUp, location: .zero, modifierFlags: [], timestamp: 0,
        windowNumber: 0, context: nil, characters: ",", charactersIgnoringModifiers: ",",
        isARepeat: false, keyCode: 43))
    view.keyDown(with: down)
    #expect(view.controls.roll == 1)
    view.keyUp(with: up)
    #expect(view.controls.roll == 0 && view.held.isEmpty)
  }

  @MainActor @Test func nativeFrameProcessesNumberKeysMenusAndClearsFocus() async throws {
    _ = NSApplication.shared
    let delegate = AppDelegate(restoreOnLaunch: false)
    let notification = Notification(name: NSApplication.didFinishLaunchingNotification)
    delegate.applicationDidFinishLaunching(notification)
    let window = try #require(delegate.window)
    let view = try #require(window.contentView as? GameView)
    let loop = try #require(delegate.loop)
    loop.cancel()
    await loop.value
    view.pending = ["return", "0", "chart:20:30"]
    view.held = ["x"]
    view.pressedKeys = [7: "x"]
    await delegate.processFrame(in: view) { 0.02 }
    #expect(view.pending.isEmpty)
    #expect(view.game.time > 0)
    let gameMenu = try #require(NSApp.mainMenu?.item(withTitle: "Game")?.submenu)
    let pauseItem = try #require(gameMenu.item(withTitle: "Pause / Resume"))
    #expect(pauseItem.keyEquivalent == "p" && pauseItem.keyEquivalentModifierMask == .command)
    gameMenu.performActionForItem(at: gameMenu.index(of: pauseItem))
    await delegate.processFrame(in: view) { 0.02 }
    #expect(view.game.paused)
    gameMenu.performActionForItem(at: gameMenu.index(of: pauseItem))
    await delegate.processFrame(in: view) { 0.02 }
    #expect(!view.game.paused)
    let guideMenu = try #require(NSApp.mainMenu?.item(withTitle: "Help")?.submenu)
    guideMenu.performActionForItem(at: 0)
    await delegate.processFrame(in: view) { 0.02 }
    #expect(view.game.screen == .help)
    view.game.launch()
    // Headless runners may not grant key-window status; inject the held touch for this reset check.
    view.trackpad.update(positions: [.zero, .zero, .zero])
    #expect(view.trackpad.fingerCount == 3)
    delegate.windowDidResignKey(notification)
    #expect(view.held.isEmpty && view.pressedKeys.isEmpty && view.trackpad.fingerCount == 0)
    delegate.windowWillClose(notification)
    #expect(delegate.loop == nil)
    window.orderOut(nil)
  }

  @MainActor @Test func nativePresentationDrawsColouredLinesAndShadedFaces() throws {
    var game = Game(executive: false)
    game.time = 2.3
    game.screen = .front
    game.bodies = [.init(id: 1, hull: .cobra, position: .init(0, 0, 280))]
    game.commander.shipDisplayStyle = .colourWireframe
    let wire = try #require(
      imageFor(Display.render(game, rasterizeGraphics: false), pixelSize: 512))
    game.commander.shipDisplayStyle = .shadedPanels
    let shaded = try #require(
      imageFor(Display.render(game, rasterizeGraphics: false), pixelSize: 512))
    func colouredPixels(_ image: CGImage) throws -> Int {
      let data = try #require(image.dataProvider?.data)
      let bytes = try #require(CFDataGetBytePtr(data))
      return stride(from: 0, to: CFDataGetLength(data), by: 4).filter {
        let channels = [Int(bytes[$0]), Int(bytes[$0 + 1]), Int(bytes[$0 + 2])]
        return channels.max()! > 20 && channels.max()! - channels.min()! > 20
      }.count
    }
    let lines = try colouredPixels(wire)
    let panels = try colouredPixels(shaded)
    #expect(lines > 100)
    // Filled material colour covers more area than lines, regardless of livery hue.
    #expect(panels > lines)
    #expect(shaded.width == 512 && shaded.height == 512)
  }

  @MainActor @Test func flightHasNoDecorativePlanetAndUsesNativeWindowSize() throws {
    var game = Game(executive: false)
    game.launch()
    game.bodies = []
    let frame = Display.cockpit(game, width: 1379, height: 800)
    #expect(
      !frame.worldGraphics.contains {
        if case .ellipse = $0 { return true }
        return false
      })
    let image = try #require(imageForGame(game, width: 1379, height: 800, scale: 2))
    #expect(image.width == 2758 && image.height == 1600)
    #expect(imageForGame(game, width: 0, height: 800) == nil)
    #expect(imageForGame(game, width: 5000, height: 800) == nil)
  }

  @MainActor @Test func changingThrottleCannotTeleportStarsOrAddTails() throws {
    var game = Game(executive: false)
    game.screen = .front
    game.bodies = []
    game.time = 100
    game.speed = 20
    let before = try #require(
      imageFor(Display.render(game, rasterizeGraphics: false), pixelSize: 768))
    game.speed = 32
    let after = try #require(
      imageFor(Display.render(game, rasterizeGraphics: false), pixelSize: 768))
    let first = try #require(before.dataProvider?.data)
    let second = try #require(after.dataProvider?.data)
    // The cockpit speed gauge changes, but space must not move until the next tick.
    let space = (12 * 3 * before.bytesPerRow)..<(176 * 3 * before.bytesPerRow)
    let firstSpace = Data(bytes: CFDataGetBytePtr(first)! + space.lowerBound, count: space.count)
    let secondSpace = Data(bytes: CFDataGetBytePtr(second)! + space.lowerBound, count: space.count)
    #expect(firstSpace == secondSpace)
  }

  @MainActor @Test func nativeGraphicsRenderAtExactOutputSizeAndKeepOriginalGlyphs() throws {
    var game = Game(executive: false)
    game.key("k")
    let frame = Display.render(game, rasterizeGraphics: false)
    let image = try #require(imageFor(frame, pixelSize: 768))
    let data = try #require(image.dataProvider?.data)
    let bytes = try #require(CFDataGetBytePtr(data))
    for y in 8..<15 {
      for x in 0..<256 {
        let expected = UInt8((frame.pixels[y * 256 + x] >> 24) & 255)
        for dy in 0..<3 {
          for dx in 0..<3 {
            #expect(bytes[(y * 3 + dy) * image.bytesPerRow + (x * 3 + dx) * 4] == expected)
          }
        }
      }
    }
    let resized = try #require(imageFor(frame, pixelSize: 1379))
    #expect(resized.width == 1379 && resized.height == 1379)
    let retina = try #require(imageFor(frame, pixelSize: 3072))
    #expect(retina.width == 3072 && retina.height == 3072)
    #expect(imageFor(frame, pixelSize: 0) == nil)
    #expect(imageFor(frame, pixelSize: 8193) == nil)
  }
}

extension NativeViewTests {
  @MainActor @Test func nativeTargetCameraAndEquipmentRenderResponsiveFrames() throws {
    var game = Game(executive: false)
    game.launch()
    game.speed = 0
    for key in "xyzzy" { game.key(String(key)) }
    game.key("return")
    game.bodies = [.init(id: 1, hull: .constrictor, position: .init(0, 0, 1000))]
    game.key("r")
    game.targetPanelExpanded = true
    for width in [512, 1512] {
      for style in ShipDisplayStyle.allCases {
        game.commander.shipDisplayStyle = style
        let image = try #require(imageForGame(game, width: width, height: 768))
        #expect(image.width == width && image.height == 768)
      }
      game.screen = .equipment
      game.selection = Equipment.all.count - 1
      let image = try #require(imageForGame(game, width: width, height: 768))
      #expect(image.width == width)
      game.screen = .front
    }
  }
}

extension NativeViewTests {
  @MainActor @Test func nativeMapsAndSearchRenderWithNoFlightInputLeakage() throws {
    let view = GameView()
    view.game.launch()
    view.game.key("4")
    view.game.key("/")
    view.held = ["a", "x", " "]
    #expect(!view.controls.fire && view.controls.pitch == 0 && view.controls.throttle == 0)
    for width in [512, 1512] {
      for mode in MapColourMode.allCases {
        view.game.mapColour = mode
        let image = try #require(imageForGame(view.game, width: width, height: 768))
        #expect(image.width == width)
      }
      view.game.key("escape")
      view.game.key("5")
      let image = try #require(imageForGame(view.game, width: width, height: 768))
      #expect(image.width == width)
      view.game.key("4")
      view.game.key("/")
    }
  }
  @MainActor @Test func responsiveStationScreensRenderMarketColoursMountsAndScrollableInformation()
    throws
  {
    var game = Game(executive: false)
    game.commander.installLaser(.military, on: .rear)
    for screen in [Screen.market, .buy, .sell, .status, .inventory, .equipment] {
      game.screen = screen
      for width in [512, 1024, 2560] {
        let image = try #require(imageForGame(game, width: width, height: 518))
        #expect(image.width == width && image.height == 518)
        #expect(image.dataProvider?.data != nil)
      }
    }
  }

}

extension NativeViewTests {
  @MainActor @Test func blackjackNativeContactRendersAndMouseInputKeepsFlightNeutral() throws {
    let view = GameView(frame: NSRect(x: 0, y: 0, width: 512, height: 518))
    view.game.commander.galaxy = 1
    view.game.systems = Universe.galaxy(number: 1)
    view.game.commander.system = 241
    view.game.dock()
    view.held = ["a", "x", " "]
    #expect(view.game.screen == .handoff && !view.controls.fire && view.controls.pitch == 0)
    for width in [512, 1024, 2560] {
      let image = try #require(imageForGame(view.game, width: width, height: 518, scale: 2))
      #expect(image.width == width * 2 && image.height == 1036)
      #expect(image.dataProvider?.data != nil)
    }
    let click = try #require(
      NSEvent.mouseEvent(
        with: .leftMouseDown, location: .init(x: 100, y: 48), modifierFlags: [], timestamp: 0,
        windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
    view.mouseDown(with: click)
    #expect(view.pending.first?.hasPrefix("script-page-click:") == true)
    view.game.key("k")
    #expect(PlayerHelp.pages(for: view.game).first?.title == "MISSION DIALOG")
  }
}

extension NativeViewTests {
  @MainActor @Test func rClearsHeldSteeringAndStationGuidanceOwnsTheTrackpad() throws {
    let view = GameView()
    view.game.launch()
    view.game.commander.installTargetingComputer(.military)
    view.game.bodies = [.init(id: 0, hull: .station, position: .init(0, 0, 1500))]
    view.held = ["x", "left", ",", " "]
    view.updateTrackpad(positions: [.zero, .zero, .zero])
    let event = try #require(
      NSEvent.keyEvent(
        with: .keyDown, location: .zero,
        modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: "r",
        charactersIgnoringModifiers: "r", isARepeat: false, keyCode: 15))
    view.keyDown(with: event)
    #expect(view.controls.pitch == 0 && view.controls.roll == 0 && view.controls.yaw == 0)
    view.game.key("r")
    #expect(view.game.dockingComputer && view.controls.throttle == 0 && view.held.isEmpty)
    view.updateTrackpad(positions: [.zero, .zero, .zero])
    #expect(view.controls.throttle == 0 && view.trackpad.fingerCount == 0)
  }

  @MainActor @Test func nativeCatalogueMapsAndCompactScreensRenderAtWindowAndRetinaSizes() throws {
    var game = Game(executive: false)
    game.screen = .status
    game.key("showroom-open")
    game.showroom.selection = "SH165"
    game.showroom.detail = true
    let evidence = ProcessInfo.processInfo.environment["ELITE_UI_EVIDENCE_DIRECTORY"]
    for (width, height, scale) in [(512, 518, 1), (1512, 982, 2)] {
      for screen in [Screen.showroom, .system, .help, .secret, .demo, .title, .equipment, .chart] {
        game.screen = screen
        game.helpReturn = .showroom
        game.time = 5
        let image = try #require(imageForGame(game, width: width, height: height, scale: scale))
        #expect(image.width == width * scale && image.height == height * scale)
        if let evidence {
          let url = URL(fileURLWithPath: evidence, isDirectory: true)
          try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
          let data = try #require(
            NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
          try data.write(to: url.appendingPathComponent("\(screen.rawValue)-\(width).png"))
        }
      }
    }
    game.screen = .chart
    game.key("/")
    game.key("w")
    #expect(game.screen == .chart && game.mapSearch.query == "w")
    game.key("showroom-open")
    #expect(game.screen == .showroom)
    game.key("/")
    game.key("k")
    #expect(game.showroom.searching && game.showroom.query == "k")
    game.key("help-open")
    #expect(game.screen == .help && game.helpReturn == .showroom)
    game.key("help-open")
    #expect(game.screen == .showroom && game.showroom.searching)
    game.key("escape")
    game.showroom.query = ""
    let bounds = ShowroomLayout(width: 768, height: 768, detail: false)
    game.viewportWidth = 768
    game.viewportHeight = 768
    let view = GameView(frame: .init(x: 0, y: 0, width: 768, height: 768))
    view.game = game
    let event = try #require(
      NSEvent.mouseEvent(
        with: .leftMouseDown,
        location: .init(x: bounds.buttons[3].x + 8, y: 768 - bounds.buttons[3].y - 8),
        modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
        eventNumber: 1, clickCount: 1, pressure: 1))
    view.mouseDown(with: event)
    #expect(view.pending.first?.hasPrefix("showroom-click:") == true)
  }
  @MainActor @Test func macBookControlsUseArrowsDeleteReturnAndSafeModifierCommands() throws {
    let view = GameView()
    view.game.launch()
    func event(
      _ code: UInt16, _ text: String = "", flags: NSEvent.ModifierFlags = [], repeated: Bool = false
    ) throws -> NSEvent {
      try #require(
        NSEvent.keyEvent(
          with: .keyDown, location: .zero, modifierFlags: flags,
          timestamp: 0, windowNumber: 0, context: nil, characters: text,
          charactersIgnoringModifiers: text, isARepeat: repeated, keyCode: code))
    }
    for (code, text) in [(UInt16(126), ""), (123, ""), (49, " "), (36, "\r")] {
      view.keyDown(with: try event(code, text))
    }
    #expect(view.controls.pitch == 1 && view.controls.roll == 1)
    #expect(view.controls.throttle == 1 && view.controls.fire)
    view.game.key("4")
    #expect(view.held.isEmpty && view.controls.throttle == 0 && !view.controls.fire)
    view.keyDown(with: try event(125, flags: .option))
    #expect(nativeQueuedKey(view.pending.last) == "pagedown")
    view.keyDown(with: try event(126, flags: .option))
    #expect(nativeQueuedKey(view.pending.last) == "pageup")
    view.game.key("/")
    view.game.key("a")
    #expect(view.performKeyEquivalent(with: try event(51, flags: .command)))
    #expect(view.pending.last == "search-clear")
    view.game.key(view.pending.removeLast())
    #expect(view.game.mapSearch.query.isEmpty)
    view.keyDown(with: try event(0, "a", flags: .command))
    #expect(!view.held.contains("a"))
    view.keyDown(with: try event(8, "c", repeated: true))
    #expect(view.pending.last == "c")
    view.game.key("escape")
    view.game.key("0")
    view.keyDown(with: try event(51))
    #expect(view.controls.throttle == -1)
    view.keyUp(with: try event(51))
    #expect(view.controls.throttle == 0)
    view.game.commander.equipment.insert("Energy Bomb")
    view.game.commander.installTargetingComputer(.basic)
    view.game.key("tab")
    #expect(view.game.commander.equipment.contains("Energy Bomb"))
    view.game.paused = true
    #expect(view.held.isEmpty && !view.controls.fire)
  }

}

// Assert the native key protocol without treating the proof envelope as the user's key name.
private func nativeQueuedKey(_ event: String?) -> String? {
  guard let event else { return nil }
  guard event.hasPrefix("script-page-key:") else { return event }
  return event.dropFirst("script-page-key:".count).split(separator: ":", maxSplits: 1).last.map(
    String.init)
}

@MainActor
private final class HeadlessScriptInput {
  let folder: URL
  let preferences: UserDefaults
  let file: URL
  let delegate: AppDelegate
  let view: GameView
  init() async throws {
    let id = UUID().uuidString
    folder = FileManager.default.temporaryDirectory.appendingPathComponent(id)
    preferences = try #require(UserDefaults(suiteName: id))
    file = folder.appendingPathComponent("commander.json")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try JSONEncoder().encode(Commander()).write(to: file)
    delegate = AppDelegate(
      restoreOnLaunch: false,
      saves: CommanderSaveSession(preferences: preferences, defaultURL: file))
    view = GameView(frame: NSRect(x: 0, y: 0, width: 512, height: 518))
    do {
      try await delegate.runtime.load(from: file, persistMigrations: false)
      let example = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(
          "docs/mission-packs/station-conversation")
      try await delegate.runtime.installScriptPack(
        from: example,
        destination: folder.appendingPathComponent("packs"))
      await delegate.runtime.setViewport(width: 512, height: 518)
    } catch {
      clean()
      throw error
    }
  }
  func clean() {
    preferences.removePersistentDomain(forName: folder.lastPathComponent)
    try? FileManager.default.removeItem(at: folder)
  }
  func frame() async {
    view.game = await delegate.runtime.snapshot()
    view.updateLayer()
  }
  func question() async throws -> UUID {
    await delegate.runtime.key("contacts-open")
    await delegate.runtime.key("return")
    await delegate.runtime.key("contacts-open")
    await frame()
    return try #require(view.game.scriptOffer)
  }
  func press(_ key: String) throws {
    let code: UInt16 = key == "return" ? 36 : key == "down" ? 125 : 11
    let text = key == "return" ? "\r" : key == "down" ? "" : "b"
    let event = try #require(
      NSEvent.keyEvent(
        with: .keyDown, location: .zero,
        modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: text,
        charactersIgnoringModifiers: text, isARepeat: false, keyCode: code))
    view.keyDown(with: event)
  }
  func clickConfirm() throws {
    let location = view.convert(NSPoint(x: 40, y: 478), to: nil)
    let event = try #require(
      NSEvent.mouseEvent(
        with: .leftMouseDown, location: location,
        modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
        eventNumber: 0, clickCount: 1, pressure: 1))
    view.mouseDown(with: event)
  }
  func drain() async { await delegate.processPendingCommands(in: view) }
}
