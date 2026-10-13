import Foundation

public enum ShipDisplayStyle: String, Codable, Sendable, CaseIterable {
  case whiteWireframe, colourWireframe, shadedPanels

  public var next: Self {
    switch self {
    case .whiteWireframe: .colourWireframe
    case .colourWireframe: .shadedPanels
    case .shadedPanels: .whiteWireframe
    }
  }
  public var label: String {
    switch self {
    case .whiteWireframe: "WHITE WIREFRAME"
    case .colourWireframe: "COLOUR WIREFRAME"
    case .shadedPanels: "SHADED PANELS"
    }
  }
}

public struct ScreenPoint: Sendable, Equatable {
  public let x: Double
  public let y: Double
  public init(_ x: Double, _ y: Double) {
    self.x = x
    self.y = y
  }
}

public struct ShipPanel: Sendable, Equatable {
  public let vertices: [ScreenPoint]
  public let colour: UInt32
}

extension Hull {
  public var ink: Ink {
    switch self {
    case .cobra, .constrictor: .cyan
    case .viper: .blue
    case .sidewinder, .cargo: .yellow
    case .asteroid: .orange
    case .station: .blue
    case .missile: .red
    case .thargoid, .thargon: .green
    }
  }
}

enum ShipProjection {
  static func shade(_ ink: Ink, normal: Vector3) -> UInt32 {
    let light = Vector3(-0.4, 0.6, -1)
    let brightness = 0.25 + 0.75 * max(0, normal.dot(light) / (normal.length * light.length))
    let rgba = ink.rawValue
    let r = UInt32(Double((rgba >> 24) & 255) * brightness)
    let g = UInt32(Double((rgba >> 16) & 255) * brightness)
    let b = UInt32(Double((rgba >> 8) & 255) * brightness)
    return r << 24 | g << 16 | b << 8 | 255
  }

  static func polygon(_ vertices: [Vector3], projection: FlightProjection = .legacy)
    -> [ScreenPoint]
  {
    guard var previous = vertices.last else { return [] }
    var clipped: [Vector3] = []
    for current in vertices {
      if (current.z >= 1) != (previous.z >= 1) {
        clipped.append(
          previous + (current - previous) * ((1 - previous.z) / (current.z - previous.z)))
      }
      if current.z >= 1 { clipped.append(current) }
      previous = current
    }
    let points = clipped.map { projection.point($0) }
    return points.allSatisfy { $0.x.isFinite && $0.y.isFinite } ? points : []
  }
}

extension Frame {
  public mutating func panel(_ vertices: [ScreenPoint], colour: UInt32) {
    guard vertices.count >= 3, vertices.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else {
      return
    }
    var clipped = vertices
    clipped = Self.clipPolygon(clipped, axis: \.x, limit: flightClip.x, above: true)
    clipped = Self.clipPolygon(clipped, axis: \.x, limit: flightClip.maxX - 1, above: false)
    clipped = Self.clipPolygon(clipped, axis: \.y, limit: flightClip.y, above: true)
    clipped = Self.clipPolygon(clipped, axis: \.y, limit: flightClip.maxY - 1, above: false)
    guard clipped.count >= 3 else { return }
    graphics.append(.panel(ShipPanel(vertices: clipped, colour: colour)))
    if rasterizeGraphics { fillPanel(clipped, colour: colour) }
  }

  private static func clipPolygon(
    _ vertices: [ScreenPoint], axis: KeyPath<ScreenPoint, Double>, limit: Double, above: Bool
  ) -> [ScreenPoint] {
    guard var previous = vertices.last else { return [] }
    var result: [ScreenPoint] = []
    for current in vertices {
      let start = previous[keyPath: axis]
      let end = current[keyPath: axis]
      let startInside = above ? start >= limit : start <= limit
      let endInside = above ? end >= limit : end <= limit
      if startInside != endInside {
        let t = (limit - start) / (end - start)
        result.append(
          ScreenPoint(
            previous.x + t * (current.x - previous.x), previous.y + t * (current.y - previous.y)))
      }
      if endInside { result.append(current) }
      previous = current
    }
    return result
  }

  private mutating func fillPanel(_ vertices: [ScreenPoint], colour: UInt32) {
    let low = Int(vertices.map(\.y).min() ?? 12)
    let high = Int(vertices.map(\.y).max() ?? 175)
    for y in low...high {
      let row = Double(y) + 0.5
      var crossings: [Double] = []
      for index in vertices.indices {
        let a = vertices[index]
        let b = vertices[(index + 1) % vertices.count]
        if (a.y <= row && b.y > row) || (b.y <= row && a.y > row) {
          crossings.append(a.x + (row - a.y) * (b.x - a.x) / (b.y - a.y))
        }
      }
      guard let left = crossings.min(), let right = crossings.max() else { continue }
      let first = max(0, Int(ceil(left - 0.5)))
      let last = min(255, Int(floor(right - 0.5)))
      if first <= last { for x in first...last { pixels[y * Self.width + x] = colour } }
    }
  }
}
