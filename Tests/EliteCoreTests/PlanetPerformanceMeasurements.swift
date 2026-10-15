import AppKit
import Darwin
import Foundation
import Testing

@testable import EliteCore
@testable import EliteMac

private struct PlanetTiming: Codable {
  let scenario: String
  let stage: String
  let trial: Int
  let diameter: Int?
  let width: Int?
  let height: Int?
  let scale: Int?
  let wallMilliseconds: Double
  let cpuMilliseconds: Double
}

private func planetProcessCPU() -> Double {
  var usage = rusage()
  getrusage(RUSAGE_SELF, &usage)
  return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
    + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
}

@MainActor
private func planetMeasure(
  scenario: String, stage: String, trial: Int, diameter: Int? = nil,
  width: Int? = nil, height: Int? = nil, scale: Int? = nil,
  operation: () -> Void
) -> PlanetTiming {
  let cpu = planetProcessCPU()
  let wall = DispatchTime.now().uptimeNanoseconds
  operation()
  let wallEnd = DispatchTime.now().uptimeNanoseconds
  let cpuEnd = planetProcessCPU()
  return .init(
    scenario: scenario, stage: stage, trial: trial, diameter: diameter,
    width: width, height: height, scale: scale,
    wallMilliseconds: Double(wallEnd - wall) / 1_000_000,
    cpuMilliseconds: (cpuEnd - cpu) * 1000)
}

private struct PlanetTimingSummary: Codable {
  let scenario: String
  let stage: String
  let samples: Int
  let wallP50: Double
  let wallP95: Double
  let wallP99: Double
  let cpuP50: Double
  let cpuP95: Double
  let cpuP99: Double
}

private func planetPercentile(_ values: [Double], _ fraction: Double) -> Double {
  let sorted = values.sorted()
  return sorted[max(0, min(sorted.count - 1, Int(ceil(Double(sorted.count) * fraction)) - 1))]
}

private struct PlanetPerformanceReport: Codable {
  let sha: String
  let buildMode: String
  let processorCount: Int
  let operatingSystem: String
  let notes: [String]
  let samples: [PlanetTiming]
  let summaries: [PlanetTimingSummary]
}

private func planetProfileSHA() throws -> String {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
  process.arguments = ["rev-parse", "HEAD"]
  let output = Pipe()
  process.standardOutput = output
  try process.run()
  process.waitUntilExit()
  return String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    .trimmingCharacters(in: .whitespacesAndNewlines)
}

