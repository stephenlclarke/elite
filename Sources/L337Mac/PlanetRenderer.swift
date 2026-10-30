import AppKit
import L337Core

/// Presentation-only bounded caches; terrain and rotation never consume game RNG.
@MainActor
enum PlanetRenderer {
  private struct ImageKey: Equatable {
    let identity: PlanetIdentity
    let appearance: PlanetPalette
    let lighting: PlanetLighting
    let night: PlanetNightProfile
    let diameter: Int
    let phase: Int
  }
  // CPU fallback and accelerated frames share one explicit colour interpretation.
  private static let colourSpace =
    CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
  private static var terrains: [(PlanetIdentity, PlanetTerrain)] = []
  private static var settlements: [(PlanetSettlementKey, PlanetSettlementMask)] = []
  private static var referenceKey: ImageKey?
  private static var referenceImageCache: CGImage?
  private static var imageKey: ImageKey?
  private static var imageCache: CGImage?
  private static var gpuPreparation: Task<Void, Never>?
  private static var gpuShader: PlanetGPUShader?
  static var backendDescription: String { gpuShader?.deviceName ?? "CPU fallback" }

  private static func startGPUPreparation() {
    guard gpuPreparation == nil else { return }
    gpuPreparation = Task {
      if let pipeline = await PlanetGPUShader.compile() {
        gpuShader = PlanetGPUShader(pipeline: pipeline)
        // A CPU fallback cached during preparation must not hide the ready GPU.
        imageKey = nil
        imageCache = nil
      }
    }
  }

