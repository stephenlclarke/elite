import Darwin
import Foundation
import Testing

@testable import L337Core

private final class CommanderSaveSafetyBundle: NSObject {}

private func safetyProgress(_ payloads: [String: Int]) -> MissionProgress {
  var progress = MissionProgress(
    version: "1.0.0", digest: String(repeating: "0", count: 64), stage: "carrying")
  progress.payloads = payloads
  return progress
}

struct CommanderSaveSafetyTests {
  @Test func extremeDecodedMissionPayloadsAreRejectedByTheAppWithoutCrashing() throws {
    let executable = Bundle(for: CommanderSaveSafetyBundle.self).bundleURL
      .deletingLastPathComponent().appendingPathComponent("L337")
    #expect(FileManager.default.isExecutableFile(atPath: executable.path))
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: file) }
    for payloads in [
      ["first": Int.max, "second": Int.max], ["first": Int.min], ["first": -1],
      ["first": 1_000_001],
    ] {
      var commander = Commander()
      commander.missionProgress = ["missing/mission": safetyProgress(payloads)]
      let original = try JSONEncoder().encode(commander)
      try original.write(to: file)
      let process = Process()
      process.executableURL = executable
      process.arguments = ["--validate-commander-save", file.path]
      process.standardOutput = FileHandle.nullDevice
      process.standardError = FileHandle.nullDevice
      try process.run()
      process.waitUntilExit()
      #expect(process.terminationReason == .exit && process.terminationStatus == EXIT_FAILURE)
      #expect(try Data(contentsOf: file) == original)
    }
  }

  @Test func invalidPayloadAdmissionPreservesTheWholeLiveStateAndFile() async throws {
    let runtime = GameRuntime()
    let before = await runtime.snapshot()
    var corrupt = Commander()
    corrupt.missionProgress = [
      "missing/mission": safetyProgress(["first": Int.max, "second": Int.max])
    ]
    #expect(corrupt.checkedMissionPayloadTonnes == nil && corrupt.checkedCargoTonnes == nil)
    #expect(corrupt.missionPayloadTonnes == Int.max && corrupt.cargoTonnes == Int.max)
    #expect(!corrupt.valid)
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: file) }
    let original = try JSONEncoder().encode(corrupt)
    try original.write(to: file)
    await #expect(throws: SaveError.self) { try await runtime.load(from: file) }
    let after = await runtime.snapshot()
    #expect(after.commander == before.commander && after.bodies == before.bodies)
    #expect(after.inventoryContextEpoch == before.inventoryContextEpoch)
    #expect(try Data(contentsOf: file) == original)
  }

  @Test func allSupportedMissionPayloadBoundsAndMaximumOrdinaryCargoRemainExact() throws {
    var commander = Commander()
    commander.unlimitedCargo = true
    let payloads = Dictionary(uniqueKeysWithValues: (0..<128).map { ("payload\($0)", 1_000_000) })
    commander.missionProgress = Dictionary(
      uniqueKeysWithValues: (0..<128).map { ("missing/mission\($0)", safetyProgress(payloads)) })
    #expect(commander.valid && commander.missionPayloadTonnes == 16_384_000_000)
    #expect(commander.cargoTonnes == 16_384_000_000)
    let decoded = try JSONDecoder().decode(Commander.self, from: JSONEncoder().encode(commander))
    #expect(decoded == commander && decoded.valid)
    commander.missionProgress = [:]
    commander.cargo[0] = Int.max / 17
    #expect(commander.valid && commander.cargoTonnes == Int.max / 17)
    commander.missionProgress = ["missing/mission": safetyProgress(["parcel": 1])]
    #expect(!commander.valid && commander.checkedCargoTonnes == Int.max / 17 + 1)
  }

  @Test func boundedReaderAcceptsTheExactByteLimitAndRejectsSparseOrNonregularFiles() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("save.json")
    var exact = try JSONEncoder().encode(Commander())
    exact.append(Data(repeating: 32, count: CommanderSaveInput.maximumBytes - exact.count))
    try exact.write(to: file)
    #expect(try CommanderSaveInput.read(from: file) == exact)
    let handle = try FileHandle(forWritingTo: file)
    try handle.truncate(atOffset: 64 * 1024 * 1024)
    try handle.close()
    #expect(throws: SaveError.self) { try CommanderSaveInput.read(from: file) }
    #expect(throws: SaveError.self) { try CommanderSaveInput.read(from: folder) }
    #expect(throws: SaveError.self) {
      try CommanderSaveInput.read(from: URL(fileURLWithPath: "/dev/zero"))
    }
    let fifo = folder.appendingPathComponent("fifo")
    let created = fifo.path.withCString { mkfifo($0, 0o600) }
    #expect(created == 0)
    #expect(throws: SaveError.self) { try CommanderSaveInput.read(from: fifo) }
  }
}
