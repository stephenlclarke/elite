import AppKit
import CryptoKit
import ImageIO
import Testing

@testable import EliteCore
@testable import EliteMac

@Suite(.serialized)
struct NativeTexturedShipExportTests {
  @MainActor @Test(arguments: ["SH169", "SH170"])
  func actualTexturedShipGIFContainsAllRenderedFrames(id: String) throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let ship = try #require(ShipCatalogue.ship(id))
    for index in 0..<24 {
      let frame = Display.shipPortrait(ship, angle: Double(index) * 2 * .pi / 24)
      #expect(frame.hasShipSurfaces)
      #expect(frame.shipPanels.isEmpty)
      #expect(frame.graphics.contains { if case .textured = $0 { true } else { false } })
    }
    try exportShipMedia(ids: [id], directory: root)
    let source = try #require(
      CGImageSourceCreateWithURL(root.appendingPathComponent(id + ".gif") as CFURL, nil))
    #expect(CGImageSourceGetCount(source) == 24)
    var frames: Set<Data> = []
    for index in 0..<24 {
      let image = try #require(CGImageSourceCreateImageAtIndex(source, index, nil))
      #expect(image.width == 256 && image.height == 256)
      let pixels = try #require(image.dataProvider?.data) as Data
      #expect(Set(pixels).count > 8)
      frames.insert(Data(SHA256.hash(data: pixels)))
    }
    #expect(frames.count > 1)
  }
}