/// Explicit opt-in: this helper performs no work during ordinary test runs.
@MainActor @Test func measurePlanetPerformance() throws {
  guard ProcessInfo.processInfo.environment["ELITE_PLANET_PROFILE"] == "1" else { return }
  var samples: [PlanetTiming] = []
  let systems = Universe.systemsIncludingPlugh()
  var identity = 100
  func preview(system: Int, diameter: Int, time: Double = 0) -> PlanetPreview {
    .init(
      galaxy: 0, system: systems[system],
      bounds: .init(x: 0, y: 0, width: Double(diameter), height: Double(diameter)), time: time)
  }
  for diameter in [128, 256, 512, 768] {
    for trial in 0..<3 {
      let value = preview(system: identity, diameter: diameter)
      identity += 1
      var result: CGImage?
      samples.append(
        planetMeasure(
          scenario: "cold-terrain-\(diameter)", stage: "PlanetRenderer.image",
          trial: trial, diameter: diameter
        ) { result = PlanetRenderer.image(for: value, diameter: diameter) })
      #expect(result != nil)
    }
    let system = identity
    identity += 1
    let value = preview(system: system, diameter: diameter)
    _ = PlanetRenderer.image(for: value, diameter: diameter)
    for trial in 0..<8 {
      samples.append(
        planetMeasure(
          scenario: "warm-hit-\(diameter)", stage: "PlanetRenderer.image",
          trial: trial, diameter: diameter
        ) { _ = PlanetRenderer.image(for: value, diameter: diameter) })
    }
    for trial in 0..<5 {
      let phase = preview(system: system, diameter: diameter, time: Double(trial + 1))
      samples.append(
        planetMeasure(
          scenario: "phase-only-miss-\(diameter)", stage: "PlanetRenderer.image",
          trial: trial, diameter: diameter
        ) { _ = PlanetRenderer.image(for: phase, diameter: diameter) })
    }
    for trial in 0..<6 {
      // Prime the exact base outside timing; 769 is invalid, so 768 uses only -1.
      let changed = diameter == 768 || trial % 2 == 0 ? diameter - 1 : diameter + 1
      _ = PlanetRenderer.image(for: value, diameter: diameter)
      samples.append(
        planetMeasure(
          scenario: "diameter-miss-\(diameter)", stage: "PlanetRenderer.image",
          trial: trial, diameter: changed
        ) { _ = PlanetRenderer.image(for: value, diameter: changed) })
    }
  }
  for (width, height) in [(1512, 982), (768, 768)] {
    for visible in [true, false] {
      var initial = Game(executive: false)
      initial.launch()
      initial.commander.shipDisplayStyle = .shadedPanels
      initial.bodies = []
      initial.speed = 8
      initial.celestials = [
        .init(
          kind: .planet,
          position: visible ? .init(0, 0, 5000) : .init(20000, 0, 5000), radius: 1500)
      ]
      let fixture = initial
      let name = "\(visible ? "visible" : "offscreen")-flight-\(width)x\(height)-2x"
      var simulation = fixture
      var snapshots: [Game] = []
      for frame in 0..<30 {
        samples.append(
          planetMeasure(
            scenario: name, stage: "simulation.tick", trial: frame,
            width: width, height: height, scale: 2
          ) { simulation.tick(delta: 1.0 / 60) })
        snapshots.append(simulation)
      }
      for (frame, snapshot) in snapshots.enumerated() {
        var rendered: Frame?
        samples.append(
          planetMeasure(
            scenario: name, stage: "Display.presentation", trial: frame,
            width: width, height: height, scale: 2
          ) {
            rendered = Display.presentation(snapshot, width: Double(width), height: Double(height))
          })
        #expect(rendered != nil)
      }
      for (frame, snapshot) in snapshots.enumerated() {
        var image: CGImage?
        samples.append(
          planetMeasure(
            scenario: name, stage: "imageForGame.endToEnd", trial: frame,
            width: width, height: height, scale: 2
          ) {
            autoreleasepool {
              image = imageForGame(snapshot, width: width, height: height, scale: 2)
            }
          })
        #expect(image != nil)
      }
    }
  }
  let groups = Dictionary(grouping: samples) { $0.scenario + "|" + $0.stage }
  let summaries = groups.keys.sorted().map { key -> PlanetTimingSummary in
    let group = groups[key]!
    let wall = group.map(\.wallMilliseconds)
    let cpu = group.map(\.cpuMilliseconds)
    return .init(
      scenario: group[0].scenario, stage: group[0].stage, samples: group.count,
      wallP50: planetPercentile(wall, 0.5), wallP95: planetPercentile(wall, 0.95),
      wallP99: planetPercentile(wall, 0.99), cpuP50: planetPercentile(cpu, 0.5),
      cpuP95: planetPercentile(cpu, 0.95), cpuP99: planetPercentile(cpu, 0.99))
  }
  #if DEBUG
    let buildMode = "debug"
  #else
    let buildMode = "release"
  #endif
  let report = PlanetPerformanceReport(
    sha: try planetProfileSHA(), buildMode: buildMode,
    processorCount: ProcessInfo.processInfo.processorCount,
    operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
    notes: [
      "Milliseconds; CPU is process user+system getrusage; wall is monotonic DispatchTime.",
      "imageForGame includes Display.presentation, bitmap allocation and rasterization; these costs overlap, do not sum stages.",
      "Cold terrain uses previously unused identities; warm/phase/diameter cases reuse terrain. Diameter trials prime exact base outside timing then measure +/-1; 768+1 is invalid and omitted.",
      "Flight snapshots share an immutable starting fixture; 30 frames at speed8, delta1/60. Each stage consumes equivalent snapshots.",
      "Bounded small samples: nearest-rank p95/p99 often equal maximum. No latency assertion is imposed.",
      "Other checkout CI/export work may contend for CPU; compare process CPU as well as wall and repeat if conclusions depend on small differences.",
    ], samples: samples, summaries: summaries)
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  let path =
    ProcessInfo.processInfo.environment["ELITE_PLANET_PROFILE_OUTPUT"]
    ?? "/tmp/elite-planet-baseline-5111907.json"
  try encoder.encode(report).write(to: URL(fileURLWithPath: path), options: .atomic)
  print("Planet profiling report: \(path), \(samples.count) samples, \(buildMode)")
}
