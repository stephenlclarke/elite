import AppKit
import CryptoKit
import EliteCore
import Foundation

/// Opt-in observation of the ordinary application loop; it never runs its own draw loop.
@MainActor
final class PlanetFrameProfiler {
  private enum Phase: String {
    case warmCompact, compact, settleCompact, fullscreenTransition, warmFullscreen, fullscreen
    case settleFullscreen, finished
  }
  private struct Sample: Codable {
    let id: UInt64
    let phase: String
    let index: Int
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
    var widthPixels: Int?
    var heightPixels: Int?
    var fullscreen: Bool?
    var backend: String?
    var planets: Int?
    var largestPlanetPixels: Int?
    var simulationSeconds: Double?
    var pitch: Double?
    var yaw: Double?
    var roll: Double?
    var throttle: Double?
  }
  private struct Summary: Codable {
    let phase: String
    let submittedFrames: Int
    let drawnFrames: Int
    let planetFrames: Int
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
    let declaredSourceSHA: String
    let executableSHA256: String
    let success: Bool
    let error: String?
    let timingInterpretation: String
    let comparison: String
    let warmupFramesPerWindow: Int
    let requestedSampleFramesPerWindow: Int
    let system: String
    let fullscreenEntered: Bool
    let summaries: [Summary]
    let samples: [Sample]
  }

  let directory: URL
  let sourceSHA: String
  private let systemDescription: String
  private let origin = ContinuousClock.now
  private var phase = Phase.warmCompact
  private var phaseFrames = 0
  private var nextID: UInt64 = 0
  private(set) var currentID: UInt64?
  private var currentPhase = Phase.warmCompact
  private var samples: [UInt64: Sample] = [:]
  private var lastLoop: ContinuousClock.Instant?
  private var lastDraw: ContinuousClock.Instant?
  private var transitionStarted: ContinuousClock.Instant?
  private var fullscreenEntered = false
  private var capturing = false
  private(set) var completedSuccessfully = false
  private var finished = false
  private let warmupFrames = 60
  private let sampleFrames = 240

  init(directory: URL, sourceSHA: String, system: StarSystem) throws {
    guard directory.path.hasPrefix("/"), !FileManager.default.fileExists(atPath: directory.path),
      sourceSHA.count == 40, sourceSHA.allSatisfy({ "0123456789abcdef".contains($0) })
    else { throw CocoaError(.fileWriteInvalidFileName) }
    self.directory = directory
    self.sourceSHA = sourceSHA
    systemDescription =
      "G0 / \(system.id) \(system.name) / economy \(system.economy) / government \(system.government) / technology \(system.technology)"
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  static func elapsed(_ start: ContinuousClock.Instant, _ end: ContinuousClock.Instant) -> Double {
    let value = start.duration(to: end).components
    return Double(value.seconds) + Double(value.attoseconds) / 1e18
  }

  func beginFrame(in view: GameView) {
    guard !finished else { return }
    if phase == .fullscreenTransition, let started = transitionStarted,
      Self.elapsed(started, ContinuousClock.now) > 15
    {
      fail("The native fullscreen transition did not complete.")
      return
    }
    let now = ContinuousClock.now
    nextID += 1
    currentID = nextID
    currentPhase = phase
    if phase == .compact || phase == .fullscreen {
      guard view.window?.isKeyWindow == true, view.window?.isVisible == true,
        !view.game.docked, view.game.screen.isFlight
      else {
        fail("The controlled native flight window is no longer active.")
        return
      }
      samples[nextID] = Sample(
        id: nextID, phase: phase.rawValue, index: phaseFrames,
        startedSeconds: Self.elapsed(origin, now),
        loopIntervalMilliseconds: lastLoop.map { Self.elapsed($0, now) * 1000 })
      let quadrant = min(3, phaseFrames / 60)
      if phaseFrames % 60 == 0 { view.pending.append(String(quadrant + 1)) }
      // Feed the real two-contact flight-yoke path with a small, repeating steering input.
      let offset = quadrant % 2 == 0 ? 0.04 : -0.04
      view.held.removeAll()
      view.updateTrackpad(positions: [
        .init(0.52 + offset, 0.52), .init(0.54 + offset, 0.54),
      ])
    } else {
      view.held.removeAll()
      view.updateTrackpad(positions: [])
    }
    lastLoop = now
  }

  func submitted(
    in view: GameView, commands: Double, advance: Double, submission: Double
  ) {
    guard let id = currentID, var sample = samples[id] else { return }
    sample.commandsMilliseconds = commands * 1000
    sample.actorAdvanceMilliseconds = advance * 1000
    sample.submissionMilliseconds = submission * 1000
    sample.simulationSeconds = view.game.commander.flightSimulation.physicalTime
    let controls = view.controls
    sample.pitch = controls.pitch
    sample.yaw = controls.yaw
    sample.roll = controls.roll
    sample.throttle = controls.throttle
    samples[id] = sample
  }

  func drew(
    in view: GameView, id: UInt64?, frame: Frame, presentation: Double, drawing: Double,
    at now: ContinuousClock.Instant
  ) {
    guard !capturing, let id, var sample = samples[id] else { return }
    let backing = view.convertToBacking(view.bounds)
    sample.presentationMilliseconds = presentation * 1000
    sample.drawMilliseconds = drawing * 1000
    sample.drawIntervalMilliseconds = lastDraw.map { Self.elapsed($0, now) * 1000 }
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
    }
    .max()
    samples[id] = sample
    lastDraw = now
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
    case .warmCompact where phaseFrames >= warmupFrames:
      changePhase(.compact)
    case .compact where phaseFrames >= sampleFrames:
      view.pending.append("1")
      changePhase(.settleCompact)
    case .settleCompact where phaseFrames >= 6:
      do { try capture(view, name: "compact") } catch {
        fail(error.localizedDescription)
        return
      }
      changePhase(.fullscreenTransition)
      transitionStarted = ContinuousClock.now
      view.window?.toggleFullScreen(nil)
    case .warmFullscreen where phaseFrames >= warmupFrames:
      changePhase(.fullscreen)
    case .fullscreen where phaseFrames >= sampleFrames:
      view.pending.append("1")
      changePhase(.settleFullscreen)
    case .settleFullscreen where phaseFrames >= 6:
      do { try capture(view, name: "fullscreen") } catch {
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
    changePhase(.warmFullscreen)
  }

  func fail(_ message: String) { finish(error: message) }
  func cancelled() {
    if !finished { finish(error: "The profiling window closed before completion.") }
  }

  private func changePhase(_ next: Phase) {
    phase = next
    phaseFrames = 0
    lastLoop = nil
    lastDraw = nil
  }

  private func capture(_ view: GameView, name: String) throws {
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
      to: directory.appendingPathComponent(name + ".png"), options: .withoutOverwriting)
  }

