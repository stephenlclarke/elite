import Foundation

protocol AlienStoragePageWriter {
  mutating func writePage(hash: String, data: Data) throws
}
protocol AlienStoragePageReader {
  func readPage(hash: String) throws -> Data
}
struct AlienStorageReference: Codable, Sendable, Equatable {
  let owner: UUID
  let revision: UInt64
  let worldRevision: UInt64
  let rootHash: String
}
struct AlienStorageArchive: Sendable {
  let reference: AlienStorageReference
  let rootData: Data
}
enum AlienStorageIndex: String, Codable, CaseIterable, Sendable {
  case sources, attachments, upgrades, receipts, commands, world
}
enum AlienStoragePayload: Codable, Sendable {
  case source(AlienStorageSource)
  case attachment(AlienStorageAttachment)
  case upgrade(AlienStorageUpgrade)
  case receipt(AlienStorageReceipt)
  case command(AlienStorageCommand)
  case world(AlienStorageWorldRecord)
  var id: UUID {
    switch self {
    case .source(let value): value.id
    case .attachment(let value): value.id
    case .upgrade(let value): value.id
    case .receipt(let value): value.id
    case .command(let value): value.id
    case .world(let value): value.id
    }
  }
  var index: AlienStorageIndex {
    switch self {
    case .source: .sources
    case .attachment: .attachments
    case .upgrade: .upgrades
    case .receipt: .receipts
    case .command: .commands
    case .world: .world
    }
  }
}
struct AlienStorageEntry: Codable, Sendable {
  let key: String
  let payload: AlienStoragePayload
}
struct AlienStorageTree: Codable, Sendable, Equatable {
  let hash: String?
  let count: UInt64
  let height: UInt64
  let firstKey: String?
  let lastKey: String?
  static let empty = Self(hash: nil, count: 0, height: 0, firstKey: nil, lastKey: nil)
}
struct AlienStorageIndexRoot: Codable, Sendable {
  let index: AlienStorageIndex
  let tree: AlienStorageTree
}
struct AlienStorageRoot: Codable, Sendable {
  let version: Int
  let owner: UUID
  let revision: UInt64
  let worldRevision: UInt64
  let indices: [AlienStorageIndexRoot]
}
struct AlienStoragePage: Codable, Sendable {
  let version: Int
  let owner: UUID
  let index: AlienStorageIndex
  let height: UInt64
  let entries: [AlienStorageEntry]
  let children: [AlienStorageTree]
}

/// Page limits bound one allocation/parser unit, never lifetime records or tree depth.
enum AlienStoragePageCodec {
  static let maximumPageBytes = 262_144
  static let maximumRootBytes = 16_384
  static let maximumEntries = 128

