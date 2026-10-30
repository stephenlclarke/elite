import Foundation
import Testing

@testable import L337Core
@testable import L337Mac

@MainActor
struct StartupFrameObservationTests {
  private let source = String(repeating: "a", count: 40)

  @Test func startupArgumentsSelectTheExactSceneAndFiniteDistinctDrawCount() throws {
    for (name, expected, frames) in [("title", Screen.title, 2), ("credits", .demo, 120)] {
      let request = try #require(
        try PlanetFrameProfiler.startupRequest(
          arguments: [
            "L337", "--profile-startup-frames", "/tmp/startup-observation", source, name,
            String(frames),
          ]))
      #expect(request.directory.path == "/tmp/startup-observation")
      #expect(request.sourceSHA == source && request.scene.screen == expected)
      #expect(request.frames == frames)
      let game = request.game()
      #expect(game.screen == expected && game.time == 0 && game.docked && !game.paused)
      #expect(game.commander == Game(executive: false).commander)
      #expect(!request.completed(distinctDrawnFrames: frames - 1, screen: expected))
      #expect(request.completed(distinctDrawnFrames: frames, screen: expected))
      #expect(!request.completed(distinctDrawnFrames: frames, screen: .front))
    }
  }

  @Test func malformedOrAmbiguousStartupRequestsRefuseWithoutCreatingOutput() throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let valid = ["L337", "--profile-startup-frames", path.path, source, "title", "30"]
    var invalid: [[String]] = [Array(valid.dropLast()), valid + ["extra"]]
    for (index, value) in [
      (2, "relative/output"), (3, "short"), (3, String(repeating: "A", count: 40)),
      (4, "planet"), (5, "0"), (5, "1"), (5, "121"), (5, "3.5"),
    ] {
      var changed = valid
      changed[index] = value
      invalid.append(changed)
    }
    invalid.append(["L337", "--profile-planet-frames"] + Array(valid.dropFirst()))
    for arguments in invalid {
      #expect(throws: (any Error).self) {
        try PlanetFrameProfiler.startupRequest(arguments: arguments)
      }
    }
    #expect(!FileManager.default.fileExists(atPath: path.path))
  }

  @Test func ordinaryAndPlanetLaunchesRetainTheirExistingObserverMode() throws {
    #expect(try PlanetFrameProfiler.startupRequest(arguments: ["L337"]) == nil)
    #expect(
      try PlanetFrameProfiler.startupRequest(
        arguments: [
          "L337", "--profile-planet-frames", "/tmp/planet-observation", source, "compact",
        ])
        == nil)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let profile = try PlanetFrameProfiler(
      directory: directory, sourceSHA: source, system: Game(executive: false).currentSystem,
      mode: .compact)
    #expect(profile.startupRequest == nil && !profile.completedSuccessfully)
    #expect(FileManager.default.fileExists(atPath: directory.path))
  }
}
