import AppKit
import Darwin
import Foundation
import Testing

@testable import EliteCore
@testable import EliteMac

private enum PlanetContextVariant: String, CaseIterable, Codable {
  case deviceRGBA = "DeviceRGB-RGBA-original"
  case deviceBGRA = "DeviceRGB-BGRA"
  case srgbRGBA = "sRGB-RGBA"
  case srgbBGRA = "sRGB-BGRA-current"

  var colourSpace: CGColorSpace {
    switch self {
    case .deviceRGBA, .deviceBGRA: CGColorSpaceCreateDeviceRGB()
    case .srgbRGBA, .srgbBGRA: CGColorSpace(name: CGColorSpace.sRGB)!
    }
  }
  var bitmapInfo: UInt32 {
    switch self {
    case .deviceRGBA, .srgbRGBA: CGImageAlphaInfo.premultipliedLast.rawValue
    case .deviceBGRA, .srgbBGRA:
      CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
    }
  }
}

private struct PlanetContextSample: Codable {
  let variant: PlanetContextVariant
  let visible: Bool
  let trial: Int
  let wallMS: Double
  let cpuMS: Double
}

private struct PlanetContextSummary: Codable {
  let variant: PlanetContextVariant
  let visible: Bool
  let wallP50: Double
  let wallP95: Double
  let cpuP50: Double
  let cpuP95: Double
}

private struct PlanetContextMetadata: Codable {
  let variant: PlanetContextVariant
  let imageColourSpace: String
  let bitmapInfo: UInt32
  let bytesPerRow: Int
}

private struct PlanetContextReport: Codable {
  let device: String
  let gpuImageColourSpace: String
  let drawingColourSpace: String
  let width: Int
  let height: Int
  let scale: Int
  let warmupRounds: Int
  let metadata: [PlanetContextMetadata]
  let samples: [PlanetContextSample]
  let summaries: [PlanetContextSummary]
  let notes: [String]
}

private func contextExperimentCPU() -> Double {
  var usage = rusage()
  getrusage(RUSAGE_SELF, &usage)
  return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
    + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
}

/// Mirrors imageForGame, changing only the requested context space and byte layout.
@MainActor
private func contextExperimentImage(_ game: Game, variant: PlanetContextVariant) -> CGImage? {
  let width = 1512
  let height = 982
  let scale = 2
  guard
    let context = CGContext(
      data: nil, width: width * scale, height: height * scale, bitsPerComponent: 8,
      bytesPerRow: width * scale * 4, space: variant.colourSpace, bitmapInfo: variant.bitmapInfo)
  else { return nil }
  context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
  context.fill(CGRect(x: 0, y: 0, width: width * scale, height: height * scale))
  context.translateBy(x: 0, y: Double(height * scale))
  context.scaleBy(x: Double(scale), y: Double(-scale))
  drawGame(game, context: context, rect: CGRect(x: 0, y: 0, width: width, height: height))
  return context.makeImage()
}

private func contextPercentile(_ values: [Double], fraction: Double) -> Double {
  let sorted = values.sorted()
  return sorted[min(sorted.count - 1, max(0, Int(ceil(Double(sorted.count) * fraction)) - 1))]
}

