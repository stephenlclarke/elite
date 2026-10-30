import Foundation

public struct ScriptBookChapter: Codable, Sendable, Equatable {
  public let id: String
  public let title: String
  public let text: String
  public let level: Int
  var valid: Bool {
    PackValidation.localID(id) && (1...96).contains(title.count)
      && (1...12000).contains(text.utf8.count) && (0...4).contains(level)
  }
}
public struct ScriptBookDefinition: Codable, Sendable, Equatable {
  public let id: String
  public let title: String
  public let chapters: [ScriptBookChapter]
  var valid: Bool {
    PackValidation.localID(id) && (1...96).contains(title.count)
      && (1...64).contains(chapters.count) && Set(chapters.map(\.id)).count == chapters.count
      && chapters.allSatisfy(\.valid)
      && chapters.reduce(0, { $0 + $1.text.utf8.count }) <= 131072
  }
}

/// Immutable retained text. Constructor/decoder validates the content hash once, not every frame.
public struct ScriptBookRecord: Codable, Sendable, Equatable {
  public let provider: String
  public let version: String
  public let digest: String
  public let book: ScriptBookDefinition
  public let source: String
  public let license: String
  public let instance: UUID
  public let sequence: UInt64
  public let revision: UInt64
  public let causeKind: String
  public let cause: ScriptEventContext
  public let committed: ScriptEventContext
  public let contentHash: String
  public var key: String { provider + "/" + book.id }

  private enum CodingKeys: String, CodingKey {
    case provider, version, digest, book, source, license, instance, sequence, revision, causeKind,
      cause,
      committed, contentHash
  }
  static func hash(_ book: ScriptBookDefinition) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return ScriptPackLibrary.hash(try encoder.encode(book))
  }
  private init(
    provider: String, version: String, digest: String, book: ScriptBookDefinition,
    source: String, license: String, instance: UUID, sequence: UInt64, revision: UInt64,
    causeKind: String, cause: ScriptEventContext, committed: ScriptEventContext, contentHash: String
  ) throws {
    guard PackValidation.identifier(provider), PackValidation.version(version),
      ScriptCompletionReceipt.validDigest(digest), book.valid,
      (1...12000).contains(source.utf8.count), (1...12000).contains(license.utf8.count),
      sequence > 0, sequence < UInt64(Int64.max), revision > 0,
      revision < UInt64(Int64.max), ScriptCapabilities.events.contains(causeKind), cause.valid,
      committed.valid,
      cause.revision < revision, committed.revision == revision,
      cause.localSeconds <= committed.localSeconds,
      cause.flightSeconds <= committed.flightSeconds,
      cause.calendarSeconds <= committed.calendarSeconds,
      cause.transitSeconds <= committed.transitSeconds,
      try Self.hash(book) == contentHash
    else { throw MissionPackError("Invalid retained reference book or provenance.") }
    self.provider = provider
    self.version = version
    self.digest = digest
    self.book = book
    self.source = source
    self.license = license
    self.instance = instance
    self.sequence = sequence
    self.revision = revision
    self.causeKind = causeKind
    self.cause = cause
    self.committed = committed
    self.contentHash = contentHash
  }
  init(
    pack: ScriptPack, book: ScriptBookDefinition, state: ScriptInstance,
    event: ScriptEvent, committed: ScriptEventContext
  ) throws {
    guard let cause = event.context else {
      throw MissionPackError("Reference books require their original native acquisition fact.")
    }
    try self.init(
      provider: pack.manifest.id, version: pack.manifest.version, digest: pack.digest,
      book: book, source: pack.manifest.source, license: pack.manifest.license,
      instance: state.id, sequence: event.sequence, revision: committed.revision,
      causeKind: event.kind, cause: cause, committed: committed, contentHash: Self.hash(book))
  }
  public init(from decoder: any Decoder) throws {
    let fields = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      provider: fields.decode(String.self, forKey: .provider),
      version: fields.decode(String.self, forKey: .version),
      digest: fields.decode(String.self, forKey: .digest),
      book: fields.decode(ScriptBookDefinition.self, forKey: .book),
      source: fields.decode(String.self, forKey: .source),
      license: fields.decode(String.self, forKey: .license),
      instance: fields.decode(UUID.self, forKey: .instance),
      sequence: fields.decode(UInt64.self, forKey: .sequence),
      revision: fields.decode(UInt64.self, forKey: .revision),
      causeKind: fields.decode(String.self, forKey: .causeKind),
      cause: fields.decode(ScriptEventContext.self, forKey: .cause),
      committed: fields.decode(ScriptEventContext.self, forKey: .committed),
      contentHash: fields.decode(String.self, forKey: .contentHash))
  }
  var header: ScriptValue {
    .object([
      "key": .string(key), "title": .string(book.title), "provider": .string(provider),
      "version": .string(version), "digest": .string(digest),
      "chapters": .integer(Int64(book.chapters.count)),
    ])
  }
}

