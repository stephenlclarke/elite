import AppKit
import CryptoKit
import EliteCore
import Foundation

/// Opt-in observation of the ordinary application loop, with no separate drawing loop.
@MainActor
final class PlanetFrameProfiler {
  enum WindowMode: String { case compact, fullscreen }
  private enum Phase: String {
    case fullscreenTransition, warmWindow, launching, warmFlight, flyby, settle, finished
  }
  private struct Sample: Codable {
    let id: UInt64
    let phase: String
    let startedSeconds: Double
    var loopIntervalMilliseconds: Double?
    var commandsMilliseconds: Double?
    var actorAdvanceMilliseconds: Double?
    var submissionMilliseconds: Double?
    var processingMilliseconds: Double?
    var deadlineOverrunMilliseconds: Double?
    var presentationMilliseconds: Double?
    var drawMilliseconds: Double?
    var drawIntervalMilliseconds: Double?
    var redraws = 0
    var widthPixels: Int?
    var heightPixels: Int?
    var fullscreen: Bool?
    var backend: String?
    var planets: Int?
    var largestPlanetPixels: Int?
    var simulationSeconds: Double?
    var gameSeconds: Double?
    var position: [Double]?
    var planetRelative: [Double]?
    var sunRelative: [Double]?
    var planetRange: Double?
    var sunRange: Double?
    var speed: Double?
    var cabinTemperature: Double?
    var camera: String?
    var fingerCount: Int?
    var pitch: Double?
    var yaw: Double?
    var roll: Double?
    var throttle: Double?
  }
  private struct DrawEvent: Codable {
    let submission: UInt64?
    let phase: String
    let seconds: Double
    let repeatedSubmission: Bool
    let capture: Bool
    let presentationMilliseconds: Double
    let drawMilliseconds: Double
  }
  private struct Origin: Codable {
    let position: [Double]
    let simulationSeconds: Double
    let gameSeconds: Double
    let planet: [Double]
    let planetRadius: Double
    let sun: [Double]
    let sunRadius: Double
    let ship: String
    let commander: String
    let nativeMaximumSpeed: Double
    let xyzzy: Bool
    let assistsEnabled: Bool
    let energy: Double
    let fuel: Int
  }
  private struct Geometry: Codable {
    var minimumPlanetRange: Double?
    var minimumSunRange: Double?
    var planetFront = false
    var planetRear = false
    var sunFront = false
    var sunRear = false
    var lastPosition: [Double]?
  }
  private struct Summary: Codable {
    let submittedFrames: Int
    let distinctDrawnFrames: Int
    let repeatedDraws: Int
    let coalescedOrUndrawnSubmissions: Int
    let planetFrames: Int
    let largestPlanetPixels: Int
    let drawIntervalP50Milliseconds: Double?
    let drawIntervalP95Milliseconds: Double?
    let drawIntervalMaximumMilliseconds: Double?
    let processingP95Milliseconds: Double?
    let presentationP95Milliseconds: Double?
    let drawP95Milliseconds: Double?
    let estimatedMissed60HzIntervals: Int
  }
  private struct Report: Codable {
    let scenario: String
    let windowMode: String
    let declaredSourceSHA: String
    let executableSHA256: String
    let success: Bool
    let error: String?
    let timingInterpretation: String
    let comparison: String
    let missionPackIsolation: String
    let system: String
    let fullscreenEntered: Bool
    let warmWindowFrames: Int
    let warmFlightSubmissions: Int
    let initial: Origin?
    let geometry: Geometry
    let summary: Summary
    let samples: [Sample]
    let draws: [DrawEvent]
  }

  let directory: URL
  let sourceSHA: String
  private let mode: WindowMode
  private let systemDescription: String
  private let clockOrigin = ContinuousClock.now
  private var phase: Phase
  private var phaseFrames = 0
  private var nextID: UInt64 = 0
  private(set) var currentID: UInt64?
  private var currentPhase: Phase
  private var samples: [UInt64: Sample] = [:]
  private var draws: [DrawEvent] = []
  private var lastLoopByPhase: [String: ContinuousClock.Instant] = [:]
  private var lastDistinctDrawByPhase: [String: ContinuousClock.Instant] = [:]
  private var transitionStarted: ContinuousClock.Instant?
  private var flightStarted: ContinuousClock.Instant?
  private var launchRequested: ContinuousClock.Instant?
  private var initial: Origin?
  private var geometry = Geometry()
  private var fullscreenEntered = false
  private var capturing = false
  private(set) var completedSuccessfully = false
  private var finished = false
  private var lastCameraKey: String?
  private let windowWarmupFrames = 60

