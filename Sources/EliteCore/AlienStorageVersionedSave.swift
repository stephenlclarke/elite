import Foundation

enum AlienStorageVersionedSave {
  static let rootName = "alien-root.json"
  private static let runtimeFields: Set<String> = [
    "alienStorageState", "alienStorageCache", "savedAlienStorageState",
  ]

  static func rejectFields(_ bytes: Data) throws {
    let keys = try headerKeys(bytes)
    guard !keys.contains("savedAlienStorageReference"), keys.isDisjoint(with: runtimeFields) else {
      throw SaveError.invalidCommander
    }
  }

  static func validateHeader(_ bytes: Data, schema: Int) throws {
    guard schema >= 27 else {
      try rejectFields(bytes)
      return
    }
    let keys = try headerKeys(bytes)
    guard keys.contains("savedAlienStorageReference"), keys.isDisjoint(with: runtimeFields) else {
      throw SaveError.invalidCommander
    }
  }

  private static func headerKeys(_ bytes: Data) throws -> Set<String> {
    guard let header = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else {
      throw SaveError.invalidCommander
    }
    return Set(header.keys)
  }

  /// Pages and the constant-size root are durable before any pointer can name them.
  static func stage(_ commander: Commander, in directory: URL) throws -> AlienStoragePublication? {
    guard commander.usesAlienStorageSaveVersion else { return nil }
    guard commander.alienStorageStateValid, let state = commander.alienStorageState else {
      throw SaveError.invalidCommander
    }
    let reference = try AlienStoragePageStore.write(
      snapshot: state.current.snapshot, previous: state.durable?.snapshot, to: directory)
    return .init(before: state, after: try state.published(reference: reference))
  }

  /// The header reference and fixed pointer hash must authenticate the same root.
  static func hydrate(
    _ commander: inout Commander, rootHash: String, directory: URL
  ) throws {
    guard commander.alienStorageState == nil,
      let reference = commander.savedAlienStorageReference,
      let owner = commander.equipmentOwnerID, reference.owner == owner,
      reference.rootHash == rootHash
    else { throw SaveError.invalidCommander }
    let snapshot = try AlienStoragePageStore.read(
      reference: reference, expectedOwner: owner, from: directory)
    commander.alienStorageState = try .hydrated(snapshot, reference: reference)
  }
}
