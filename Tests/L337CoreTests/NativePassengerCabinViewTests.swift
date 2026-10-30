import AppKit
import Foundation
import Testing

@testable import L337Core
@testable import L337Mac

private func cabinShopGame() throws -> Game {
  var game = Game(executive: false)
  game.screen = .equipment
  game.commander.credits = 1_000_000
  game.selection = try #require(
    Equipment.all.firstIndex { $0.name == PassengerCabin.equipmentName })
  return game
}

@Test func cabinActorAPIsAndRawShopKeysRequireADurableWriter() async throws {
  let runtime = GameRuntime(game: try cabinShopGame())
  let before = await runtime.snapshot().commander
  let quote = await runtime.passengerBerthQuote()
  await #expect(throws: SaveError.self) { try await runtime.confirmPassengerBerth(quote) }
  await runtime.key("return")
  #expect(await runtime.snapshot().commander == before)
  var fitted = try cabinShopGame()
  let id = try fitted.confirmPassengerBerth(fitted.passengerBerthQuote)
  let noWriter = GameRuntime(game: fitted)
  let original = await noWriter.snapshot()
  let context = try #require(original.equipmentPurchaseContext)
  let store = try #require(context.passengerBerthFitting(fitted: false))
  #expect(await noWriter.equipmentTransaction(.passengerBerth(store)) == .refused(.invalidState))
  await #expect(throws: SaveError.self) {
    try await noWriter.setPassengerBerthFitted(id, fitted: false)
  }
  await noWriter.key("s")
  let unchanged = await noWriter.snapshot()
  #expect(unchanged.commander == original.commander)
  #expect(unchanged.inventoryContextEpoch == original.inventoryContextEpoch)
  #expect(unchanged.commander.accommodation.fitted == [id])
}

@Test func cabinFittingIntentRefusesStalePausedWrongStationAndCapacityWithoutCharging() throws {
  var game = try cabinShopGame()
  let id = try game.confirmPassengerBerth(game.passengerBerthQuote)
  let placeIDs = game.commander.accommodation.ownedBerths.map(\.id)
  let store = try #require(game.equipmentPurchaseContext?.passengerBerthFitting(fitted: false))
  for changed in ["pause", "station", "selection", "epoch"] {
    var candidate = game
    switch changed {
    case "pause": candidate.paused = true
    case "station":
      candidate.dock(atMainStation: false)
      candidate.screen = .equipment
    case "selection": candidate.selection = 0
    default: candidate.inventoryContextEpoch = .init()
    }
    let before = candidate.commander
    #expect(!candidate.performEquipmentMutation(.passengerBerth(store)).applied)
    #expect(candidate.commander == before)
  }
  let cash = game.commander.credits
  #expect(game.performEquipmentMutation(.passengerBerth(store)).applied)
  #expect(game.commander.accommodation.storedCabins.map(\.id) == [id])
  #expect(game.commander.accommodation.storedBerths.map(\.id) == placeIDs)
  #expect(!game.performEquipmentMutation(.passengerBerth(store)).applied)
  game.commander.cargo[0] = game.commander.standardCargoCapacity
  let refit = try #require(game.equipmentPurchaseContext?.passengerBerthFitting(fitted: true))
  let full = game.commander
  #expect(game.performEquipmentMutation(.passengerBerth(refit)) == .refused(.fittingUnavailable))
  #expect(game.commander == full && game.commander.credits == cash)
  #expect(game.commander.accommodation.storedCabins.map(\.id) == [id])
  #expect(game.commander.accommodation.storedBerths.map(\.id) == placeIDs)
}

@MainActor
private struct NativeCabinFixture {
  let delegate: AppDelegate
  let view: GameView
  let window: NSWindow
  let directory: URL
  let save: URL
  let preferences: UserDefaults
  let identifier: String
  let menu: NSMenu?

