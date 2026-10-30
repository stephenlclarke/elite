import Foundation

/// Immutable RGBA8 texels. Source alpha is a material channel, not hull transparency.
public struct ShipTexturePixels: Sendable, Equatable {
  public let width: Int
  public let height: Int
  public let pixels: [UInt32]

  public init?(width: Int, height: Int, pixels: [UInt32]) {
    guard (1...2048).contains(width), (1...2048).contains(height),
      pixels.count == width * height
    else { return nil }
    self.width = width
    self.height = height
    self.pixels = pixels
  }
}

public struct ShipTextureVertex: Sendable, Equatable {
  public let point: ScreenPoint
  public let reciprocalDepth: Double
  public let uOverDepth: Double
  public let vOverDepth: Double

  public init(point: ScreenPoint, reciprocalDepth: Double, uOverDepth: Double, vOverDepth: Double) {
    self.point = point
    self.reciprocalDepth = reciprocalDepth
    self.uOverDepth = uOverDepth
    self.vOverDepth = vOverDepth
  }
}

/// Original surface maps provide relief over an already lit authored palette.
/// Archival textures retain their own RGB and the existing scalar lighting contract.
public enum ShipTextureAppearance: Sendable, Equatable {
  case sourceRGB
  case originalSurface(litMaterial: UInt32)
}

public struct ShipTexturedTriangle: Sendable, Equatable {
  public let vertices: [ShipTextureVertex]
  public let texture: String
  public let brightness: Double
  public let appearance: ShipTextureAppearance
  public let clip: CanvasRect

  public init(
    vertices: [ShipTextureVertex], texture: String, brightness: Double, clip: CanvasRect,
    appearance: ShipTextureAppearance = .sourceRGB
  ) {
    self.vertices = vertices
    self.texture = texture
    self.brightness = brightness
    self.appearance = appearance
    self.clip = clip
  }
}

public struct ShipTextureTile: Sendable, Equatable {
  public let origin: ScreenPoint
  public let width: Int
  public let height: Int
  public let scale: Double
  public let rgba: [UInt32]
}

public enum ShipTextureProjection {
  private struct Corner {
    let point: Vector3
    let u: Double
    let v: Double

    func interpolated(to other: Self, fraction: Double) -> Self {
      .init(
        point: point + (other.point - point) * fraction,
        u: u + (other.u - u) * fraction, v: v + (other.v - v) * fraction)
    }
  }

  /// Clip in camera space, before dividing position and UV by depth.
  public static func triangles(
    vertices: [Vector3], uv: [[Double]], projection: FlightProjection,
    texture: String, brightness: Double, clip: CanvasRect,
    appearance: ShipTextureAppearance = .sourceRGB
  ) -> [ShipTexturedTriangle] {
    guard (3...64).contains(vertices.count), uv.count == vertices.count,
      vertices.allSatisfy({ valid($0.x) && valid($0.y) && valid($0.z) }),
      uv.allSatisfy({ $0.count == 2 && valid($0[0]) && valid($0[1]) }),
      valid(projection.center.x), valid(projection.center.y), valid(projection.focal),
      projection.focal > 0, ShipTextureRaster.validClip(clip),
      brightness.isFinite, (0...1).contains(brightness), !texture.isEmpty
    else { return [] }
    let corners = zip(vertices, uv).map { Corner(point: $0.0, u: $0.1[0], v: $0.1[1]) }
    var previous = corners[corners.count - 1]
    var clipped: [Corner] = []
    for current in corners {
      if (current.point.z >= 1) != (previous.point.z >= 1) {
        let fraction = (1 - previous.point.z) / (current.point.z - previous.point.z)
        let crossing = previous.interpolated(to: current, fraction: fraction)
        // Set the clipped depth exactly, avoiding roundoff across the near plane.
        clipped.append(
          .init(point: .init(crossing.point.x, crossing.point.y, 1), u: crossing.u, v: crossing.v))
      }
      if current.point.z >= 1 { clipped.append(current) }
      previous = current
    }
    guard clipped.count >= 3 else { return [] }
    let projected = clipped.map {
      ShipTextureVertex(
        point: projection.point($0.point), reciprocalDepth: 1 / $0.point.z,
        uOverDepth: $0.u / $0.point.z, vOverDepth: $0.v / $0.point.z)
    }
    guard projected.allSatisfy(ShipTextureRaster.validVertex) else { return [] }
    return (1..<(projected.count - 1)).map {
      .init(
        vertices: [projected[0], projected[$0], projected[$0 + 1]],
        texture: texture, brightness: brightness, clip: clip, appearance: appearance)
    }
  }

