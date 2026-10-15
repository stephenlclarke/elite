import AppKit
import Testing

@testable import EliteCore
@testable import EliteMac

@Suite(.serialized)
struct FlightInputCadenceTests {
  @MainActor @Test func heldPitchIgnoresRepeatAndReleasesImmediately() throws {
    let view = GameView()
    view.game.launch()
    func event(_ key: String, _ code: UInt16, down: Bool, repeated: Bool = false) throws -> NSEvent
    {
      try #require(
        NSEvent.keyEvent(
          with: down ? .keyDown : .keyUp,
          location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
          context: nil, characters: key, charactersIgnoringModifiers: key,
          isARepeat: repeated, keyCode: code))
    }
    view.keyDown(with: try event("s", 1, down: true))
    #expect(view.controls.pitch == -1)
    let pending = view.pending
    for _ in 0..<20 { view.keyDown(with: try event("s", 1, down: true, repeated: true)) }
    #expect(view.pending == pending && view.controls.pitch == -1)
    view.keyUp(with: try event("s", 1, down: false))
    #expect(view.controls.pitch == 0)
    view.keyDown(with: try event("x", 7, down: true))
    #expect(view.controls.pitch == 1)
    view.game.paused = true
    #expect(view.controls.pitch == 0 && view.held.isEmpty)
    view.game.paused = false
    #expect(view.controls.pitch == 0)
  }

  @MainActor @Test func presentationBitmapHasExplicitColourSpaceAndNativeLayout() throws {
    let image = try #require(
      imageForGame(Game(executive: false), width: 768, height: 768, scale: 2))
    #expect(image.width == 1536 && image.height == 1536)
    #expect(image.colorSpace?.name == CGColorSpace.sRGB)
    #expect(image.alphaInfo == .noneSkipFirst)
    #expect(image.bitmapInfo.contains(.byteOrder32Little))
    #expect(GameView().isOpaque)
  }

  @MainActor @Test func opaqueFramebufferPreservesRenderedColours() throws {
    var game = Game(executive: false)
    game.launch()
    game.commander.shipDisplayStyle = .shadedPanels
    let image = try #require(imageForGame(game, width: 768, height: 768))
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    func context() throws -> CGContext {
      try #require(
        CGContext(
          data: nil, width: 768, height: 768, bitsPerComponent: 8, bytesPerRow: 768 * 4,
          space: space,
          bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
            | CGBitmapInfo.byteOrder32Little.rawValue))
    }
    let reference = try context()
    reference.setFillColor(CGColor(gray: 0, alpha: 1))
    reference.fill(CGRect(x: 0, y: 0, width: 768, height: 768))
    reference.translateBy(x: 0, y: 768)
    reference.scaleBy(x: 1, y: -1)
    drawGame(game, context: reference, rect: CGRect(x: 0, y: 0, width: 768, height: 768))
    let actual = try context()
    actual.draw(image, in: CGRect(x: 0, y: 0, width: 768, height: 768))
    let referenceBytes = try #require(reference.data).assumingMemoryBound(to: UInt8.self)
    let actualBytes = try #require(actual.data).assumingMemoryBound(to: UInt8.self)
    let count = 768 * 768 * 4
    #expect(
      Array(UnsafeBufferPointer(start: referenceBytes, count: count))
        == Array(UnsafeBufferPointer(start: actualBytes, count: count)))
  }
}
