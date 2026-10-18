import Foundation

/// Permanent zero-mass record of the first verified success for one approved source.
struct ScriptClueAward: Codable, Sendable, Equatable {
  let sourceID: String
  let clueID: String
  let receiptID: String
  let completion: ScriptCompletionReceipt
}

struct ScriptClueJournal: Codable, Sendable, Equatable {
  let owner: UUID
  private(set) var awards: [String: ScriptClueAward] = [:]

  func valid(engine: ScriptEngineState) -> Bool {
    !awards.isEmpty && awards.count <= ScriptBaseClueCatalog.sources.count
      && Set(awards.values.map(\.clueID)).count == awards.count
      && awards.allSatisfy { key, award in
        guard key == award.sourceID,
          let source = ScriptBaseClueCatalog.bySource[key], source.clueID == award.clueID,
          source.receiptID == award.receiptID, award.completion.outcome == .complete,
          award.completion.cause != nil,
          let instance = engine.instances[award.completion.instance],
          instance.completionReceipt == award.completion
        else { return false }
        return award.completion.valid(for: instance, engine: engine)
      }
  }

  mutating func record(_ receipt: ScriptCompletionReceipt, source: ScriptBaseClueSource) {
    guard awards[source.sourceID] == nil else { return }
    awards[source.sourceID] = .init(
      sourceID: source.sourceID, clueID: source.clueID, receiptID: source.receiptID,
      completion: receipt)
  }

  var progress: ScriptClueProgress {
    let collected = Set(awards.values.map(\.clueID))
    return .init(
      collectedClueIDs: collected.sorted(),
      missingClueIDs: ScriptBaseClueCatalog.requiredClueIDs.subtracting(collected).sorted(),
      complete: ScriptBaseClueCatalog.requiredClueIDs.isSubset(of: collected))
  }
}

public struct ScriptClueProgress: Sendable, Equatable {
  public let collectedClueIDs: [String]
  public let missingClueIDs: [String]
  public let complete: Bool

  static let empty = ScriptClueProgress(
    collectedClueIDs: [], missingClueIDs: ScriptBaseClueCatalog.requiredClueIDs.sorted(),
    complete: false)
}

extension Game {
  /// Called only inside the existing protected terminal candidate, before publication.
  mutating func awardScriptClue(
    previous: ScriptInstance, next: ScriptInstance, trust: ScriptClueTrustCatalog
  ) throws {
    guard previous.outcome == .active, next.outcome == .complete,
      let receipt = next.completionReceipt, let pin = trust.pin(for: receipt)
    else { return }
    guard let owner = commander.equipmentOwnerID, receipt.cause != nil,
      receipt.valid(for: next, engine: commander.scriptState),
      let source = ScriptBaseClueCatalog.bySource[pin.sourceID]
    else { throw SaveError.invalidCommander }
    var journal = commander.scriptState.savedClueJournal ?? .init(owner: owner)
    guard journal.owner == owner else { throw SaveError.invalidCommander }
    journal.record(receipt, source: source)
    commander.scriptState.savedClueJournal = journal
  }
}

extension GameRuntime {
  /// A snapshot only: never scans old completions or creates awards.
  public func baseClueProgress() -> ScriptClueProgress {
    guard ScriptClueVersionedSave.validateClaims(game.commander, trust: .production) else {
      return .empty
    }
    return game.commander.scriptState.savedClueJournal?.progress ?? .empty
  }
}
