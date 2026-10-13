import AppKit
import EliteCore
import ImageIO
import UniformTypeIdentifiers

@MainActor
func exportShipMedia(ids: [String], directory: URL) throws {
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  for id in ids {
    guard let ship = ShipCatalogue.ship(id) else { throw ShipFileError.invalid(id) }
    let path = directory.appendingPathComponent(id + ".gif")
    guard
      let gif = CGImageDestinationCreateWithURL(
        path as CFURL, UTType.gif.identifier as CFString, 24, nil)
    else { throw ShipFileError.invalid(id) }
    CGImageDestinationSetProperties(
      gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    for index in 0..<24 {
      let frame = Display.shipPortrait(ship, angle: Double(index) * 2 * .pi / 24)
      guard !frame.shipPanels.isEmpty, let image = imageFor(frame, pixelSize: 256) else {
        throw ShipFileError.invalid(id)
      }
      CGImageDestinationAddImage(
        gif, image,
        [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.10]] as CFDictionary)
    }
    guard CGImageDestinationFinalize(gif) else { throw ShipFileError.invalid(id) }
  }
}

@MainActor
func exportShipOverview(directory: URL) throws {
  let ships = ShipCatalogue.all
  let columns = 10
  let rows = (ships.count + columns - 1) / columns
  guard
    let context = CGContext(
      data: nil, width: columns * 256, height: rows * 256, bitsPerComponent: 8,
      bytesPerRow: columns * 256 * 4, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
  else { throw SaveError.invalidCommander }
  context.setFillColor(CGColor(gray: 0, alpha: 1))
  context.fill(CGRect(x: 0, y: 0, width: columns * 256, height: rows * 256))
  for (index, ship) in ships.enumerated() {
    guard let image = imageFor(Display.shipPortrait(ship, angle: 0.65), pixelSize: 256) else {
      throw ShipFileError.invalid(ship.id)
    }
    context.draw(
      image,
      in: CGRect(
        x: (index % columns) * 256, y: (rows - 1 - index / columns) * 256, width: 256, height: 256))
  }
  let path = directory.appendingPathComponent("overview.png")
  guard let image = context.makeImage(),
    let output = CGImageDestinationCreateWithURL(
      path as CFURL, UTType.png.identifier as CFString, 1, nil)
  else { throw SaveError.invalidCommander }
  CGImageDestinationAddImage(output, image, nil)
  guard CGImageDestinationFinalize(output) else { throw SaveError.invalidCommander }
}