  static func open(source: Game? = nil) async throws -> Self {
    _ = NSApplication.shared
    let menu = NSApp.mainMenu
    let identifier = "elite-native-cabins-" + UUID().uuidString
    let preferences = try #require(UserDefaults(suiteName: identifier))
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(identifier)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let save = directory.appendingPathComponent("commander.json")
    let seed = GameRuntime(game: try source ?? cabinShopGame(), saveURL: save)
    try await seed.save(to: save)
    let saves = CommanderSaveSession(preferences: preferences, defaultURL: save)
    let delegate = AppDelegate(
      restoreOnLaunch: false, saves: saves,
      windowSize: .init(width: 900, height: 700))
    do {
      delegate.applicationDidFinishLaunching(
        Notification(name: NSApplication.didFinishLaunchingNotification))
      let window = try #require(delegate.window)
      let view = try #require(window.contentView as? GameView)
      let loop = try #require(delegate.loop)
      loop.cancel()
      await loop.value
      try await delegate.runtime.load(from: save, persistMigrations: false)
      await delegate.runtime.key("3")
      for _ in EquipmentGroups.itemIndices { await delegate.runtime.key("down") }
      await delegate.runtime.key("up")
      view.game = await delegate.runtime.snapshot()
      try #require(
        Equipment.all[view.game.selection].name == PassengerCabinGrade.stateroomSingle.equipmentName
      )
      view.pending.removeAll()
      #expect(view.game.passengerBerthSelected)
      return .init(
        delegate: delegate, view: view, window: window, directory: directory, save: save,
        preferences: preferences, identifier: identifier, menu: menu)
    } catch {
      delegate.windowWillClose(Notification(name: NSWindow.willCloseNotification))
      delegate.window?.orderOut(nil)
      preferences.removePersistentDomain(forName: identifier)
      NSApp.mainMenu = menu
      try? FileManager.default.removeItem(at: directory)
      throw error
    }
  }

  func clean() {
    delegate.windowWillClose(Notification(name: NSWindow.willCloseNotification))
    window.orderOut(nil)
    NSApp.mainMenu = menu
    preferences.removePersistentDomain(forName: identifier)
    try? FileManager.default.removeItem(at: directory)
  }

  func paint() throws {
    let width = Int(view.bounds.width)
    let height = Int(view.bounds.height)
    let context = try #require(
      CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.translateBy(x: 0, y: Double(height))
    context.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    view.draw(view.bounds)
    #expect(context.makeImage() != nil)
  }

  func queue(_ code: UInt16, text: String, repeatKey: Bool = false) throws {
    for type in [NSEvent.EventType.keyDown, .keyUp] {
      let event = try #require(
        NSEvent.keyEvent(
          with: type, location: .zero, modifierFlags: [],
          timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: text,
          charactersIgnoringModifiers: text, isARepeat: repeatKey, keyCode: code))
      if type == .keyDown { view.keyDown(with: event) } else { view.keyUp(with: event) }
    }
  }

  func generations() throws -> Int {
    let root = save.appendingPathExtension("missions")
    guard FileManager.default.fileExists(atPath: root.path) else { return 0 }
    return try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
      .count
  }

  func exportEvidence(_ stage: String) throws {
    guard let path = ProcessInfo.processInfo.environment["ELITE_UI_EVIDENCE_DIRECTORY"] else {
      return
    }
    let output = URL(fileURLWithPath: path, isDirectory: true)
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    let snapshot = view.game
    try #require(snapshot.passengerBerthSelected)
    let accommodation = snapshot.commander.accommodation
    for (width, height) in [(512, 518), (1512, 982)] {
      let image = try #require(imageForGame(snapshot, width: width, height: height, scale: 1))
      #expect(image.width == width && image.height == height)
      let data = try #require(
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
      let name = "passenger-cabins-\(stage)-\(width)x\(height)"
      try data.write(to: output.appendingPathComponent(name + ".png"))
      let receipt: [String: Any] = [
        "source": ProcessInfo.processInfo.environment["ELITE_VALIDATION_SOURCE_SHA"] ?? "local",
        "stage": stage, "width": width, "height": height, "scale": 1,
        "selection": snapshot.selection, "selectedItem": Equipment.all[snapshot.selection].name,
        "fittedIDs": accommodation.fitted.map(\.uuidString).sorted(),
        "storedIDs": accommodation.storedBerths.map { $0.id.uuidString }.sorted(),
        "creditsTenths": snapshot.commander.credits, "cargoTonnes": snapshot.commander.cargoTonnes,
        "pngSHA256": ScriptPackLibrary.hash(data),
      ]
      try JSONSerialization.data(withJSONObject: receipt, options: [.prettyPrinted, .sortedKeys])
        .write(to: output.appendingPathComponent(name + ".json"))
    }
  }
}

