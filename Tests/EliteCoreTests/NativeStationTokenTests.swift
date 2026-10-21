import Foundation
import Testing

@testable import EliteCore

@Test func stationIdentityTokensKeepExactASCIIAndByteBoundsWithoutGrantingSourceAuthority() throws {
  let source = try #require(NativeStationSource.bindings.first)
  let world = UUID()
  func identity(_ key: String) -> NativeStationIdentity {
    .init(
      world: world, system: source.system, definition: source.kind.sourceDefinition,
      version: "1.5.4", key: key)
  }
  let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._"
  let allowed = Set(alphabet.unicodeScalars.map(\.value))
  for value in UInt32(0)...255 {
    let character = String(try #require(UnicodeScalar(value)))
    #expect(identity(character).valid == allowed.contains(value))
  }
  #expect(identity(alphabet).valid)
  #expect(identity(String(repeating: "A", count: 80)).valid)
  for key in [
    "", String(repeating: "A", count: 81), "A B", "A/B", "A:B", "A\nB", "A\0B",
    "A\u{200D}B", "e\u{301}", "\u{FF21}", String(repeating: "\u{E9}", count: 40),
  ] {
    #expect(!identity(key).valid)
  }
  let actual = source.identity(world: world)
  #expect(actual.valid && NativeStationSource.binding(for: actual) == source)
  let alias = identity(actual.key + ".")
  #expect(alias.valid && NativeStationSource.binding(for: alias) == nil)
  let outsideLocalSource = NativeStationIdentity(
    world: world, system: .init(galaxy: source.system.galaxy, system: 256),
    definition: source.kind.sourceDefinition, version: "1.5.4", key: actual.key)
  #expect(!outsideLocalSource.valid && NativeStationSource.binding(for: outsideLocalSource) == nil)
}
