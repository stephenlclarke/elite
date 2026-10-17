import Foundation
import Testing

@testable import EliteCore

struct AlienStoragePageTests {
  @Test func pagedTransferRetirementAndUnappliedUpgradesRoundTrip() throws {
    var fixture = AlienStorageTestFixture()
    for index in 0..<300 {
      let id = try fixture.acquire(
        kind: AlienModuleKind.allCases[index % AlienModuleKind.allCases.count])
      try fixture.fit(id)
    }
    let before = fixture.snapshot
    fixture.transfer(to: AlienStorageTestFixture.uuid(90000))
    let upgrade = try fixture.acquire(kind: AlienModuleKind.allCases[0], upgrade: true)
    try fixture.retire(fixture.attachments[0].id)
    let snapshot = fixture.snapshot
    var pages = AlienStorageMemoryPages()
    let archive = try AlienStoragePageCodec.encode(
      snapshot: snapshot, previous: before, into: &pages)
    let restored = try AlienStoragePageCodec.decode(
      reference: archive.reference,
      expectedOwner: snapshot.owner, rootData: archive.rootData, from: pages)
    #expect(restored == snapshot)
    #expect(restored.receipts.count == 300)
    #expect(restored.upgrades.first(where: { $0.id == upgrade })?.disposition == .stored)
    #expect(restored.sources.count == 301)
    #expect(pages.pages.count > 6)
    #expect(pages.pages.values.allSatisfy { $0.count <= AlienStoragePageCodec.maximumPageBytes })
    let root = try JSONDecoder().decode(AlienStorageRoot.self, from: archive.rootData)
    #expect(root.indices.count == 6)
    #expect(root.indices.contains { $0.tree.height > 0 })
    let reversed = AlienStorageSnapshot(
      owner: snapshot.owner, revision: snapshot.revision,
      worldRevision: snapshot.worldRevision, world: snapshot.world.reversed(),
      sources: snapshot.sources.reversed(),
      attachments: snapshot.attachments.reversed(), upgrades: snapshot.upgrades.reversed(),
      receipts: snapshot.receipts.reversed(), commands: snapshot.commands.reversed())
    var reorderedPages = AlienStorageMemoryPages()
    let reordered = try AlienStoragePageCodec.encode(
      snapshot: reversed, previous: snapshot, into: &reorderedPages)
    #expect(reversed == snapshot)
    #expect(reordered.rootData == archive.rootData)
    #expect(reorderedPages.pages == pages.pages)
  }

  @Test func upgradeHistoryExceedsOldCollectionAndSaveGatesWithoutGrowingRecords() throws {
    var fixture = AlienStorageTestFixture()
    let kind = AlienModuleKind.allCases[0]
    let physical = try fixture.acquire(kind: kind)
    for _ in 0..<16385 {
      let upgrade = try fixture.acquire(kind: kind, upgrade: true)
      try fixture.apply(upgrade, to: physical)
    }
    let snapshot = fixture.snapshot
    var pages = AlienStorageMemoryPages()
    let archive = try AlienStoragePageCodec.encode(snapshot: snapshot, previous: nil, into: &pages)
    let restored = try AlienStoragePageCodec.decode(
      reference: archive.reference,
      expectedOwner: snapshot.owner, rootData: archive.rootData, from: pages)
    #expect(restored == snapshot)
    #expect(restored.receipts.count == 16385)
    #expect(restored.upgrades.count == 16385)
    #expect(restored.attachments.count == 1)
    #expect(pages.pages.values.reduce(0) { $0 + $1.count } > 4 * 1024 * 1024)
    #expect(archive.rootData.count < AlienStoragePageCodec.maximumRootBytes)
    #expect(try AlienStoragePageCodec.canonical(archive.reference).count < 512)
    let root = try JSONDecoder().decode(AlienStorageRoot.self, from: archive.rootData)
    #expect(root.indices.contains { $0.tree.height >= 2 })
    for data in pages.pages.values {
      #expect(data.count <= AlienStoragePageCodec.maximumPageBytes)
      let page = try JSONDecoder().decode(AlienStoragePage.self, from: data)
      #expect(page.entries.count <= AlienStoragePageCodec.maximumEntries)
      #expect(page.children.count <= AlienStoragePageCodec.maximumEntries)
    }
  }

