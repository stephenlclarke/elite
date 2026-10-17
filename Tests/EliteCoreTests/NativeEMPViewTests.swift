import AppKit
import Foundation
import Testing

@testable import EliteCore
@testable import EliteMac

@MainActor
private func nativeEMPFrameImage(_ frame: Frame) throws -> CGImage {
  let context = try #require(
    CGContext(
      data: nil, width: 768, height: 768, bitsPerComponent: 8, bytesPerRow: 768 * 4,
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
  )
  context.setFillColor(CGColor(gray: 0, alpha: 1))
  context.fill(CGRect(x: 0, y: 0, width: 768, height: 768))
  context.translateBy(x: 0, y: 768)
  context.scaleBy(x: 1, y: -1)
  drawFrame(frame, context: context, rect: CGRect(x: 0, y: 0, width: 768, height: 768))
  return try #require(context.makeImage())
}

private func nativeEMPBytes(_ image: CGImage) throws -> Data {
  let data = try #require(image.dataProvider?.data)
  return data as Data
}

@MainActor
private func captureNativeEMPView(_ view: GameView) throws -> (image: CGImage, seconds: Double) {
  try #require(view.bounds.width == 768 && view.bounds.height == 768)
  let context = try #require(
    CGContext(
      data: nil, width: 768, height: 768, bitsPerComponent: 8, bytesPerRow: 768 * 4,
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
  )
  context.translateBy(x: 0, y: 768)
  context.scaleBy(x: 1, y: -1)
  NSGraphicsContext.saveGraphicsState()
  defer { NSGraphicsContext.restoreGraphicsState() }
  NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
  let started = ProcessInfo.processInfo.systemUptime
  view.draw(view.bounds)
  let seconds = ProcessInfo.processInfo.systemUptime - started
  return (try #require(context.makeImage()), seconds)
}

@MainActor
private func verifyNativeEMPPixels(_ view: GameView, bodyID: Int, ink: Ink, stage: String) throws {
  let original = view.game
  defer { view.game = original }
  for style in ShipDisplayStyle.allCases {
    var game = original
    game.commander.shipDisplayStyle = style
    let started = ProcessInfo.processInfo.systemUptime
    let frame = Display.presentation(game, width: 768, height: 768)
    view.game = game
    let captured = try captureNativeEMPView(view)
    let image = captured.image
    let oracleStarted = ProcessInfo.processInfo.systemUptime
    let oracle = try #require(imageForGame(game, width: 768, height: 768))
    let oracleSeconds = ProcessInfo.processInfo.systemUptime - oracleStarted
    #expect(try nativeEMPBytes(image) == nativeEMPBytes(oracle))
    try #require(captured.seconds > 0 && oracleSeconds > 0)
    let pixels = try nativeEMPBytes(image)
    #expect(try pixels == nativeEMPBytes(nativeEMPFrameImage(frame)))
    var withoutCue = frame
    func stripped(_ graphics: [Graphic]) -> [Graphic] {
      graphics.filter { if case .glow = $0 { false } else { true } }
    }
    withoutCue.worldGraphics = stripped(frame.worldGraphics)
    withoutCue.graphics = stripped(frame.graphics)
    let baseline = try nativeEMPBytes(nativeEMPFrameImage(withoutCue))
    var colouredDifference = 0
    var white = 0
    for y in 0..<768 {
      for x in 0..<768 {
        // The established native bitmap convention addresses logical y directly after the y-flip.
        let offset = y * image.bytesPerRow + x * 4
        let r = Int(pixels[offset])
        let g = Int(pixels[offset + 1])
        let b = Int(pixels[offset + 2])
        let inside = frame.flightClip.contains(.init(Double(x), Double(y)))
        if inside, r > 230, g > 230, b > 230 { white += 1 }
        if pixels[offset..<offset + 4] != baseline[offset..<offset + 4] {
          #expect(inside)
          if ink == .red, r > g + 20, r > b + 20 { colouredDifference += 1 }
          if ink == .orange, r > g, g > b + 10 { colouredDifference += 1 }
        }
      }
    }
    #expect(colouredDifference > 0)
    if style == .whiteWireframe {
      #expect(!frame.shipLines.isEmpty && frame.shipLines.allSatisfy { $0.ink == .white })
      #expect(white > 0)
    }
    let index = try #require(game.bodies.firstIndex { $0.id == bodyID })
    for hidden in [false, true] {
      var occluded = game
      if hidden {
        occluded.bodies[index].position = .init(10000, 0, 1000)
      } else {
        occluded.bodies.append(.init(id: 999, hull: .station, position: .init(0, 0, 350)))
      }
      let clipped = Display.presentation(occluded, width: 768, height: 768)
      #expect(!clipped.worldGraphics.contains { if case .glow = $0 { true } else { false } })
      var strippedFrame = clipped
      strippedFrame.worldGraphics = stripped(clipped.worldGraphics)
      strippedFrame.graphics = stripped(clipped.graphics)
      view.game = occluded
      let actual = try captureNativeEMPView(view).image
      let clippedOracle = try #require(imageForGame(occluded, width: 768, height: 768))
      #expect(try nativeEMPBytes(actual) == nativeEMPBytes(clippedOracle))
      #expect(try nativeEMPBytes(actual) == nativeEMPBytes(nativeEMPFrameImage(strippedFrame)))
    }
    if let path = ProcessInfo.processInfo.environment["ELITE_UI_EVIDENCE_DIRECTORY"] {
      let directory = URL(fileURLWithPath: path, isDirectory: true)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let name = "emp-\(stage)-\(style.rawValue)"
      let png = try #require(
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
      try png.write(to: directory.appendingPathComponent(name + ".png"))
      let evidence: [String: Any] = [
        "source": ProcessInfo.processInfo.environment["ELITE_VALIDATION_SOURCE_SHA"] ?? "local",
        "colouredCuePixels": colouredDifference, "whiteWorldPixels": white,
        "actualDrawSeconds": captured.seconds, "oracleDrawSeconds": oracleSeconds,
        "actualToOracleRatio": captured.seconds / oracleSeconds,
        "verificationSeconds": ProcessInfo.processInfo.systemUptime - started,
        "foregroundAndOffscreenCuePixels": 0,
      ]
      try JSONSerialization.data(withJSONObject: evidence, options: [.prettyPrinted, .sortedKeys])
        .write(to: directory.appendingPathComponent(name + ".json"))
    }
  }
}

extension NativeViewTests {
  @MainActor @Test func nativeEMPKeysDisableEjectAndPublishTheSameSourceAndPeople() async throws {
    _ = NSApplication.shared
    let previousMenu = NSApp.mainMenu
    let identifier = "elite-native-emp-" + UUID().uuidString
    let preferences = try #require(UserDefaults(suiteName: identifier))
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(identifier)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("commander.json")
    var baseline = try empFixture(hostile: true)
    baseline.selectFlightTool(.combatLaser)
    let profile = try #require(SalvageCatalogue.empProfile(catalogueShipID: "SH023"))
    let cargoSection = try #require(profile.sections.first { $0.kind == .cargo })
    let forward = cargoSection.normal.unit * -1
    let cardinal = abs(forward.y) < 0.8 ? Vector3(0, 1, 0) : .init(1, 0, 0)
    var basis = Basis3()
    basis.z = forward
    basis.x = cardinal.cross(forward).unit
    basis.y = forward.cross(basis.x).unit
    baseline.bodies[0].orientation = basis.transposed
    baseline.bodies[0].position = .init(0, 0, 1000)
    baseline.bodies[0].physical?.velocity = .init(0, 0, 0)
    baseline.bodies[0].physical?.angularVelocity = .init(0, 0, 0)
    let original = baseline.bodies[0]
    let writer = GameRuntime(game: baseline)
    try await writer.save(to: file)
    let delegate = AppDelegate(
      restoreOnLaunch: false,
      saves: CommanderSaveSession(preferences: preferences, defaultURL: file))
    delegate.applicationDidFinishLaunching(
      Notification(name: NSApplication.didFinishLaunchingNotification))
    let window = try #require(delegate.window)
    defer {
      delegate.windowWillClose(Notification(name: NSWindow.willCloseNotification))
      window.orderOut(nil)
      window.delegate = nil
      NSApp.mainMenu = previousMenu
      preferences.removePersistentDomain(forName: identifier)
      try? FileManager.default.removeItem(at: directory)
    }
    let view = try #require(window.contentView as? GameView)
    let loop = try #require(delegate.loop)
    loop.cancel()
    await loop.value
    try await delegate.runtime.load(from: file, persistMigrations: false)
    view.game = await delegate.runtime.snapshot()
    view.pending.removeAll()
    func event(_ code: UInt16, _ text: String, down: Bool) throws -> NSEvent {
      try #require(
        NSEvent.keyEvent(
          with: down ? .keyDown : .keyUp, location: .zero, modifierFlags: [],
          timestamp: 0, windowNumber: window.windowNumber, context: nil,
          characters: text, charactersIgnoringModifiers: text, isARepeat: false, keyCode: code))
    }
    for _ in 0..<3 {
      view.keyDown(with: try event(13, "w", down: true))
      view.keyUp(with: try event(13, "w", down: false))
      await delegate.processPendingCommands(in: view)
    }
    try #require(view.game.selectedFlightTool == .empPirateBlaster)
    try verifyNativeEMPPixels(view, bodyID: original.id, ink: .red, stage: "armed")
    view.keyDown(with: try event(36, "\r", down: true))
    await delegate.processFrame(in: view, delta: { 0.1 })
    view.keyUp(with: try event(36, "\r", down: false))
    let source = try #require(view.game.commander.savedEMPState?.records.keys.first)
    let disabled = try #require(view.game.bodies.first { $0.physical?.empSource == source })
    #expect(disabled.id == original.id && disabled.energy == original.energy)
    #expect(view.game.targetColourCue(for: disabled) == .recoverable)
    #expect(view.game.empTargetStatus(disabled)?.contains("CREW ABOARD") == true)
    try verifyNativeEMPPixels(view, bodyID: disabled.id, ink: .orange, stage: "disabled-occupied")
    for _ in 0..<40 { await delegate.processFrame(in: view, delta: { 0.1 }) }
    let record = try #require(view.game.commander.savedEMPState?.records[source])
    try #require(record.crewAboard == 0 && record.pods.count == record.crewTotal)
    let salvage = try #require(view.game.bodies.first { $0.physical?.empSource == source })
    #expect(salvage.id == original.id && view.game.targetColourCue(for: salvage) == .recoverable)
    let metadata = try #require(salvage.physical?.salvage)
    let context = try #require(view.game.gameplayContext())
    #expect(view.game.salvageCuttingIsAllowed(salvage, metadata: metadata, context: context))
    let people = Set(view.game.bodies.compactMap { $0.physical?.empCrewPod })
    #expect(people.count == record.crewTotal)
    try verifyNativeEMPPixels(view, bodyID: salvage.id, ink: .orange, stage: "disabled-empty")
    // Use the player's real filter/Tab target commands and controller to reach a cutter hold.
    for (code, text) in [(UInt16(3), "f"), (3, "f"), (48, "\t")] {
      view.keyDown(with: try event(code, text, down: true))
      view.keyUp(with: try event(code, text, down: false))
      await delegate.processPendingCommands(in: view)
    }
    for _ in 0..<2400 where view.game.workGuidance?.holding != true {
      await delegate.processFrame(in: view, delta: { 0.1 })
    }
    try #require(view.game.workGuidance?.holding == true)
    try #require(view.game.selectedFlightTool == .salvageCutter)
    let section = WreckSectionIdentity(wreck: record.wreck, section: cargoSection.index)
    try #require(view.game.workGuidance?.surface.section == section)
    view.keyDown(with: try event(36, "\r", down: true))
    for _ in 0..<1200 where !view.game.commander.salvageLedger.isDepleted(section) {
      await delegate.processFrame(in: view, delta: { 0.1 })
    }
    view.keyUp(with: try event(36, "\r", down: false))
    try #require(view.game.commander.salvageLedger.isDepleted(section))
    let food = view.game.commander.salvageLedger.pendingLots.reduce(0) { total, lot in
      guard lot.identity.section.wreck == record.wreck,
        case .commodity(let amount)? = lot.loot?.content, amount.commodity == .food
      else { return total }
      return total + amount.quantity
    }
    #expect(
      food + view.game.commander.cargo[CommodityIdentity.food.rawValue]
        - baseline.commander.cargo[CommodityIdentity.food.rawValue] == 2)
    #expect(view.game.commander.savedEMPState?.records[source]?.pods.count == people.count)
    delegate.queueCommanderFile(.saveActive)
    await delegate.processPendingCommands(in: view)
    let bytes = try Data(contentsOf: file)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    let (saved, _) = try ScriptSaveStore.read(bytes, from: file)
    #expect(pointer.schemaVersion == 22)
    #expect(saved.savedEMPState?.records[source]?.pods.count == people.count)
    #expect(saved.savedEMPState?.records[source]?.hull.body.id == original.id)
  }
}
