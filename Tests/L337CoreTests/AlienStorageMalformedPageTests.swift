import Foundation
import Testing

@testable import L337Core

struct AlienStorageMalformedPageTests {
  @Test func authenticatedMalformedPageJoinsAreRejected() throws {
    var fixture = AlienStorageTestFixture()
    _ = try fixture.acquire(kind: AlienModuleKind.allCases[0])
    let snapshot = fixture.snapshot
    var pages = AlienStorageMemoryPages()
    let archive = try AlienStoragePageCodec.encode(snapshot: snapshot, previous: nil, into: &pages)
    let root = try JSONDecoder().decode(AlienStorageRoot.self, from: archive.rootData)
    let originalTree = try #require(root.indices.first(where: { $0.index == .sources })?.tree)
    let hash = try #require(originalTree.hash)
    let bytes = try #require(pages.pages[hash])
    let page = try JSONDecoder().decode(AlienStoragePage.self, from: bytes)
    let entry = try #require(page.entries.first)
    let malformed: [AlienStoragePage] = [
      .init(
        version: 1, owner: AlienStorageTestFixture.uuid(999), index: .sources,
        height: 0, entries: [entry], children: []),
      .init(
        version: 1, owner: snapshot.owner, index: .sources,
        height: 0, entries: [entry, entry], children: []),
      .init(
        version: 1, owner: snapshot.owner, index: .sources,
        height: 0,
        entries: [.init(key: AlienStorageTestFixture.uuid(999).uuidString, payload: entry.payload)],
        children: []),
      .init(
        version: 1, owner: snapshot.owner, index: .attachments,
        height: 0, entries: [entry], children: []),
    ]
    for invalid in malformed {
      let data = try AlienStoragePageCodec.canonical(invalid)
      let invalidHash = ScriptPackLibrary.hash(data)
      var reader = pages
      reader.pages[invalidHash] = data
      let tree = AlienStorageTree(
        hash: invalidHash, count: UInt64(invalid.entries.count), height: 0,
        firstKey: invalid.entries.first?.key, lastKey: invalid.entries.last?.key)
      let changed = AlienStorageRoot(
        version: 1, owner: root.owner, revision: root.revision,
        worldRevision: root.worldRevision,
        indices: root.indices.map {
          $0.index == .sources ? .init(index: .sources, tree: tree) : $0
        })
      let changedBytes = try AlienStoragePageCodec.canonical(changed)
      let reference = AlienStorageReference(
        owner: root.owner, revision: root.revision,
        worldRevision: root.worldRevision, rootHash: ScriptPackLibrary.hash(changedBytes))
      #expect(throws: (any Error).self) {
        try AlienStoragePageCodec.decode(
          reference: reference, expectedOwner: root.owner,
          rootData: changedBytes, from: reader)
      }
    }
  }

  @Test func unknownAndDuplicateRootKeysCannotHideBehindValidHash() throws {
    let snapshot = AlienStorageSnapshot(
      owner: AlienStorageTestFixture.owner, revision: 0,
      worldRevision: 0, world: [], sources: [], attachments: [], upgrades: [], receipts: [],
      commands: [])
    var pages = AlienStorageMemoryPages()
    let archive = try AlienStoragePageCodec.encode(snapshot: snapshot, previous: nil, into: &pages)
    let original = try #require(String(data: archive.rootData, encoding: .utf8))
    for prefix in ["\"extra\":1,", "\"version\":1,"] {
      let bytes = Data(("{" + prefix + String(original.dropFirst())).utf8)
      let reference = AlienStorageReference(
        owner: snapshot.owner, revision: 0, worldRevision: 0,
        rootHash: ScriptPackLibrary.hash(bytes))
      #expect(throws: (any Error).self) {
        try AlienStoragePageCodec.decode(
          reference: reference, expectedOwner: snapshot.owner,
          rootData: bytes, from: pages)
      }
    }
  }
}
