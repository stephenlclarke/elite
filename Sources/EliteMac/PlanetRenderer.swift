import AppKit
import EliteCore

/// Presentation-only bounded caches; terrain and rotation never consume game RNG.
@MainActor
enum PlanetRenderer {
  private struct ImageKey: Equatable {
    let identity: PlanetIdentity
    let diameter: Int
    let phase: Int
  }
  private static var terrains: [(PlanetIdentity, PlanetTerrain)] = []
  private static var lastKey: ImageKey?
  private static var lastImage: CGImage?

  static func draw(_ preview: PlanetPreview, context: CGContext) {
    let scale = hypot(context.ctm.a, context.ctm.c)
    let diameter = max(32, min(768, Int(ceil(preview.bounds.width * scale))))
    guard let image = image(for: preview, diameter: diameter) else { return }
    context.saveGState()
    context.interpolationQuality = .high
    context.translateBy(x: preview.bounds.x, y: preview.bounds.maxY)
    context.scaleBy(x: 1, y: -1)
    context.draw(
      image, in: CGRect(x: 0, y: 0, width: preview.bounds.width, height: preview.bounds.height))
    context.restoreGState()
  }

  static func image(for preview: PlanetPreview, diameter: Int) -> CGImage? {
    guard (32...768).contains(diameter) else { return nil }
    let phase = Int(preview.angle.truncatingRemainder(dividingBy: 2 * .pi) / 0.006)
    let key = ImageKey(identity: preview.identity, diameter: diameter, phase: phase)
    if lastKey == key { return lastImage }
    let terrain: PlanetTerrain
    if let cached = terrains.first(where: { $0.0 == preview.identity }) {
      terrain = cached.1
    } else {
      terrain = PlanetTerrain(identity: preview.identity)
      terrains.append((preview.identity, terrain))
      if terrains.count > 8 { terrains.removeFirst() }
    }
    let palette = PlanetPalette(identity: preview.identity)
    let angle = Double(phase) * 0.006
    var bytes = [UInt8](repeating: 0, count: diameter * diameter * 4)
    for y in 0..<diameter {
      for x in 0..<diameter {
        let nx = (Double(x) + 0.5 - Double(diameter) / 2) / (Double(diameter) * 0.47)
        let ny = (Double(diameter) / 2 - Double(y) - 0.5) / (Double(diameter) * 0.47)
        let radius = nx * nx + ny * ny
        let colour = pixel(
          nx: nx, ny: ny, radius: radius, angle: angle, terrain: terrain, palette: palette)
        let offset = (y * diameter + x) * 4
        bytes[offset] = byte(colour.x)
        bytes[offset + 1] = byte(colour.y)
        bytes[offset + 2] = byte(colour.z)
        // Preserve the premultiplied atmospheric rim while keeping space transparent.
        let haze = max(0, 1 - (sqrt(radius) - 1) / 0.035)
        bytes[offset + 3] = radius < 1 ? 255 : byte(haze * haze * 0.25)
      }
    }
    let data = Data(bytes) as CFData
    guard let provider = CGDataProvider(data: data) else { return nil }
    let result = CGImage(
      width: diameter, height: diameter, bitsPerComponent: 8,
      bitsPerPixel: 32, bytesPerRow: diameter * 4, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
      provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    lastKey = key
    lastImage = result
    return result
  }

  private static func byte(_ value: Double) -> UInt8 {
    UInt8(max(0, min(255, value * 255)))
  }

  private static func pixel(
    nx: Double, ny: Double, radius: Double, angle: Double,
    terrain: PlanetTerrain, palette: PlanetPalette
  ) -> Vector3 {
    guard radius < 1 else {
      let haze = max(0, 1 - (sqrt(radius) - 1) / 0.035)
      return Vector3(0.12, 0.35, 0.66) * (haze * haze * 0.25)
    }
    let nz = sqrt(1 - radius)
    let latitude = asin(ny)
    let longitude = atan2(nx, nz) + angle
    let height = terrain.sample(terrain.elevation, longitude: longitude, latitude: latitude)
    let cloud = terrain.sample(
      terrain.clouds, longitude: longitude + angle * 0.08, latitude: latitude)
    let coast = smooth(palette.seaLevel - 0.018, palette.seaLevel + 0.018, height)
    let highland = smooth(palette.seaLevel + 0.04, 0.8, height)
    let land = blend(palette.land, Vector3(0.56, 0.46, 0.30), highland * 0.65)
    var surface = blend(palette.ocean, land, coast)
    let ice = smooth(palette.ice - 0.06, palette.ice + 0.02, abs(ny))
    surface = blend(surface, Vector3(0.81, 0.89, 0.93), ice)
    let cloudOpacity = smooth(0.50, 0.67, cloud) * 0.80
    surface = blend(surface, Vector3(0.92, 0.95, 1), cloudOpacity)
    let sunlight = -nx * 0.52 + ny * 0.35 + nz * 0.78
    let illumination = 0.035 + 0.965 * smooth(-0.10, 0.80, sunlight)
    let atmosphere = pow(1 - nz, 3) * smooth(-0.12, 0.50, sunlight) * 0.40
    return surface * illumination + Vector3(0.20, 0.49, 0.85) * atmosphere
  }

  private static func smooth(_ low: Double, _ high: Double, _ value: Double) -> Double {
    let t = max(0, min(1, (value - low) / (high - low)))
    return t * t * (3 - 2 * t)
  }
  private static func blend(_ a: Vector3, _ b: Vector3, _ t: Double) -> Vector3 { a + (b - a) * t }
}