  private func finish(error: String?) {
    guard !finished else { return }
    finished = true
    phase = .finished
    let values = samples.values.sorted { $0.id < $1.id }
    let summaries = [Phase.compact, .fullscreen].map { phase in
      let frames = values.filter { $0.phase == phase.rawValue }
      let intervals = frames.compactMap(\.drawIntervalMilliseconds)
      return Summary(
        phase: phase.rawValue, submittedFrames: frames.count,
        drawnFrames: frames.filter { $0.drawMilliseconds != nil }.count,
        planetFrames: frames.filter { ($0.planets ?? 0) > 0 }.count,
        drawIntervalP50Milliseconds: percentile(intervals, fraction: 0.5),
        drawIntervalP95Milliseconds: percentile(intervals, fraction: 0.95),
        drawIntervalMaximumMilliseconds: intervals.max(),
        processingP95Milliseconds: percentile(
          frames.compactMap(\.processingMilliseconds), fraction: 0.95),
        presentationP95Milliseconds: percentile(
          frames.compactMap(\.presentationMilliseconds), fraction: 0.95),
        drawP95Milliseconds: percentile(frames.compactMap(\.drawMilliseconds), fraction: 0.95),
        estimatedMissed60HzIntervals: intervals.reduce(0) {
          $0 + max(0, Int(($1 / (1000 / 60)).rounded()) - 1)
        })
    }
    let valid =
      error == nil && fullscreenEntered
      && summaries.allSatisfy {
        $0.submittedFrames == sampleFrames && $0.drawnFrames > 0 && $0.planetFrames > 0
      }
    do {
      let binary = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[0]))
      let hash = SHA256.hash(data: binary).map { String(format: "%02x", $0) }.joined()
      let report = Report(
        scenario:
          "native-industrial-flyby-v1; default native seed; same four-view/two-contact input schedule per window",
        declaredSourceSHA: sourceSHA, executableSHA256: hash, success: valid,
        error: error
          ?? (valid ? nil : "Required native fullscreen or visible planet samples are missing."),
        timingInterpretation:
          "Monotonic elapsed spans include actor queue and GPU wait; not CPU-only time, physical scanout or input latency. Missed 60-Hz intervals are rounded estimates from observed draws.",
        comparison:
          "Candidate measurement only. A before/after claim requires an independently identified baseline with identical instrumentation and scenario.",
        warmupFramesPerWindow: warmupFrames, requestedSampleFramesPerWindow: sampleFrames,
        system: systemDescription, fullscreenEntered: fullscreenEntered,
        summaries: summaries, samples: values)
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      try encoder.encode(report).write(
        to: directory.appendingPathComponent("profile.json"), options: .withoutOverwriting)
      completedSuccessfully = valid
    } catch {
      print("Planet profiling failed: \(error.localizedDescription)")
    }
    // Stop the application event loop so main can return a failing exit status when needed.
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
