import AppKit
import ImageIO
import L337Core
import UniformTypeIdentifiers

@MainActor
func exportAppIcon(at root: URL = URL(fileURLWithPath: ".")) throws {
  let files = FileManager.default
  let images = root.appendingPathComponent("docs/images")
  let iconset = root.appendingPathComponent(".build/L337.iconset")
  try files.createDirectory(at: images, withIntermediateDirectories: true)
  try files.createDirectory(at: iconset, withIntermediateDirectories: true)
  let frame = Display.appIcon()
  try writeIconPNG(frame, size: 1024, path: images.appendingPathComponent("l337-icon.png").path)
  for size in [16, 32, 128, 256, 512] {
    try writeIconPNG(
      frame, size: size, path: iconset.appendingPathComponent("icon_\(size)x\(size).png").path)
    try writeIconPNG(
      frame, size: size * 2,
      path: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png").path)
  }
}

@MainActor
private func writeIconPNG(_ frame: Frame, size: Int, path: String) throws {
  guard let image = imageFor(frame, pixelSize: size),
    let destination = CGImageDestinationCreateWithURL(
      URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)
  else { throw SaveError.invalidCommander }
  CGImageDestinationAddImage(destination, image, nil)
  guard CGImageDestinationFinalize(destination) else { throw SaveError.invalidCommander }
}