extension ScriptEngineState {
  public var books: [String: ScriptBookRecord] {
    get { savedBooks ?? [:] }
    set { savedBooks = newValue.isEmpty ? nil : newValue }
  }
  var booksValid: Bool {
    books.count <= 64
      && books.allSatisfy { key, value in
        guard key == value.key, let origin = instances[value.instance] else { return false }
        return origin.definition.hasPrefix(value.provider + "/")
          && origin.version == value.version && origin.digest == value.digest
          && origin.hasAcknowledged(value.sequence) && value.sequence <= nextEvent
          && value.revision <= origin.revision
          && value.committed.localSeconds <= localSeconds
          && value.committed.flightSeconds <= flightSeconds
          && value.committed.calendarSeconds <= calendarSeconds
          && value.committed.transitSeconds <= transitSeconds
      }
  }
}

extension Game {
  public var referenceBooks: [ScriptBookRecord] {
    commander.scriptState.books.values.sorted { $0.key < $1.key }
  }
  mutating func unlockScriptBook(
    _ command: ScriptValue, pack: ScriptPack, state: ScriptInstance, event: ScriptEvent
  ) throws -> (String, [String: ScriptValue])? {
    guard let fields = command.object, Set(fields.keys) == ["op", "id"],
      let id = command["id"]?.string,
      pack.manifest.capabilities.contains("library-books-basic-v2"), state.outcome == .active,
      let book = pack.manifest.books?.first(where: { $0.id == id })
    else { throw MissionPackError("Reference book requests require a declared owned book.") }
    let key = pack.manifest.id + "/" + id
    if let existing = commander.scriptState.books[key] {
      guard existing.version == pack.manifest.version, existing.digest == pack.digest,
        try existing.contentHash == ScriptBookRecord.hash(book)
      else { throw MissionPackError("This reference book requires an explicit content migration.") }
      return nil
    }
    guard commander.scriptState.books.count < 64 else {
      throw MissionPackError("Reference library capacity reached; book was not granted.")
    }
    var committed = state
    committed.revision += 1
    let record = try ScriptBookRecord(
      pack: pack, book: book, state: state, event: event,
      committed: scriptEventContext(committed))
    commander.scriptState.books[key] = record
    return ("book.unlocked", ["book_key": .string(key), "book_id": .string(id)])
  }
}

extension ScriptPackLibrary {
  static func validateBooks(_ manifest: ScriptManifest) throws {
    let books = manifest.books ?? []
    guard books.count <= 32, Set(books.map(\.id)).count == books.count,
      books.allSatisfy(\.valid),
      Set(manifest.mission.requiredBooks ?? []).count
        == (manifest.mission.requiredBooks?.count ?? 0),
      Set(manifest.mission.requiredBooks ?? []).isSubset(of: Set(books.map(\.id))),
      books.isEmpty
        || (manifest.capabilities.contains("library-books-basic-v2")
          && manifest.source.utf8.count <= 12000 && manifest.license.utf8.count <= 12000),
      !manifest.handlers.contains(where: { $0.event == "book.unlocked" })
        || manifest.capabilities.contains("library-books-basic-v2")
    else {
      throw MissionPackError("Invalid, duplicate or unsupported reference book declarations.")
    }
  }
}