extension NativeViewTests {
  @MainActor @Test func paintedNativeCabinPurchaseStoreRefitAndFailedWritePreserveCustody()
    async throws
  {
    let fixture = try await NativeCabinFixture.open()
    defer { fixture.clean() }
    try fixture.paint()
    let cash = fixture.view.game.commander.credits
    let beforeBuy = fixture.view.game.commander
    let price = fixture.view.game.passengerBerthQuote.price
    try #require(!beforeBuy.unlimitedCash && price > 0 && price == PassengerCabin.price)
    let beforeGenerations = try fixture.generations()
    let beforeBytes = try Data(contentsOf: fixture.save)
    let beforePointer = try JSONDecoder().decode(ScriptSavePointer.self, from: beforeBytes)
    try #require(beforeGenerations > 0 && beforePointer.schemaVersion == 26)
    try #require(
      beforePointer.scope == "commander" && beforePointer.valueCodec == ScriptValueStorage.codec)
    let (beforeStored, beforeWorld) = try ScriptSaveStore.read(beforeBytes, from: fixture.save)
    #expect(
      beforeStored == beforeBuy && beforeWorld.valid && beforeWorld.consistent(with: beforeBuy))
    let generationRoot = fixture.save.appendingPathExtension("missions")
    let originalGenerations = try FileManager.default.contentsOfDirectory(
      atPath: generationRoot.path)
    let originalFiles: [URL: Data] = try {
      let enumeration = FileManager.default.enumerator(
        at: generationRoot, includingPropertiesForKeys: [.isRegularFileKey])
      let entries = try #require(enumeration)
      var originalFiles: [URL: Data] = [:]
      for case let url as URL in entries {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey])
        if values.isRegularFile == true { originalFiles[url] = try Data(contentsOf: url) }
      }
      return originalFiles
    }()
    try #require(!originalFiles.isEmpty)
    try fixture.queue(36, text: "\r")
    #expect(fixture.view.pending == ["equipment-purchase"])
    await fixture.delegate.processPendingCommands(in: fixture.view)
    let berth = try #require(fixture.view.game.commander.accommodation.fittedBerths.first?.id)
    try #require(!beforeBuy.accommodation.ownedBerths.contains { $0.id == berth })
    let cabin = try #require(fixture.view.game.commander.accommodation.fittedCabins.first?.id)
    #expect(cabin != berth)
    var expectedPurchase = beforeBuy
    expectedPurchase.accommodation.ownedCabins.append(.init(id: cabin, grade: .stateroomSingle))
    expectedPurchase.accommodation.ownedBerths.append(PassengerBerth(id: berth, cabinID: cabin))
    expectedPurchase.accommodation.fitted.insert(cabin)
    expectedPurchase.credits -= price
    #expect(fixture.view.game.commander == expectedPurchase)
    #expect(fixture.view.game.commander.credits == cash - PassengerCabin.price)
    #expect(fixture.view.game.commander.cargoTonnes == 5)
    try fixture.exportEvidence("fitted")
    let afterBuy = try fixture.generations()
    #expect(afterBuy == beforeGenerations + 1)
    let afterBytes = try Data(contentsOf: fixture.save)
    let afterPointer = try JSONDecoder().decode(ScriptSavePointer.self, from: afterBytes)
    #expect(afterPointer.generation != beforePointer.generation && afterBytes != beforeBytes)
    #expect(afterPointer.schemaVersion == 26 && afterPointer.scope == "commander")
    #expect(afterPointer.valueCodec == ScriptValueStorage.codec)
    let (afterStored, afterWorld) = try ScriptSaveStore.read(afterBytes, from: fixture.save)
    #expect(
      afterStored == expectedPurchase && afterStored == fixture.view.game.commander
        && afterWorld.valid
        && afterWorld.consistent(with: afterStored))
    #expect(afterStored.equipmentInventory == beforeBuy.equipmentInventory)
    #expect(afterStored.equipmentPurchaseHistory == beforeBuy.equipmentPurchaseHistory)
    #expect(
      afterStored.cargo == beforeBuy.cargo && afterStored.salvageLedger == beforeBuy.salvageLedger)
    let currentGenerations = try FileManager.default.contentsOfDirectory(
      atPath: generationRoot.path)
    #expect(Set(originalGenerations).isSubset(of: Set(currentGenerations)))
    #expect(Set(currentGenerations).subtracting(originalGenerations) == [afterPointer.generation])
    for (url, original) in originalFiles {
      let retained = try Data(contentsOf: url)
      #expect(retained == original)
    }
    try fixture.paint()
    try fixture.queue(1, text: "s", repeatKey: true)
    #expect(fixture.view.pending.isEmpty)
    try fixture.queue(1, text: "s")
    #expect(fixture.view.pending == ["passenger-berth-fitting"])
    #expect(fixture.view.pendingPassengerBerthFittings.count == 1)
    await fixture.delegate.processPendingCommands(in: fixture.view)
    #expect(fixture.view.game.commander.accommodation.storedBerths.map(\.id) == [berth])
    #expect(fixture.view.game.commander.cargoTonnes == 0)
    try fixture.exportEvidence("stored")
    #expect(try fixture.generations() == afterBuy + 1)
    try fixture.paint()
    try fixture.queue(15, text: "r")
    await fixture.delegate.processPendingCommands(in: fixture.view)
    #expect(fixture.view.game.commander.accommodation.fittedBerths.map(\.id) == [berth])
    #expect(fixture.view.game.commander.credits == cash - PassengerCabin.price)
    #expect(try fixture.generations() == afterBuy + 2)

    try fixture.paint()
    try fixture.queue(1, text: "s")
    let stale = try #require(fixture.view.pendingPassengerBerthFittings.first)
    // Returning to identical cabin custody still invalidates the previously painted epoch.
    try await fixture.delegate.runtime.setPassengerBerthFitted(cabin, fitted: false)
    try await fixture.delegate.runtime.setPassengerBerthFitted(cabin, fitted: true)
    let beforeStale = await fixture.delegate.runtime.snapshot().commander
    await fixture.delegate.processPendingCommands(in: fixture.view)
    #expect(fixture.view.game.commander == beforeStale)
    #expect(
      await fixture.delegate.runtime.equipmentTransaction(.passengerBerth(stale))
        == .refused(.staleContext))

    try fixture.paint()
    let before = fixture.view.game.commander
    let oldBytes = try Data(contentsOf: fixture.save)
    let root = fixture.save.appendingPathExtension("missions")
    let backup = fixture.directory.appendingPathComponent("held-generations")
    try FileManager.default.moveItem(at: root, to: backup)
    var blocked = true
    defer {
      if blocked {
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.moveItem(at: backup, to: root)
      }
    }
    try Data("blocked".utf8).write(to: root)
    try fixture.queue(1, text: "s")
    await fixture.delegate.processPendingCommands(in: fixture.view)
    #expect(fixture.view.game.commander == before)
    #expect(try Data(contentsOf: fixture.save) == oldBytes)
    #expect(fixture.view.game.commander.accommodation.fitted == [cabin])
    #expect(fixture.view.game.message == "MISSION SAVE FAILED - ACTION NOT COMMITTED")
    try FileManager.default.removeItem(at: root)
    try FileManager.default.moveItem(at: backup, to: root)
    blocked = false
    let restored = GameRuntime()
    try await restored.load(from: fixture.save, persistMigrations: false)
    #expect(await restored.snapshot().commander == before)
  }

  @MainActor @Test func paintedCabinStorageCannotRemoveAnActualPassengerOrActWhilePaused()
    async throws
  {
    var game = try cabinShopGame()
    let berth = try game.confirmPassengerBerth(game.passengerBerthQuote)
    let packURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/scripted-passengers")
    let pack = try ScriptPackLibrary.read(packURL)
    game.scriptPacks = [pack]
    _ = try game.acceptScriptMission(pack)
    #expect(game.commander.accommodation.fittedBerths.first?.use.used == true)
    let fixture = try await NativeCabinFixture.open(source: game)
    defer { fixture.clean() }
    let before = fixture.view.game.commander
    #expect(before.accommodation.fitted == [berth] && before.accommodation.people.count == 1)
    let bytes = try Data(contentsOf: fixture.save)
    try fixture.paint()
    try fixture.queue(1, text: "s")
    #expect(fixture.view.pending.isEmpty && fixture.view.pendingPassengerBerthFittings.isEmpty)
    #expect(fixture.view.game.commander == before)
    await fixture.delegate.runtime.key("pause")
    fixture.view.game = await fixture.delegate.runtime.snapshot()
    #expect(fixture.view.game.paused)
    try fixture.paint()
    try fixture.queue(15, text: "r")
    #expect(fixture.view.pending.isEmpty)
    #expect(fixture.view.game.commander == before)
    #expect(try Data(contentsOf: fixture.save) == bytes)
  }

}

