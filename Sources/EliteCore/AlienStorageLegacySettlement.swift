import Foundation

/// Store original proposal metadata once, shared by every affected imported section.
/// No historical transaction time exists in the old proposal.
struct AlienStorageLegacySettlement: Codable, Sendable, Equatable {
  let id: UUID
  let owner: UUID
  let command: UUID
  let revision: UInt64
  let action: SalvageDefinitionAction
  let saleValueTenths: Int
  let binding: SalvageTransactionBinding?
  let itemCount: UInt16
}

/// One original item per record avoids embedding up to 128 lots in each emission claim.
struct AlienStorageLegacySettlementItem: Codable, Sendable, Equatable {
  let id: UUID
  let owner: UUID
  let settlement: UUID
  let ordinal: UInt16
  let lot: SalvageLot
}

/// Whole-owner normalized audit values; this container is not a saved lifetime blob.
struct AlienStorageLegacySettlements: Sendable, Equatable {
  let headers: [AlienStorageLegacySettlement]
  let items: [AlienStorageLegacySettlementItem]

  /// Reconstruct ordered values only; authenticity requires the real sealed export join.
  func proposal(for header: AlienStorageLegacySettlement) throws -> SalvageSettlementProposal {
    let members = items.filter { $0.settlement == header.id }.sorted { $0.ordinal < $1.ordinal }
    guard headers.filter({ $0.id == header.id }) == [header],
      members.count == Int(header.itemCount), !members.isEmpty,
      members.allSatisfy({ $0.owner == header.owner }),
      members.enumerated().allSatisfy({ Int($0.element.ordinal) == $0.offset })
    else { throw AlienStorageError.invalidJoin }
    return .init(
      command: header.command, revision: header.revision, items: members.map(\.lot),
      action: header.action, saleValueTenths: header.saleValueTenths, binding: header.binding)
  }
}