  init(directory: URL, sourceSHA: String, system: StarSystem, mode: WindowMode) throws {
    guard directory.path.hasPrefix("/"), !FileManager.default.fileExists(atPath: directory.path),
      sourceSHA.count == 40, sourceSHA.allSatisfy({ "0123456789abcdef".contains($0) })
    else { throw CocoaError(.fileWriteInvalidFileName) }
    self.directory = directory
    self.sourceSHA = sourceSHA
    self.mode = mode
    phase = mode == .compact ? .warmWindow : .fullscreenTransition
    currentPhase = phase
    systemDescription =
      "G0 / \(system.id) \(system.name) / economy \(system.economy) / government \(system.government) / technology \(system.technology)"
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  static func elapsed(_ start: ContinuousClock.Instant, _ end: ContinuousClock.Instant) -> Double {
    let value = start.duration(to: end).components
    return Double(value.seconds) + Double(value.attoseconds) / 1e18
  }
  private static func coordinates(_ point: Vector3) -> [Double] { [point.x, point.y, point.z] }

  func beginFrame(in view: GameView) {
    guard !finished else { return }
    let now = ContinuousClock.now
    if phase == .fullscreenTransition {
      if transitionStarted == nil {
        transitionStarted = now
        view.window?.toggleFullScreen(nil)
      } else if let started = transitionStarted, Self.elapsed(started, now) > 15 {
        fail("The native fullscreen transition did not complete.")
        return
      }
    }
    if phase == .launching, let requested = launchRequested, Self.elapsed(requested, now) > 15 {
      fail("The ordinary launch command did not complete.")
      return
    }
    if let started = flightStarted, Self.elapsed(started, now) > 180 {
      fail("The normal-input flight did not complete its flyby within the diagnostic limit.")
      return
    }
    nextID += 1
    currentID = nextID
    currentPhase = phase
    samples[nextID] = Sample(
      id: nextID, phase: phase.rawValue, startedSeconds: Self.elapsed(clockOrigin, now),
      loopIntervalMilliseconds: lastLoopByPhase[phase.rawValue].map { Self.elapsed($0, now) * 1000 }
    )
    lastLoopByPhase[phase.rawValue] = now
    view.held.removeAll()
    if phase == .flyby {
      guard view.window?.isKeyWindow == true, view.window?.isVisible == true,
        !view.game.docked, view.game.screen.isFlight,
        let anchors = view.game.commander.flightSimulation.anchors
      else {
        fail("The controlled native flight window is no longer active.")
        return
      }
      // The original +Z launch line passes planet at 1.795R and sun at 4.746R.
      // Actual measurements below must prove those safe close passes occurred.
      view.updateTrackpad(positions: [.init(0.45, 0.5), .init(0.5, 0.5), .init(0.55, 0.5)])
      let pose = view.game.commander.flightSimulation.pose
      let target =
        pose.position.z < anchors.planet.position.z + anchors.planet.radius
        ? anchors.planet.position : anchors.sun.position
      let relative = pose.shipPoint(target)
      let key =
        abs(relative.x) > abs(relative.z)
        ? (relative.x > 0 ? "3" : "2") : (relative.z > 0 ? "0" : "1")
      if key != lastCameraKey {
        view.pending.append(key)
        lastCameraKey = key
      }
    } else {
      view.updateTrackpad(positions: [])
    }
  }

  /// Observe the actual launch snapshot before the ordinary actor advance.
  func willAdvance(in view: GameView) {
    guard phase == .launching, !view.game.docked,
      let anchors = view.game.commander.flightSimulation.anchors
    else { return }
    let flight = view.game.commander.flightSimulation
    initial = Origin(
      position: Self.coordinates(flight.pose.position), simulationSeconds: flight.physicalTime,
      gameSeconds: view.game.time, planet: Self.coordinates(anchors.planet.position),
      planetRadius: anchors.planet.radius, sun: Self.coordinates(anchors.sun.position),
      sunRadius: anchors.sun.radius, ship: view.game.commander.shipID,
      commander: view.game.commander.name,
      nativeMaximumSpeed: view.game.commander.performance.speed,
      xyzzy: view.game.commander.xyzzyActive,
      assistsEnabled: view.game.commander.unlimitedCash || view.game.commander.unlimitedCargo
        || view.game.commander.unlimitedMissiles || view.game.commander.unlimitedFuel
        || view.game.commander.unlimitedJumps,
      energy: view.game.energy, fuel: view.game.commander.fuel)
    flightStarted = ContinuousClock.now
    changePhase(.warmFlight)
  }

  func submitted(in view: GameView, commands: Double, advance: Double, submission: Double) {
    guard let id = currentID, var sample = samples[id] else { return }
    sample.commandsMilliseconds = commands * 1000
    sample.actorAdvanceMilliseconds = advance * 1000
    sample.submissionMilliseconds = submission * 1000
    let flight = view.game.commander.flightSimulation
    sample.simulationSeconds = flight.physicalTime
    sample.gameSeconds = view.game.time
    sample.position = Self.coordinates(flight.pose.position)
    sample.speed = view.game.speed
    sample.cabinTemperature = view.game.cabinTemperature
    sample.camera = String(describing: view.game.screen)
    sample.fingerCount = view.trackpad.fingerCount
    let controls = view.controls
    sample.pitch = controls.pitch
    sample.yaw = controls.yaw
    sample.roll = controls.roll
    sample.throttle = controls.throttle
    if let anchors = flight.anchors {
      let planet = flight.pose.shipPoint(anchors.planet.position)
      let sun = flight.pose.shipPoint(anchors.sun.position)
      sample.planetRelative = Self.coordinates(planet)
      sample.sunRelative = Self.coordinates(sun)
      sample.planetRange = planet.length
      sample.sunRange = sun.length
      if phase == .warmFlight || phase == .flyby {
        geometry.minimumPlanetRange = min(
          geometry.minimumPlanetRange ?? planet.length, planet.length)
        geometry.minimumSunRange = min(geometry.minimumSunRange ?? sun.length, sun.length)
        geometry.planetFront = geometry.planetFront || planet.z > anchors.planet.radius
        geometry.planetRear = geometry.planetRear || planet.z < -anchors.planet.radius
        geometry.sunFront = geometry.sunFront || sun.z > anchors.sun.radius
        geometry.sunRear = geometry.sunRear || sun.z < -anchors.sun.radius
        geometry.lastPosition = sample.position
      }
    }
    samples[id] = sample
  }

  func drew(
    in view: GameView, id: UInt64?, frame: Frame, presentation: Double, drawing: Double,
    at now: ContinuousClock.Instant
  ) {
    let previous = id.flatMap { samples[$0] }
    let repeated = previous?.drawMilliseconds != nil
    draws.append(
      DrawEvent(
        submission: id, phase: previous?.phase ?? "unsubmitted",
        seconds: Self.elapsed(clockOrigin, now),
        repeatedSubmission: repeated, capture: capturing,
        presentationMilliseconds: presentation * 1000, drawMilliseconds: drawing * 1000))
    guard !capturing, let id, var sample = previous else { return }
    if repeated {
      sample.redraws += 1
      samples[id] = sample
      return
    }
    let backing = view.convertToBacking(view.bounds)
    sample.presentationMilliseconds = presentation * 1000
    sample.drawMilliseconds = drawing * 1000
    // Only the first draw of a distinct submitted frame participates, within its own phase.
    sample.drawIntervalMilliseconds = lastDistinctDrawByPhase[sample.phase].map {
      Self.elapsed($0, now) * 1000
    }
    lastDistinctDrawByPhase[sample.phase] = now
    sample.widthPixels = Int(backing.width.rounded())
    sample.heightPixels = Int(backing.height.rounded())
    sample.fullscreen = view.window?.styleMask.contains(.fullScreen) == true
    sample.backend = PlanetRenderer.backendDescription
    let planets = (frame.graphics + frame.worldGraphics).compactMap { graphic -> PlanetPreview? in
      if case .planet(let planet) = graphic { return planet }
      return nil
    }
    sample.planets = planets.count
    let scale = view.bounds.width > 0 ? backing.width / view.bounds.width : 1
    sample.largestPlanetPixels = planets.map {
      min(768, max(32, Int(ceil($0.bounds.width * scale))))
    }.max()
    samples[id] = sample
  }

  func endFrame(
    in view: GameView, started: ContinuousClock.Instant, deadline: ContinuousClock.Instant
  ) {
    guard !finished else { return }
    if let id = currentID, var sample = samples[id] {
      let now = ContinuousClock.now
      sample.processingMilliseconds = Self.elapsed(started, now) * 1000
      sample.deadlineOverrunMilliseconds = max(0, Self.elapsed(deadline, now) * 1000)
      samples[id] = sample
    }
    guard phase == currentPhase else { return }
    phaseFrames += 1
    switch phase {
    case .warmWindow where phaseFrames >= windowWarmupFrames:
      view.pending.append("0")
      launchRequested = ContinuousClock.now
      changePhase(.launching)
    case .warmFlight:
      if let initial,
        view.game.commander.flightSimulation.physicalTime >= initial.simulationSeconds + 1
      {
        changePhase(.flyby)
      }
    case .flyby:
      guard let anchors = view.game.commander.flightSimulation.anchors else {
        fail("Flight anchors disappeared.")
        return
      }
      if view.game.commander.flightSimulation.pose.position.z > anchors.sun.position.z + 2
        * anchors.sun.radius
      {
        view.pending.append("1")
        changePhase(.settle)
      }
    case .settle where phaseFrames >= 6:
      do { try capture(view) } catch {
        fail(error.localizedDescription)
        return
      }
      finish(error: nil)
    default: break
    }
  }

  func enteredFullscreen(window: NSWindow) {
    guard phase == .fullscreenTransition, window.styleMask.contains(.fullScreen) else { return }
    fullscreenEntered = true
    changePhase(.warmWindow)
  }
  func fail(_ message: String) { finish(error: message) }
  func cancelled() {
    if !finished { finish(error: "The profiling window closed before completion.") }
  }
  private func changePhase(_ next: Phase) {
    phase = next
    phaseFrames = 0
  }

  private func capture(_ view: GameView) throws {
    capturing = true
    defer { capturing = false }
    guard let image = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
      throw CocoaError(.fileWriteUnknown)
    }
    view.cacheDisplay(in: view.bounds, to: image)
    guard let data = image.representation(using: .png, properties: [:]) else {
      throw CocoaError(.fileWriteUnknown)
    }
    try data.write(
      to: directory.appendingPathComponent(mode.rawValue + ".png"), options: .withoutOverwriting)
  }