@MainActor @Test func measurePlanetContextVariants() async throws {
  guard ProcessInfo.processInfo.environment["ELITE_PLANET_CONTEXT_EXPERIMENT"] == "1" else {
    return
  }
  let device = try #require(await PlanetRenderer.prepareGPU())
  var visible = Game(executive: false)
  visible.launch()
  visible.commander.shipDisplayStyle = .shadedPanels
  visible.bodies = []
  visible.speed = 8
  visible.celestials = [.init(kind: .planet, position: .init(0, 0, 5000), radius: 1500)]
  var offscreen = visible
  offscreen.celestials[0].position = .init(20000, 0, 5000)
  let preview = PlanetPreview(
    galaxy: visible.commander.galaxy, system: visible.currentSystem,
    bounds: .init(x: 0, y: 0, width: 768, height: 768), time: visible.time)
  let gpuImage = try #require(PlanetRenderer.image(for: preview, diameter: 768))
  var samples: [PlanetContextSample] = []
  var metadata: [PlanetContextMetadata] = []
  let variants = PlanetContextVariant.allCases
  // Two excluded warmups, then ten measured rounds. Rotate variant order and
  // alternate scene order so background contention does not favour a long lane.
  for round in -2..<10 {
    let offset = (round + 2) % variants.count
    for index in variants.indices {
      let variant = variants[(index + offset) % variants.count]
      let sceneOrder = round % 2 == 0 ? [true, false] : [false, true]
      for isVisible in sceneOrder {
        var image: CGImage?
        let cpu = contextExperimentCPU()
        let wall = DispatchTime.now().uptimeNanoseconds
        autoreleasepool {
          image = contextExperimentImage(isVisible ? visible : offscreen, variant: variant)
        }
        let elapsedWall = Double(DispatchTime.now().uptimeNanoseconds - wall) / 1_000_000
        let elapsedCPU = (contextExperimentCPU() - cpu) * 1000
        let result = try #require(image)
        #expect(result.width == 3024 && result.height == 1964)
        if round >= 0 {
          samples.append(
            .init(
              variant: variant, visible: isVisible, trial: round,
              wallMS: elapsedWall, cpuMS: elapsedCPU))
        }
        if round == -2 && isVisible {
          metadata.append(
            .init(
              variant: variant,
              imageColourSpace: result.colorSpace?.name.map { $0 as String } ?? "unnamed",
              bitmapInfo: result.bitmapInfo.rawValue, bytesPerRow: result.bytesPerRow))
        }
      }
    }
  }
  let summaries = variants.flatMap { variant in
    [true, false].map { isVisible -> PlanetContextSummary in
      let group = samples.filter { $0.variant == variant && $0.visible == isVisible }
      return .init(
        variant: variant, visible: isVisible,
        wallP50: contextPercentile(group.map(\.wallMS), fraction: 0.5),
        wallP95: contextPercentile(group.map(\.wallMS), fraction: 0.95),
        cpuP50: contextPercentile(group.map(\.cpuMS), fraction: 0.5),
        cpuP95: contextPercentile(group.map(\.cpuMS), fraction: 0.95))
    }
  }
  let report = PlanetContextReport(
    device: device,
    gpuImageColourSpace: gpuImage.colorSpace?.name.map { $0 as String } ?? "unnamed",
    drawingColourSpace: CGColor(red: 1, green: 0, blue: 0, alpha: 1).colorSpace?.name.map {
      $0 as String
    } ?? "unnamed",
    width: 1512, height: 982, scale: 2, warmupRounds: 2,
    metadata: metadata, samples: samples, summaries: summaries,
    notes: [
      "Release opt-in, headless. Same static Game and drawGame for every context variant; cached GPU texture, no camera/time drift.",
      "Measurements include context allocation, clear, drawGame, makeImage and autoreleasepool; exclude assertions/metadata and Metal preparation.",
      "Process user+system CPU and monotonic wall milliseconds; ten round-robin trials per variant/scene, nearest-rank p95 equals maximum.",
      "GPU image is sRGB. DeviceRGB contexts may convert it; brush colours have the separately recorded drawing colour space.",
      "Other work can contend. Same-run rotated variant order controls systematic lane bias; native layer-update/scanout performance is not measured.",
      "Production renderer, NativeGraphics and input files unchanged by this experiment.",
    ])
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  try encoder.encode(report).write(
    to: URL(fileURLWithPath: "/tmp/elite-planet-context-variants.json"))
  print(
    "Planet context variants: /tmp/elite-planet-context-variants.json, \(samples.count) samples")
}