  private static func valid(_ value: Double) -> Bool {
    value.isFinite && abs(value) <= 1_000_000_000
  }
}

public enum ShipTextureRaster {
  static func validClip(_ clip: CanvasRect) -> Bool {
    [clip.x, clip.y, clip.width, clip.height, clip.maxX, clip.maxY].allSatisfy {
      $0.isFinite && abs($0) <= 1_000_000_000
    } && clip.width > 0 && clip.height > 0 && clip.width <= 8192 && clip.height <= 8192
  }

  static func validVertex(_ vertex: ShipTextureVertex) -> Bool {
    [vertex.point.x, vertex.point.y, vertex.uOverDepth, vertex.vOverDepth].allSatisfy {
      $0.isFinite && abs($0) <= 1_000_000_000_000
    } && vertex.reciprocalDepth.isFinite && vertex.reciprocalDepth > 0
      && vertex.reciprocalDepth <= 1
  }

  /// A bounded transparent tile, shared by native display and exported frames.
  public static func tile(
    triangle: ShipTexturedTriangle, pixels: ShipTexturePixels, scale: Double = 1
  ) -> ShipTextureTile? {
    guard triangle.vertices.count == 3, triangle.vertices.allSatisfy(validVertex),
      validClip(triangle.clip), scale.isFinite, scale >= 1 / 8192, scale <= 4,
      triangle.brightness.isFinite, (0...1).contains(triangle.brightness)
    else { return nil }
    if case .originalSurface(let colour) = triangle.appearance {
      guard colour & 255 == 255,
        OriginalShipTextureAssets.allowedIDs.contains(triangle.texture)
      else { return nil }
    }
    let points = triangle.vertices.map(\.point)
    let left = max(points.map(\.x).min()!, triangle.clip.x)
    let top = max(points.map(\.y).min()!, triangle.clip.y)
    let right = min(points.map(\.x).max()!, triangle.clip.maxX)
    let bottom = min(points.map(\.y).max()!, triangle.clip.maxY)
    guard left < right, top < bottom else { return nil }
    // Keep large Retina faces textured by reducing sampling resolution within the budget.
    // Two pixels of rounding allowance bound floor/ceil at either end of each axis.
    let spanX = right - left
    let spanY = bottom - top
    let effectiveScale = min(
      scale, 4094 / spanX, 4094 / spanY, sqrt(4_186_116 / (spanX * spanY)))
    let x0 = floor(left * effectiveScale)
    let y0 = floor(top * effectiveScale)
    let widthValue = ceil(right * effectiveScale) - x0
    let heightValue = ceil(bottom * effectiveScale) - y0
    guard widthValue >= 1, heightValue >= 1, widthValue <= 4096, heightValue <= 4096,
      widthValue * heightValue <= 4_194_304
    else { return nil }
    let width = Int(widthValue)
    let height = Int(heightValue)
    let area = edge(points[0], points[1], points[2])
    guard area.isFinite, abs(area) > 1e-12 else { return nil }
    var rgba = [UInt32](repeating: 0, count: width * height)
    for y in 0..<height {
      for x in 0..<width {
        let point = ScreenPoint(
          (x0 + Double(x) + 0.5) / effectiveScale, (y0 + Double(y) + 0.5) / effectiveScale)
        guard triangle.clip.contains(point) else { continue }
        let a = edge(points[1], points[2], point) / area
        let b = edge(points[2], points[0], point) / area
        let c = 1 - a - b
        guard a >= 0, b >= 0, c >= 0 else { continue }
        let vertices = triangle.vertices
        let depth =
          a * vertices[0].reciprocalDepth + b * vertices[1].reciprocalDepth
          + c * vertices[2].reciprocalDepth
        let u =
          (a * vertices[0].uOverDepth + b * vertices[1].uOverDepth
            + c * vertices[2].uOverDepth) / depth
        let v =
          (a * vertices[0].vOverDepth + b * vertices[1].vOverDepth
            + c * vertices[2].vOverDepth) / depth
        guard u.isFinite, v.isFinite else { continue }
        rgba[y * width + x] = sample(
          pixels, u: u, v: v, brightness: triangle.brightness, appearance: triangle.appearance)
      }
    }
    let origin = ScreenPoint(x0 / effectiveScale, y0 / effectiveScale)
    guard origin.x.isFinite, origin.y.isFinite else { return nil }
    return .init(
      origin: origin, width: width, height: height,
      scale: effectiveScale, rgba: rgba)
  }

