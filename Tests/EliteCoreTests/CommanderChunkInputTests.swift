import Foundation
import Testing

@testable import EliteCore

struct CommanderChunkInputTests {
  @Test func explicitChunkLimitsAreExactAndRejectInvalidArithmeticBounds() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("chunk")
    let bytes = Data(repeating: 0x20, count: 32)
    try bytes.write(to: file)
    let exact = try CommanderSaveInput.read(from: file, maximumBytes: 32, denySymbolicLinks: true)
    #expect(exact == bytes)
    #expect(throws: SaveError.self) { try CommanderSaveInput.read(from: file, maximumBytes: 31) }
    #expect(throws: SaveError.self) { try CommanderSaveInput.read(from: file, maximumBytes: -1) }
    #expect(throws: SaveError.self) { try CommanderSaveInput.read(from: file, maximumBytes: .max) }
    try Data().write(to: file)
    let empty = try CommanderSaveInput.read(from: file, maximumBytes: 0)
    #expect(empty.isEmpty)
  }

  @Test func actualSymbolicLinkRefusalUsesTheOpenedDescriptorAndKeepsOrdinaryPolicy() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("real")
    let link = folder.appendingPathComponent("link")
    let bytes = Data("bounded chunk".utf8)
    try bytes.write(to: file)
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
    let ordinary = try CommanderSaveInput.read(from: link)
    #expect(ordinary == bytes)
    #expect(throws: POSIXError.self) {
      try CommanderSaveInput.read(
        from: link, maximumBytes: 128 * 1024 * 1024,
        denySymbolicLinks: true)
    }
    let direct = try CommanderSaveInput.read(
      from: file, maximumBytes: 128 * 1024 * 1024,
      denySymbolicLinks: true)
    #expect(direct == bytes)
  }
}
