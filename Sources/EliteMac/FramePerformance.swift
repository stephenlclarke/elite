import Foundation

/// Opt-in, bounded native diagnostics. Intervals measure layer updates, not scanout.
@MainActor
enum FramePerformance {
  private static let path = ProcessInfo.processInfo.environment["ELITE_FRAME_PROFILE_OUTPUT"]
  private static var samples: [Sample] = []
  private static var previous: UInt64?
  private static var planetVisible = false
  private struct Sample: Codable {
    let intervalMilliseconds: Double?
    let renderMilliseconds: Double
    let pitch: Double
    let screen: String
    let width: Int
    let height: Int
    let scale: Int
    let planetVisible: Bool
  }
  static func begin() -> UInt64? {
    guard path != nil else { return nil }
    planetVisible = false
    return DispatchTime.now().uptimeNanoseconds
  }
  static func notePlanet() { if path != nil { planetVisible = true } }
  static func end(
    start: UInt64?, pitch: Double, screen: String, width: Int, height: Int, scale: Int
  ) {
    guard let start, samples.count < 12000 else { return }
    let end = DispatchTime.now().uptimeNanoseconds
    samples.append(
      .init(
        intervalMilliseconds: previous.map { Double(start - $0) / 1e6 },
        renderMilliseconds: Double(end - start) / 1e6, pitch: pitch, screen: screen,
        width: width, height: height, scale: scale, planetVisible: planetVisible))
    previous = start
  }
  static func flush() {
    guard let path, let data = try? JSONEncoder().encode(samples) else { return }
    try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
  }
}