  private static func edge(_ a: ScreenPoint, _ b: ScreenPoint, _ point: ScreenPoint) -> Double {
    (b.x - a.x) * (point.y - a.y) - (b.y - a.y) * (point.x - a.x)
  }

  /// Normalized repeat UVs, with v=0 at the top PNG row and texel-center filtering.
  private static func sample(
    _ pixels: ShipTexturePixels, u: Double, v: Double, brightness: Double,
    appearance: ShipTextureAppearance
  ) -> UInt32 {
    let wrappedU = u - floor(u)
    let wrappedV = v - floor(v)
    let x = wrappedU * Double(pixels.width) - 0.5
    let y = wrappedV * Double(pixels.height) - 0.5
    let ix = Int(floor(x))
    let iy = Int(floor(y))
    let fx = x - floor(x)
    let fy = y - floor(y)
    func texel(_ x: Int, _ y: Int) -> UInt32 {
      let column = (x % pixels.width + pixels.width) % pixels.width
      let row = (y % pixels.height + pixels.height) % pixels.height
      return pixels.pixels[row * pixels.width + column]
    }
    let topLeft = texel(ix, iy)
    let topRight = texel(ix + 1, iy)
    let bottomLeft = texel(ix, iy + 1)
    let bottomRight = texel(ix + 1, iy + 1)
    func channel(_ shift: Int) -> Double {
      let top =
        Double((topLeft >> shift) & 255) * (1 - fx)
        + Double((topRight >> shift) & 255) * fx
      let bottom =
        Double((bottomLeft >> shift) & 255) * (1 - fx)
        + Double((bottomRight >> shift) & 255) * fx
      return top * (1 - fy) + bottom * fy
    }
    func opaqueChannel(_ value: Double) -> UInt32 {
      UInt32(min(255, max(0, value.rounded())))
    }
    switch appearance {
    case .sourceRGB:
      return opaqueChannel(channel(24) * brightness) << 24
        | opaqueChannel(channel(16) * brightness) << 16
        | opaqueChannel(channel(8) * brightness) << 8 | 255
    case .originalSurface(let litMaterial):
      // Match the original authoring renderer's neutral surface-relief convention.
      // Lighting (including emissivity) is already in litMaterial; do not apply it twice.
      let luminance = (channel(24) + channel(16) + channel(8)) / 3
      let relief = min(1.10, max(0.27, luminance / 86))
      return opaqueChannel(Double((litMaterial >> 24) & 255) * relief) << 24
        | opaqueChannel(Double((litMaterial >> 16) & 255) * relief) << 16
        | opaqueChannel(Double((litMaterial >> 8) & 255) * relief) << 8 | 255
    }
  }
}
