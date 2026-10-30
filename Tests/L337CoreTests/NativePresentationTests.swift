import AppKit
import Testing

@testable import L337Core
@testable import L337Mac

@Suite(.serialized)
struct NativePresentationTests {
  @MainActor @Test func directPresentationPreservesFullRenderedFrame() throws {
    var game = Game(executive: false)
    game.launch()
    game.commander.shipDisplayStyle = .shadedPanels
    game.celestials = [
      .init(kind: .planet, position: .init(-900, 0, 6000), radius: 700),
      .init(kind: .sun, position: .init(1500, 400, 7000), radius: 600),
    ]
    let view = GameView(frame: CGRect(x: 0, y: 0, width: 768, height: 768))
    view.game = game
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    func context() throws -> CGContext {
      try #require(
        CGContext(
          data: nil, width: 768, height: 768, bitsPerComponent: 8, bytesPerRow: 768 * 4,
          space: space,
          bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
            | CGBitmapInfo.byteOrder32Little.rawValue))
    }
    // Match the export context before normalizing either image for comparison.
    let drawing = try #require(
      CGContext(
        data: nil, width: 768, height: 768, bitsPerComponent: 8, bytesPerRow: 768 * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    drawing.translateBy(x: 0, y: 768)
    drawing.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: drawing, flipped: true)
    view.draw(view.bounds)
    NSGraphicsContext.restoreGraphicsState()
    let drawnImage = try #require(drawing.makeImage())
    let direct = try context()
    direct.draw(drawnImage, in: view.bounds)
    let image = try #require(imageForGame(game, width: 768, height: 768))
    let reference = try context()
    reference.draw(image, in: view.bounds)
    let directBytes = try #require(direct.data).assumingMemoryBound(to: UInt8.self)
    let referenceBytes = try #require(reference.data).assumingMemoryBound(to: UInt8.self)
    // Both images are normalized into the same canonical opaque BGRA context.
    let count = 768 * 768 * 4
    #expect(
      Array(UnsafeBufferPointer(start: directBytes, count: count))
        == Array(UnsafeBufferPointer(start: referenceBytes, count: count)))
  }

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
    view.keyDown(with: try event("s", 1, down: true))
    #expect(view.controls.pitch == 0)
    view.keyUp(with: try event("x", 7, down: false))
    #expect(view.controls.pitch == -1)
    view.keyUp(with: try event("s", 1, down: false))
    #expect(view.controls.pitch == 0)
    view.keyDown(with: try event("x", 7, down: true))
    #expect(view.controls.pitch == 1)
    view.game.paused = true
    #expect(view.controls.pitch == 0 && view.held.isEmpty)
    view.game.paused = false
    #expect(view.controls.pitch == 0)
  }

}
