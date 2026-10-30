import AppKit
import Testing

@testable import L337Core
@testable import L337Mac

extension NativeViewTests {
  @MainActor @Test func nativeMissionPaintProofRequiresActualPaintAndMatchingBounds() throws {
    _ = NSApplication.shared
    let view = GameView(frame: .init(x: 0, y: 0, width: 512, height: 518))
    view.game = Game(executive: false)
    view.game.screen = .status
    #expect(view.paintedMissionMenuPresentation == nil)
    let key = try #require(
      NSEvent.keyEvent(
        with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
        windowNumber: 0, context: nil, characters: "\r", charactersIgnoringModifiers: "\r",
        isARepeat: false, keyCode: 36))
    view.keyDown(with: key)
    #expect(view.pending.isEmpty)
    try paintCampaignGalleryView(view)
    let absence = try #require(view.paintedMissionMenuPresentation)
    #expect(absence.page == nil)
    view.game.screen = .gallery
    #expect(view.paintedMissionMenuPresentation == absence)
    #expect(view.paintedMissionMenuPresentation != view.game.scriptPagePresentation)
    view.setFrameSize(.init(width: 1512, height: 982))
    #expect(view.paintedMissionMenuPresentation == nil)
    try paintCampaignGalleryView(view)
    let painted = try #require(view.paintedMissionMenuPresentation)
    var actualBounds = view.game
    actualBounds.viewportWidth = 1512
    actualBounds.viewportHeight = 982
    #expect(painted == actualBounds.scriptPagePresentation)
  }

  @MainActor @Test func nativePageKeyboardUsesPaintedAbsenceAndOnlyTabClearsFlightSteering() throws
  {
    _ = NSApplication.shared
    let view = GameView(frame: .init(x: 0, y: 0, width: 512, height: 518))
    view.game = Game(executive: false)
    view.game.launch()
    try paintCampaignGalleryView(view)
    let painted = try #require(view.paintedMissionMenuPresentation)
    #expect(painted.page == nil)
    for (character, code) in [("r", UInt16(15)), ("\t", UInt16(48))] {
      view.held.insert("up")
      let event = try #require(
        NSEvent.keyEvent(
          with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
          windowNumber: 0, context: nil, characters: character,
          charactersIgnoringModifiers: character, isARepeat: false, keyCode: code))
      view.keyDown(with: event)
      #expect(view.held.contains("up") == (code != 48))
      let packet = try #require(view.pending.last)
      try #require(packet.hasPrefix("script-page-key:"))
      let parts = packet.dropFirst("script-page-key:".count).split(separator: ":", maxSplits: 1)
      try #require(parts.count == 2)
      let bytes = try #require(Data(base64Encoded: String(parts[0])))
      let proof = try JSONDecoder().decode(ScriptPagePresentation.self, from: bytes)
      #expect(proof == painted)
      #expect(String(parts[1]) == (code == 48 ? "tab" : "r"))
    }
  }
}