  static func encode<W: AlienStoragePageWriter>(
    snapshot: AlienStorageSnapshot,
    previous: AlienStorageSnapshot?, into writer: inout W
  ) throws -> AlienStorageArchive {
    try snapshot.validateTransition(from: previous)
    var roots: [AlienStorageIndexRoot] = []
    for index in AlienStorageIndex.allCases {
      let entries = payloads(snapshot, index: index).map {
        AlienStorageEntry(key: $0.id.uuidString, payload: $0)
      }
      .sorted { $0.key < $1.key }
      var leaves: [AlienStorageTree] = []
      var offset = 0
      while offset < entries.count {
        let end = offset + min(maximumEntries, entries.count - offset)
        var pending = [Array(entries[offset..<end])]
        while let chunk = pending.popLast() {
          let page = AlienStoragePage(
            version: 1, owner: snapshot.owner, index: index,
            height: 0, entries: chunk, children: [])
          let data = try canonical(page)
          if data.count > maximumPageBytes {
            guard chunk.count > 1 else { throw AlienStorageError.oversizedRecord }
            let middle = chunk.count / 2
            pending.append(Array(chunk[middle...]))
            pending.append(Array(chunk[..<middle]))
            continue
          }
          let hash = ScriptPackLibrary.hash(data)
          try writer.writePage(hash: hash, data: data)
          leaves.append(
            .init(
              hash: hash, count: UInt64(chunk.count), height: 0,
              firstKey: chunk.first?.key, lastKey: chunk.last?.key))
        }
        offset = end
      }
      var level = leaves
      while level.count > 1 {
        // Balanced groups avoid singleton branch nodes at a page boundary.
        let groups = level.count / maximumEntries + (level.count % maximumEntries == 0 ? 0 : 1)
        let size = level.count / groups
        let extra = level.count % groups
        var next: [AlienStorageTree] = []
        var start = 0
        for group in 0..<groups {
          let end = start + size + (group < extra ? 1 : 0)
          let children = Array(level[start..<end])
          let increment = children[0].height.addingReportingOverflow(1)
          guard !increment.overflow else { throw AlienStorageError.arithmeticOverflow }
          let page = AlienStoragePage(
            version: 1, owner: snapshot.owner, index: index,
            height: increment.partialValue, entries: [], children: children)
          let data = try canonical(page)
          guard data.count <= maximumPageBytes else { throw AlienStorageError.oversizedRecord }
          let hash = ScriptPackLibrary.hash(data)
          try writer.writePage(hash: hash, data: data)
          next.append(
            .init(
              hash: hash, count: try total(children), height: page.height,
              firstKey: children.first?.firstKey, lastKey: children.last?.lastKey))
          start = end
        }
        level = next
      }
      roots.append(.init(index: index, tree: level.first ?? .empty))
    }
    let root = AlienStorageRoot(
      version: 1, owner: snapshot.owner, revision: snapshot.revision,
      worldRevision: snapshot.worldRevision, indices: roots)
    let bytes = try canonical(root)
    guard bytes.count <= maximumRootBytes else { throw AlienStorageError.invalidReference }
    return .init(
      reference: .init(
        owner: snapshot.owner, revision: snapshot.revision,
        worldRevision: snapshot.worldRevision, rootHash: ScriptPackLibrary.hash(bytes)),
      rootData: bytes)
  }

