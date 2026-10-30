import Foundation
import ImageIO
import Testing

@testable import L337Core
@testable import L337Mac

@Test func appIconUsesApprovedLarvaalSovereignWithLegibleShadedPanels() {
  let icon = Display.appIcon()
  #expect(!icon.rasterizeGraphics)
  #expect(icon.shipPanels.count > 200 && icon.shipLines.isEmpty)
  #expect(icon.shipPanels.flatMap(\.vertices).allSatisfy { icon.canvas.contains($0) })
  #expect(icon.graphics == Display.appIcon().graphics)
  #expect(L337Branding.shipID == "SH123")
  #expect(L337Branding.iconMesh.faces.count == 99648)
  #expect(L337Branding.iconMesh.materials.contains { $0.colour == 0x5D95_72FF })
  #expect(L337Branding.iconMesh.materials.contains { $0.emissive && $0.colour == 0xFFD5_5BFF })
}

@MainActor @Test func appIconExportContainsEveryStandardAndRetinaRepresentation() throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  try exportAppIcon(at: root)
  let iconset = root.appendingPathComponent(".build/L337.iconset")
  #expect(try FileManager.default.contentsOfDirectory(atPath: iconset.path).count == 10)
  for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
      let suffix = scale == 1 ? "" : "@2x"
      let url = iconset.appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
      let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
      let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
      #expect(image.width == size * scale && image.height == size * scale)
    }
  }
  let preview = root.appendingPathComponent("docs/images/l337-icon.png")
  let source = try #require(CGImageSourceCreateWithURL(preview as CFURL, nil))
  #expect(CGImageSourceCreateImageAtIndex(source, 0, nil)?.width == 1024)
}