  @Test func missingCorruptWrongOwnerAndMalformedRootsAreRejected() throws {
    var fixture = AlienStorageTestFixture()
    _ = try fixture.acquire(kind: AlienModuleKind.allCases[0])
    let snapshot = fixture.snapshot
    var pages = AlienStorageMemoryPages()
    let archive = try AlienStoragePageCodec.encode(snapshot: snapshot, previous: nil, into: &pages)
    #expect(throws: (any Error).self) {
      try AlienStoragePageCodec.decode(
        reference: archive.reference,
        expectedOwner: AlienStorageTestFixture.uuid(999), rootData: archive.rootData, from: pages)
    }
    var missing = pages
    let hash = try #require(pages.pages.keys.first)
    missing.pages[hash] = nil
    #expect(throws: (any Error).self) {
      try AlienStoragePageCodec.decode(
        reference: archive.reference,
        expectedOwner: snapshot.owner, rootData: archive.rootData, from: missing)
    }
    var corrupt = pages
    corrupt.pages[hash] = Data("{}".utf8)
    #expect(throws: (any Error).self) {
      try AlienStoragePageCodec.decode(
        reference: archive.reference,
        expectedOwner: snapshot.owner, rootData: archive.rootData, from: corrupt)
    }
    let original = try JSONDecoder().decode(AlienStorageRoot.self, from: archive.rootData)
    let malformed = AlienStorageRoot(
      version: 1, owner: snapshot.owner, revision: snapshot.revision,
      worldRevision: snapshot.worldRevision, indices: Array(original.indices.reversed()))
    let bytes = try AlienStoragePageCodec.canonical(malformed)
    let reference = AlienStorageReference(
      owner: snapshot.owner, revision: snapshot.revision,
      worldRevision: snapshot.worldRevision, rootHash: ScriptPackLibrary.hash(bytes))
    #expect(throws: (any Error).self) {
      try AlienStoragePageCodec.decode(
        reference: reference, expectedOwner: snapshot.owner,
        rootData: bytes, from: pages)
    }
  }

  @Test func failureAtEveryPageWriteKeepsPreviousArchiveReadable() throws {
    var fixture = AlienStorageTestFixture()
    _ = try fixture.acquire(kind: AlienModuleKind.allCases[0])
    let before = fixture.snapshot
    var original = AlienStorageMemoryPages()
    let archive = try AlienStoragePageCodec.encode(snapshot: before, previous: nil, into: &original)
    for _ in 0..<150 { _ = try fixture.acquire(kind: AlienModuleKind.allCases[0]) }
    let next = fixture.snapshot
    var complete = AlienStorageMemoryPages()
    _ = try AlienStoragePageCodec.encode(snapshot: next, previous: before, into: &complete)
    for failure in 1...complete.writes {
      var interrupted = original
      interrupted.writes = 0
      interrupted.failAtWrite = failure
      #expect(throws: (any Error).self) {
        try AlienStoragePageCodec.encode(snapshot: next, previous: before, into: &interrupted)
      }
      let restored = try AlienStoragePageCodec.decode(
        reference: archive.reference,
        expectedOwner: before.owner, rootData: archive.rootData, from: interrupted)
      #expect(restored == before)
    }
  }

  @Test func nativePageStoreIsImmutableAndRefusesSymbolicLinks() throws {
    let directory = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
      .appendingPathComponent("alien-storage-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    var fixture = AlienStorageTestFixture()
    for _ in 0..<130 { _ = try fixture.acquire(kind: AlienModuleKind.allCases[0]) }
    let snapshot = fixture.snapshot
    let reference = try AlienStoragePageStore.write(
      snapshot: snapshot, previous: nil, to: directory)
    let restored = try AlienStoragePageStore.read(
      reference: reference, expectedOwner: snapshot.owner, from: directory)
    #expect(restored == snapshot)
    let retry = try AlienStoragePageStore.write(
      snapshot: snapshot, previous: snapshot, to: directory)
    #expect(retry == reference)
    _ = try fixture.acquire(kind: AlienModuleKind.allCases[0])
    #expect(throws: (any Error).self) {
      try AlienStoragePageStore.write(snapshot: fixture.snapshot, previous: snapshot, to: directory)
    }
    let retained = try AlienStoragePageStore.read(
      reference: reference, expectedOwner: snapshot.owner, from: directory)
    #expect(retained == snapshot)
    let rootURL = directory.appendingPathComponent("alien-root.json")
    let moved = directory.appendingPathComponent("original-root.json")
    try FileManager.default.moveItem(at: rootURL, to: moved)
    try FileManager.default.createSymbolicLink(at: rootURL, withDestinationURL: moved)
    #expect(throws: (any Error).self) {
      try AlienStoragePageStore.read(
        reference: reference, expectedOwner: snapshot.owner, from: directory)
    }
    let linkedDirectory = directory.appendingPathComponent("linked-pages")
    try FileManager.default.moveItem(
      at: directory.appendingPathComponent("alien-pages"), to: linkedDirectory)
    try FileManager.default.createSymbolicLink(
      at: directory.appendingPathComponent("alien-pages"), withDestinationURL: linkedDirectory)
    let store = try AlienStoragePageStore(directory: directory)
    let hash = String(repeating: "a", count: 64)
    #expect(throws: (any Error).self) { try store.readPage(hash: hash) }
  }
}