  static func decode<R: AlienStoragePageReader>(
    reference: AlienStorageReference, expectedOwner: UUID,
    rootData: Data, from reader: R
  ) throws -> AlienStorageSnapshot {
    guard reference.owner == expectedOwner else { throw AlienStorageError.wrongOwner }
    guard validHash(reference.rootHash), rootData.count <= maximumRootBytes else {
      throw AlienStorageError.invalidReference
    }
    guard ScriptPackLibrary.hash(rootData) == reference.rootHash else {
      throw AlienStorageError.hashMismatch
    }
    let root: AlienStorageRoot = try decoded(rootData)
    guard root.version == 1, root.owner == expectedOwner, root.revision == reference.revision,
      root.worldRevision == reference.worldRevision,
      root.indices.map(\.index) == AlienStorageIndex.allCases
    else { throw AlienStorageError.invalidReference }
    var visited: Set<String> = []
    var values: [AlienStoragePayload] = []
    for index in root.indices {
      try validate(index.tree)
      if index.tree.count == 0 { continue }
      var pending = [index.tree]
      var lastKey: String?
      var count: UInt64 = 0
      while let tree = pending.popLast() {
        try validate(tree)
        guard let hash = tree.hash, visited.insert(hash).inserted else {
          throw AlienStorageError.aliasedPage
        }
        let bytes = try reader.readPage(hash: hash)
        guard bytes.count <= maximumPageBytes else { throw AlienStorageError.invalidPage }
        guard ScriptPackLibrary.hash(bytes) == hash else { throw AlienStorageError.hashMismatch }
        let page: AlienStoragePage = try decoded(bytes)
        guard page.version == 1, page.owner == expectedOwner, page.index == index.index,
          page.height == tree.height
        else { throw AlienStorageError.invalidPage }
        if tree.height == 0 {
          guard page.children.isEmpty, !page.entries.isEmpty, page.entries.count <= maximumEntries,
            UInt64(page.entries.count) == tree.count, page.entries.first?.key == tree.firstKey,
            page.entries.last?.key == tree.lastKey
          else { throw AlienStorageError.invalidPage }
          for entry in page.entries {
            guard entry.key == entry.payload.id.uuidString, entry.payload.index == index.index,
              lastKey.map({ $0 < entry.key }) ?? true
            else { throw AlienStorageError.duplicateKey }
            lastKey = entry.key
            let next = count.addingReportingOverflow(1)
            guard !next.overflow else { throw AlienStorageError.arithmeticOverflow }
            count = next.partialValue
            values.append(entry.payload)
          }
        } else {
          guard page.entries.isEmpty, (2...maximumEntries).contains(page.children.count),
            try total(page.children) == tree.count,
            page.children.first?.firstKey == tree.firstKey,
            page.children.last?.lastKey == tree.lastKey
          else { throw AlienStorageError.invalidPage }
          var prior: String?
          for child in page.children {
            try validate(child)
            guard child.count > 0, child.height == tree.height - 1,
              let first = child.firstKey, let last = child.lastKey,
              prior.map({ $0 < first }) ?? true
            else { throw AlienStorageError.invalidPage }
            prior = last
          }
          pending.append(contentsOf: page.children.reversed())
        }
      }
      guard count == index.tree.count else { throw AlienStorageError.invalidPage }
    }
    let snapshot = AlienStorageSnapshot(
      owner: expectedOwner, revision: root.revision,
      worldRevision: root.worldRevision,
      world: values.compactMap { if case .world(let value) = $0 { value } else { nil } },
      sources: values.compactMap { if case .source(let value) = $0 { value } else { nil } },
      attachments: values.compactMap { if case .attachment(let value) = $0 { value } else { nil } },
      upgrades: values.compactMap { if case .upgrade(let value) = $0 { value } else { nil } },
      receipts: values.compactMap { if case .receipt(let value) = $0 { value } else { nil } },
      commands: values.compactMap { if case .command(let value) = $0 { value } else { nil } })
    try snapshot.validate()
    return snapshot
  }

  static func validHash(_ value: String) -> Bool {
    value.utf8.count == 64
      && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
  }
  static func canonical<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(value)
  }
  private static func decoded<T: Codable>(_ data: Data) throws -> T {
    try ScriptSaveJSONPreflight.validate(data)
    let value = try JSONDecoder().decode(T.self, from: data)
    // Reject unknown/duplicate keys and noncanonical representations, not just bad hashes.
    guard try canonical(value) == data else { throw AlienStorageError.invalidPage }
    return value
  }
  private static func validate(_ tree: AlienStorageTree) throws {
    if tree.count == 0 {
      guard tree == .empty else { throw AlienStorageError.invalidReference }
      return
    }
    guard let hash = tree.hash, validHash(hash), tree.height < tree.count,
      let first = tree.firstKey, let last = tree.lastKey, first <= last,
      UUID(uuidString: first)?.uuidString == first, UUID(uuidString: last)?.uuidString == last
    else { throw AlienStorageError.invalidReference }
  }
  private static func total(_ children: [AlienStorageTree]) throws -> UInt64 {
    var count: UInt64 = 0
    for child in children {
      let next = count.addingReportingOverflow(child.count)
      guard !next.overflow else { throw AlienStorageError.arithmeticOverflow }
      count = next.partialValue
    }
    return count
  }
  private static func payloads(_ snapshot: AlienStorageSnapshot, index: AlienStorageIndex)
    -> [AlienStoragePayload]
  {
    switch index {
    case .sources: snapshot.sources.map(AlienStoragePayload.source)
    case .attachments: snapshot.attachments.map(AlienStoragePayload.attachment)
    case .upgrades: snapshot.upgrades.map(AlienStoragePayload.upgrade)
    case .receipts: snapshot.receipts.map(AlienStoragePayload.receipt)
    case .commands: snapshot.commands.map(AlienStoragePayload.command)
    case .world: snapshot.world.map(AlienStoragePayload.world)
    }
  }
}
