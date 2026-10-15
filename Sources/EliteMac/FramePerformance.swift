import Foundation
import EliteCore

/// Opt-in, bounded native diagnostics. Intervals measure layer updates, not scanout.
@MainActor
enum FramePerformance {
  private static let path = ProcessInfo.processInfo.environment["ELITE_FRAME_PROFILE_OUTPUT"]
  private static var samples: [Sample] = []
  private static var previous: UInt64?
  private static var planetVisible = false
  private static var scenario: String?
  private static var simulationTick: Int?
  private static var scriptedPitch: Double?
  private static var state: SimulationState?
  private static var projectedBounds: [ProjectedBounds]?
  private struct CelestialState: Codable {
    let kind: String
    let position: Vector3?
    let radius: Double?
  }
  private struct TrafficState: Codable {
    let id: Int
    let position: Vector3?
    let orientation: Basis3?
    let rotation: Double?
  }
  private struct SimulationState: Codable {
    // Legacy Game moves scene coordinates relative to the camera; no absolute playerPose exists.
    let coordinateConvention: String
    let delta: Double?
    let time: Double?
    let speed: Double?
    let pitch: Double?
    let roll: Double?
    let yaw: Double?
    let energy: Double?
    let frontShield: Double?
    let rearShield: Double?
    let cabinTemperature: Double?
    let celestials: [CelestialState]
    let traffic: [TrafficState]
    let valid: Bool
  }
  private struct ProjectedBounds: Codable {
    let kind: String
    let x: Double?
    let y: Double?
    let width: Double?
    let height: Double?
    let valid: Bool
  }
  private struct Sample: Codable {
    let intervalMilliseconds: Double?
    let renderMilliseconds: Double
    let pitch: Double
    let screen: String
    let width: Int
    let height: Int
    let scale: Int
    let planetVisible: Bool
    let scenario: String?
    let simulationTick: Int?
    let scriptedPitch: Double?
    let simulation: SimulationState?
    let celestialBounds: [ProjectedBounds]?
  }
  static func begin() -> UInt64? {
    guard path != nil else { return nil }
    planetVisible = false
    projectedBounds = nil
    return DispatchTime.now().uptimeNanoseconds
  }
  private static func finite(_ value: Double) -> Double? { value.isFinite ? value : nil }
  private static func valid(_ value: Vector3) -> Bool {
    value.x.isFinite && value.y.isFinite && value.z.isFinite
  }
  static func noteScenario(name: String, tick: Int, pitch: Double, game: Game, delta: Double) {
    guard path != nil else { return }
    scenario = name
    simulationTick = tick
    scriptedPitch = finite(pitch)
    var isValid = [delta, game.time, game.speed, game.pitch, game.roll, game.yaw,
      game.energy, game.frontShield, game.rearShield, game.cabinTemperature].allSatisfy(\.isFinite)
      && game.screen != .gameOver && !game.docked && game.energy > 0
    let celestials = game.celestials.map { body in
      let position = game.viewPosition(body.position)
      let validBody = valid(position) && body.radius.isFinite && body.radius > 0
      isValid = isValid && validBody && position.length - body.radius > 2000
        && (body.kind != .sun || position.length > body.radius * 4)
      return CelestialState(kind: String(describing: body.kind),
        position: valid(position) ? position : nil, radius: finite(body.radius))
    }
    let traffic = game.bodies.map { body in
      let position = game.viewPosition(body.position)
      var orientation = Basis3()
      orientation.x = game.viewPosition(body.orientation.x)
      orientation.y = game.viewPosition(body.orientation.y)
      orientation.z = game.viewPosition(body.orientation.z)
      let validBasis = valid(orientation.x) && valid(orientation.y) && valid(orientation.z)
      isValid = isValid && valid(position) && validBasis && body.rotation.isFinite
      return TrafficState(id: body.id, position: valid(position) ? position : nil,
        orientation: validBasis ? orientation : nil, rotation: finite(body.rotation))
    }
    state = .init(coordinateConvention: "camera-relative scene, transformed to selected view",
      delta: finite(delta), time: finite(game.time), speed: finite(game.speed),
      pitch: finite(game.pitch), roll: finite(game.roll), yaw: finite(game.yaw),
      energy: finite(game.energy), frontShield: finite(game.frontShield),
      rearShield: finite(game.rearShield), cabinTemperature: finite(game.cabinTemperature),
      celestials: celestials, traffic: traffic, valid: isValid)
  }
  static func noteFrame(_ frame: Frame) {
    guard path != nil else { return }
    projectedBounds = frame.worldGraphics.compactMap { graphic in
      let kind: String
      let x: Double, y: Double, width: Double, height: Double
      switch graphic {
      case .planet(let preview):
        kind = "planet"
        x = preview.bounds.x; y = preview.bounds.y
        width = preview.bounds.width; height = preview.bounds.height
      case .point(let center, let radius, let opacity, let ink)
        where opacity == 0.15 && ink == .orange:
        kind = "sun-halo"
        x = center.x - radius; y = center.y - radius
        width = radius * 2; height = radius * 2
      default: return nil
      }
      return ProjectedBounds(kind: kind, x: finite(x), y: finite(y), width: finite(width),
        height: finite(height), valid: [x, y, width, height].allSatisfy(\.isFinite)
          && width > 0 && height > 0)
    }
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
        width: width, height: height, scale: scale, planetVisible: planetVisible,
        scenario: scenario, simulationTick: simulationTick, scriptedPitch: scriptedPitch,
        simulation: state, celestialBounds: projectedBounds))
    previous = start
  }
  static func flush() {
    guard let path, let data = try? JSONEncoder().encode(samples) else { return }
    try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
  }
}