  /// Await the same one-time preparation used by ordinary drawing.
  static func prepareGPU() async -> String? {
    startGPUPreparation()
    await gpuPreparation?.value
    return gpuShader?.deviceName
  }

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
    guard (32...768).contains(diameter), preview.angle.isFinite else { return nil }
    startGPUPreparation()
    let phase = Int(preview.angle.truncatingRemainder(dividingBy: 2 * .pi) / 0.006)
    let key = ImageKey(
      identity: preview.identity, appearance: preview.appearance, lighting: preview.lighting,
      night: preview.night, diameter: diameter, phase: phase)
    if imageKey == key { return imageCache }
    var accelerated: CGImage?
    if let shader = gpuShader {
      let terrain = cachedTerrain(for: preview.identity)
      accelerated = shader.image(
        identity: preview.identity, terrain: terrain, palette: preview.appearance,
        angle: Double(phase) * 0.006, diameter: diameter, lighting: preview.lighting,
        night: preview.night, settlements: cachedSettlements(for: preview, terrain: terrain))
      // Persistent command/device failures must not stall every subsequent frame.
      if accelerated == nil { gpuShader = nil }
    }
    guard let result = accelerated ?? referenceImage(for: preview, diameter: diameter) else {
      return nil
    }
    imageKey = key
    imageCache = result
    return result
  }

  private static func cachedTerrain(for identity: PlanetIdentity) -> PlanetTerrain {
    if let cached = terrains.first(where: { $0.0 == identity }) { return cached.1 }
    let terrain = PlanetTerrain(identity: identity)
    terrains.append((identity, terrain))
    if terrains.count > 8 { terrains.removeFirst() }
    return terrain
  }

  private static func cachedSettlements(for preview: PlanetPreview, terrain: PlanetTerrain)
    -> PlanetSettlementMask
  {
    let key = PlanetSettlementKey(
      identity: preview.identity, palette: preview.appearance, night: preview.night)
    if let cached = settlements.first(where: { $0.0 == key }) { return cached.1 }
    let mask = PlanetSettlementMask(key: key, terrain: terrain)
    settlements.append((key, mask))
    if settlements.count > 8 { settlements.removeFirst() }
    return mask
  }

  /// Deterministic CPU fallback and visual reference for the accelerated renderer.
  static func referenceImage(for preview: PlanetPreview, diameter: Int) -> CGImage? {
    guard (32...768).contains(diameter), preview.angle.isFinite else { return nil }
    let phase = Int(preview.angle.truncatingRemainder(dividingBy: 2 * .pi) / 0.006)
    let key = ImageKey(
      identity: preview.identity, appearance: preview.appearance, lighting: preview.lighting,
      night: preview.night, diameter: diameter, phase: phase)
    if referenceKey == key { return referenceImageCache }
    let terrain = cachedTerrain(for: preview.identity)
    let palette = preview.appearance
    let mask = cachedSettlements(for: preview, terrain: terrain)
    let angle = Double(phase) * 0.006
    var bytes = [UInt8](repeating: 0, count: diameter * diameter * 4)
    for y in 0..<diameter {
      for x in 0..<diameter {
        let nx = (Double(x) + 0.5 - Double(diameter) / 2) / (Double(diameter) * 0.47)
        let ny = (Double(diameter) / 2 - Double(y) - 0.5) / (Double(diameter) * 0.47)
        let radius = nx * nx + ny * ny
        let colour = pixel(
          nx: nx, ny: ny, radius: radius, angle: angle, terrain: terrain, palette: palette,
          lighting: preview.lighting, night: preview.night, settlements: mask)
        let offset = (y * diameter + x) * 4
        bytes[offset] = byte(colour.x)
        bytes[offset + 1] = byte(colour.y)
        bytes[offset + 2] = byte(colour.z)
        // Preserve the premultiplied atmospheric rim while keeping space transparent.
        let haze = max(0, 1 - (sqrt(radius) - 1) / palette.profile.rimWidth)
        bytes[offset + 3] = radius < 1 ? 255 : byte(haze * haze * palette.profile.rimOpacity)
      }
    }
    let data = Data(bytes) as CFData
    guard let provider = CGDataProvider(data: data) else { return nil }
    let result = CGImage(
      width: diameter, height: diameter, bitsPerComponent: 8,
      bitsPerPixel: 32, bytesPerRow: diameter * 4, space: colourSpace,
      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
      provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    referenceKey = key
    referenceImageCache = result
    return result
  }

  private static func byte(_ value: Double) -> UInt8 {
    UInt8(max(0, min(255, value * 255)))
  }

  private static func pixel(
    nx: Double, ny: Double, radius: Double, angle: Double,
    terrain: PlanetTerrain, palette: PlanetPalette, lighting: PlanetLighting,
    night: PlanetNightProfile, settlements: PlanetSettlementMask
  ) -> Vector3 {
    guard radius < 1 else {
      let haze = max(0, 1 - (sqrt(radius) - 1) / palette.profile.rimWidth)
      let sunlight = nx * lighting.direction.x + ny * lighting.direction.y
      let rimLight = 0.04 + 0.96 * smooth(-0.12, 0.30, sunlight) * lighting.strength
      return palette.profile.atmosphereColour
        * (haze * haze * palette.profile.rimOpacity * rimLight)
    }
    let nz = sqrt(1 - radius)
    let latitude = asin(ny)
    let longitude = atan2(nx, nz) + angle
    let height = terrain.sample(terrain.elevation, longitude: longitude, latitude: latitude)
    let cloud = terrain.sample(
      terrain.clouds, longitude: longitude + angle * 0.08, latitude: latitude)
    let coast = smooth(palette.seaLevel - 0.018, palette.seaLevel + 0.018, height)
    let highland = smooth(palette.seaLevel + 0.04, 0.8, height)
    var land = blend(
      palette.land, palette.profile.highland, highland * palette.profile.highlandStrength)
    let vegetation =
      smooth(palette.seaLevel + 0.015, palette.seaLevel + 0.13, height)
      * (1 - highland) * palette.profile.vegetationStrength
    land = blend(land, palette.profile.vegetation, vegetation)
    var surface = blend(palette.ocean, land, coast)
    let ice = smooth(palette.ice - 0.06, palette.ice + 0.02, abs(ny))
    surface = blend(surface, Vector3(0.81, 0.89, 0.93), ice)
    let cloudOpacity =
      smooth(palette.profile.cloudLow, palette.profile.cloudHigh, cloud)
      * palette.profile.cloudOpacity
    surface = blend(surface, palette.profile.cloudColour, cloudOpacity)
    surface = blend(surface, palette.profile.atmosphereColour, palette.profile.surfaceHaze)
    let sunlight = nx * lighting.direction.x + ny * lighting.direction.y + nz * lighting.direction.z
    let illumination = 0.006 + 0.994 * smooth(-0.08, 0.80, sunlight) * lighting.strength
    let atmosphere =
      pow(1 - nz, 3) * smooth(-0.12, 0.50, sunlight)
      * palette.profile.atmosphereStrength * lighting.strength
    let dark = 1 - smooth(-0.12, 0.08, sunlight) * lighting.strength
    var emission = Vector3(0, 0, 0)
    if dark > 0, night.emissionIntensity > 0 {
      let cities = terrain.sample(settlements.emission, longitude: longitude, latitude: latitude)
      let localScatter = terrain.sample(
        settlements.scatter, longitude: longitude, latitude: latitude)
      emission = night.emission(
        cities: cities, scatter: localScatter, cloudOpacity: cloudOpacity, darkness: dark)
    }
    return surface * illumination + palette.profile.atmosphereColour * atmosphere + emission
  }

  private static func smooth(_ low: Double, _ high: Double, _ value: Double) -> Double {
    let t = max(0, min(1, (value - low) / (high - low)))
    return t * t * (3 - 2 * t)
  }
  private static func blend(_ a: Vector3, _ b: Vector3, _ t: Double) -> Vector3 { a + (b - a) * t }
}
