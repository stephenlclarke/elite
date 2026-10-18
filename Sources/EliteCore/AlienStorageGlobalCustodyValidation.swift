import Foundation

/// One complete mutation/load-boundary census, never a frame query. Independent
/// collection receipts cannot borrow another transaction ID or resurrect spent evidence.
enum AlienStorageGlobalCustodyValidation {
  static func validate(_ snapshot: AlienStorageSnapshot) throws {
    var reserved = Set(snapshot.commands.map(\.id))
    var settled: Set<SalvageLotIdentity> = []
    var claims: [UUID: AlienStorageLegacyLot] = [:]
    for record in snapshot.world {
      switch record {
      case .legacySection(let section): reserved.insert(section.importOperation)
      case .legacySettlement(let header): reserved.insert(header.command)
      case .legacySettlementItem(let item):
        guard settled.insert(item.lot.identity).inserted else {
          throw AlienStorageError.duplicateKey
        }
      case .legacyLot(let claim):
        guard claims.updateValue(claim, forKey: claim.id) == nil else {
          throw AlienStorageError.duplicateKey
        }
      default: break
      }
    }
    var collections: Set<UUID> = []
    func collect(_ receipt: AlienStorageCompanionCollection) throws {
      guard !reserved.contains(receipt.operation), collections.insert(receipt.operation).inserted
      else { throw AlienStorageError.invalidJoin }
    }
    for source in snapshot.sources where settled.contains(source.lot.identity) {
      throw AlienStorageError.invalidJoin
    }
    for record in snapshot.world {
      switch record {
      case .plan(let plan):
        let emissions = try plan.progress.emissions(plan: plan)
        guard emissions.values.allSatisfy({ !settled.contains($0.identity) }) else {
          throw AlienStorageError.invalidJoin
        }
      case .lot(let lot):
        if case .pending(let item, _, _, _) = lot.state, settled.contains(item.identity) {
          throw AlienStorageError.invalidJoin
        }
      case .companion(let companion):
        if case .collected(let receipt) = companion.state { try collect(receipt) }
      case .legacyCurrent(let current):
        guard let claim = claims[current.claim], !settled.contains(claim.identity) else {
          throw AlienStorageError.invalidJoin
        }
        if case .collected(let receipt) = current.state { try collect(receipt) }
      case .legacyLot(let claim):
        if settled.contains(claim.identity) {
          guard case .legacySettled = claim.state else { throw AlienStorageError.invalidJoin }
          // The complete legacy validator authenticates its exact header/item reference.
        }
      default: break
      }
    }
  }
}
