import Foundation

/// Current custody is separate from the immutable original import observation.
/// Import time is genuine current time; no original emission or scoop time is invented.
struct AlienStorageLegacyCurrent: Codable, Sendable, Equatable {
  enum State: Codable, Sendable, Equatable {
    case pending(lot: SalvageLot, at: Double, offer: SpawnIdentity?, binding: ActorIdentity?)
    case acquired(source: UUID, at: Double)
    case collected(AlienStorageCompanionCollection)
    case discarded(at: Double)
    case destroyed(at: Double)
  }
  let id: UUID
  let owner: UUID
  let claim: UUID
  let state: State

  func preserve(_ old: Self) throws {
    guard id == old.id, owner == old.owner, claim == old.claim else {
      throw AlienStorageError.historyChanged
    }
    switch (old.state, state) {
    case (.pending(let a, let time, _, _), .pending(let b, let nextTime, _, _)):
      guard a.identity == b.identity, a.content == b.content, a.loot == b.loot,
        a.halfExtents == b.halfExtents, a.massKg == b.massKg, nextTime >= time
      else { throw AlienStorageError.historyChanged }
    case (.pending(_, let time, _, _), .acquired(_, let at)),
      (.pending(_, let time, _, _), .discarded(let at)),
      (.pending(_, let time, _, _), .destroyed(let at)):
      guard at >= time else { throw AlienStorageError.historyChanged }
    case (.pending(_, let time, _, _), .collected(let receipt)):
      guard receipt.at >= time else { throw AlienStorageError.historyChanged }
    default:
      guard self == old else { throw AlienStorageError.historyChanged }
    }
  }
}
