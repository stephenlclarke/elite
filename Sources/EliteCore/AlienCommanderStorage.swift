import Foundation

/// Immutable native state, excluded from Commander JSON. Validation and history
/// replay occur at mutation/load boundaries; frame queries read the held witness.
final class AlienCommanderStorage: Sendable, Equatable {
  let current: AlienStorageValidatedState
  let durable: AlienStorageValidatedState?
  let reference: AlienStorageReference?

  private init(
    current: AlienStorageValidatedState, durable: AlienStorageValidatedState?,
    reference: AlienStorageReference?
  ) {
    self.current = current
    self.durable = durable
    self.reference = reference
  }

  static func changing(
    to snapshot: AlienStorageSnapshot, from previous: AlienCommanderStorage?
  ) throws -> AlienCommanderStorage {
    try snapshot.validateTransition(from: previous?.current.snapshot)
    return .init(
      current: try .init(validating: snapshot), durable: previous?.durable,
      reference: previous?.reference)
  }

  static func hydrated(
    _ snapshot: AlienStorageSnapshot, reference: AlienStorageReference
  ) throws -> AlienCommanderStorage {
    let validated = try AlienStorageValidatedState(validating: snapshot)
    guard matches(reference, validated) else { throw AlienStorageError.invalidReference }
    return .init(current: validated, durable: validated, reference: reference)
  }

  func published(reference: AlienStorageReference) throws -> AlienCommanderStorage {
    guard Self.matches(reference, current) else { throw AlienStorageError.invalidReference }
    return .init(current: current, durable: current, reference: reference)
  }

  private static func matches(
    _ reference: AlienStorageReference, _ state: AlienStorageValidatedState
  ) -> Bool {
    reference.owner == state.owner && reference.revision == state.revision
      && reference.worldRevision == state.worldRevision
      && AlienStoragePageCodec.validHash(reference.rootHash)
  }

  static func == (lhs: AlienCommanderStorage, rhs: AlienCommanderStorage) -> Bool {
    lhs.current == rhs.current && lhs.durable == rhs.durable && lhs.reference == rhs.reference
  }
}

/// Returned by the save owner only after the complete generation pointer is published.
struct AlienStoragePublication: Sendable {
  let before: AlienCommanderStorage
  let after: AlienCommanderStorage
}

extension Commander {
  var usesAlienStorageSaveVersion: Bool {
    savedAlienStorageReference != nil || alienStorageState != nil
  }

  /// Constructors validate the complete history; this check never replays it in a frame.
  var alienStorageStateValid: Bool {
    guard let state = alienStorageState else {
      return savedAlienStorageReference == nil
        && salvageLedger.nativeTransferredSectionIdentities.isEmpty
    }
    return state.current.owner == equipmentOwnerID && state.reference == savedAlienStorageReference
      && state.current.transferredSections == salvageLedger.nativeTransferredSectionIdentities
  }

  /// Only native actor transaction producers call this after resolving physical authority.
  /// A structurally valid snapshot alone does not confer scoop or station permissions.
  mutating func replaceAlienStorage(with snapshot: AlienStorageSnapshot) throws {
    guard alienStorageStateValid, snapshot.owner == equipmentOwnerID else {
      throw AlienStorageError.wrongOwner
    }
    let next = try AlienCommanderStorage.changing(to: snapshot, from: alienStorageState)
    alienStorageState = next
  }

  /// There is no suspension or proposal callback between writing and this assignment.
  /// All fallible validation precedes the pointer publication in ScriptSaveStore.
  mutating func publishAlienStorage(_ publication: AlienStoragePublication?) {
    guard let publication else { return }
    precondition(
      alienStorageState == publication.before
        && savedAlienStorageReference == publication.before.reference
        && equipmentOwnerID == publication.after.current.owner)
    savedAlienStorageReference = publication.after.reference
    alienStorageState = publication.after
  }
}