@Test func cabinStorefrontDoesNotBecomeLegacyHardwareOrBreakMaximumRefits() throws {
  #expect(Equipment.all.last?.name == PassengerCabinGrade.stateroomDouble.equipmentName)
  #expect(!Equipment.validNames.contains(PassengerCabin.equipmentName))
  #expect(!Equipment.maximumHardware.contains(PassengerCabin.equipmentName))
  #expect(EquipmentRuntimeCatalog.node(for: PassengerCabin.equipmentName) == nil)
  var forged = Commander()
  forged.equipment.insert(PassengerCabin.equipmentName)
  #expect(!forged.valid)
  #expect(throws: CommanderEquipmentError.self) { try forged.prepareEquipment() }
  var maximum = Commander()
  maximum.xyzzyActive = true
  maximum.equipment = Equipment.maximumHardware
  maximum.fuelStorageUnits = FuelStorage.maximumCount
  try maximum.initializeEquipment(owner: UUID(), hull: UUID(), legacy: false, xyzzyGrant: true) {
    UUID()
  }
  maximum.mirrorFittedEquipment()
  #expect(maximum.valid && maximum.fuelStorageUnits == 4)
  #expect(maximum.equipmentInventory?.items.isEmpty == false)
  #expect(
    maximum.equipmentInventory?.items.allSatisfy {
      $0.node.key != PassengerCabin.equipmentName
        && ($0.provenance == .standard || $0.provenance == .xyzzy)
    } == true)
  #expect(maximum.accommodation.ownedBerths.isEmpty)
  var game = Game(executive: false)
  game.enableXYZzy()
  game.restoreXYZzyCobra()
  #expect(game.commander.xyzzyActive && game.commander.valid)
  #expect(game.commander.equipment.contains("Energy Bomb"))
  #expect(game.commander.accommodation.ownedBerths.isEmpty)
}