  private func finish(error: String?) {
    guard !finished else { return }
    finished = true
    phase = .finished
    let values = samples.values.sorted { $0.id < $1.id }
    let measured = values.filter { $0.phase == Phase.flyby.rawValue }
    let intervals = measured.compactMap(\.drawIntervalMilliseconds)
    let drawn = measured.filter { $0.drawMilliseconds != nil }
    let summary = Summary(
      submittedFrames: measured.count, distinctDrawnFrames: drawn.count,
      repeatedDraws: measured.reduce(0) { $0 + $1.redraws },
      coalescedOrUndrawnSubmissions: measured.count - drawn.count,
      planetFrames: drawn.filter { ($0.planets ?? 0) > 0 }.count,
      largestPlanetPixels: drawn.compactMap(\.largestPlanetPixels).max() ?? 0,
      drawIntervalP50Milliseconds: percentile(intervals, fraction: 0.5),
      drawIntervalP95Milliseconds: percentile(intervals, fraction: 0.95),
      drawIntervalMaximumMilliseconds: intervals.max(),
      processingP95Milliseconds: percentile(
        measured.compactMap(\.processingMilliseconds), fraction: 0.95),
      presentationP95Milliseconds: percentile(
        drawn.compactMap(\.presentationMilliseconds), fraction: 0.95),
      drawP95Milliseconds: percentile(drawn.compactMap(\.drawMilliseconds), fraction: 0.95),
      estimatedMissed60HzIntervals: intervals.reduce(0) {
        $0 + max(0, Int(($1 / (1000 / 60)).rounded()) - 1)
      })
    let planetRatio = initial.flatMap { first in
      geometry.minimumPlanetRange.map { $0 / first.planetRadius }
    }
    let sunRatio = initial.flatMap { first in geometry.minimumSunRange.map { $0 / first.sunRadius }
    }
    let geometryValid =
      (planetRatio.map { (1.3...2.2).contains($0) } ?? false)
      && (sunRatio.map { (4.1...5.2).contains($0) } ?? false)
      && geometry.planetFront && geometry.planetRear && geometry.sunFront && geometry.sunRear
    let passedWorldPlane =
      initial.map { first in
        geometry.lastPosition.map { $0[2] > first.sun[2] + 2 * first.sunRadius } ?? false
      } ?? false
    let normalHeadingInputs = measured.allSatisfy {
      abs($0.pitch ?? 0) < 1e-6 && abs($0.yaw ?? 0) < 1e-6 && abs($0.roll ?? 0) < 1e-6
    }
    let valid =
      error == nil && initial?.xyzzy == false && initial?.assistsEnabled == false && geometryValid
      && passedWorldPlane && normalHeadingInputs
      && fullscreenEntered == (mode == .fullscreen) && summary.submittedFrames >= 120
      && summary.planetFrames >= 20 && summary.largestPlanetPixels >= 256
      && drawn.allSatisfy { $0.fullscreen == (mode == .fullscreen) }
      && measured.contains { ($0.throttle ?? 0) > 0.99 && $0.fingerCount == 3 }
    do {
      let binary = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[0]))
      let hash = SHA256.hash(data: binary).map { String(format: "%02x", $0) }.joined()
      let report = Report(
        scenario:
          "native-industrial-straight-flyby-v2; fresh normal commander; default native seed; one-second launch coast then held three-finger throttle on the original +Z heading",
        windowMode: mode.rawValue, declaredSourceSHA: sourceSHA, executableSHA256: hash,
        success: valid,
        error: error
          ?? (valid
            ? nil
            : "Required safe close passes, distinct visible planet draws or window/control evidence are missing."),
        timingInterpretation:
          "Monotonic elapsed spans include actor queue and GPU wait, not CPU-only time, physical scanout or input latency. Distinct-submission first draws determine intervals; repeated draws and undrawn/coalesced submissions are explicit. Missed 60-Hz intervals are rounded estimates.",
        comparison:
          "Candidate measurement only. Each window case starts a fresh normal launch. A before/after claim requires a named baseline with identical instrumentation, scene and input protocol, verified against the raw trajectory.",
        missionPackIsolation:
          "Bundled mission library with a fresh absent legacy TOML directory; default external Lua loading disabled.",
        system: systemDescription, fullscreenEntered: fullscreenEntered,
        warmWindowFrames: values.filter { $0.phase == Phase.warmWindow.rawValue }.count,
        warmFlightSubmissions: values.filter { $0.phase == Phase.warmFlight.rawValue }.count,
        initial: initial, geometry: geometry, summary: summary, samples: values, draws: draws)
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      try encoder.encode(report).write(
        to: directory.appendingPathComponent("profile.json"), options: .withoutOverwriting)
      completedSuccessfully = valid
    } catch { print("Planet profiling failed: \(error.localizedDescription)") }
    NSApp.stop(nil)
    if let event = NSEvent.otherEvent(
      with: .applicationDefined, location: .zero, modifierFlags: [],
      timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: 0, context: nil,
      subtype: 0, data1: 0, data2: 0)
    {
      NSApp.postEvent(event, atStart: true)
    }
  }

  private func percentile(_ values: [Double], fraction: Double) -> Double? {
    guard !values.isEmpty else { return nil }
    let ordered = values.sorted()
    return ordered[min(ordered.count - 1, Int(ceil(Double(ordered.count) * fraction)) - 1)]
  }
}
