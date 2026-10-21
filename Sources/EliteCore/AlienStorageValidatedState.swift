import Foundation

/// Immutable validation witness. Construct at decode/transaction boundaries, never per frame.
/// Swift checks Sendable because the snapshot and all derived values are immutable.
final class AlienStorageValidatedState: Sendable, Equatable {
  let snapshot: AlienStorageSnapshot
  let transferredSections: Set<WreckSectionIdentity>
  private let fitted: [UUID: [AlienModuleKind: AlienAttachmentSummary]]
  private static let empty = Dictionary(
    uniqueKeysWithValues: AlienModuleKind.allCases.map {
      ($0, AlienAttachmentSummary(count: 0, bonusBasisPoints: 0))
    })

  init(validating snapshot: AlienStorageSnapshot) throws {
    try snapshot.validate()
    var fitted: [UUID: [AlienModuleKind: AlienAttachmentSummary]] = [:]
    for item in snapshot.attachments {
      guard case .fitted(let hull) = item.disposition else { continue }
      var summaries = fitted[hull] ?? Self.empty
      let prior = summaries[item.kind]!
      let count = prior.count.addingReportingOverflow(1)
      let bonus = prior.bonusBasisPoints.addingReportingOverflow(item.contributionBasisPoints)
      guard !count.overflow, !bonus.overflow else { throw AlienStorageError.arithmeticOverflow }
      summaries[item.kind] = .init(count: count.partialValue, bonusBasisPoints: bonus.partialValue)
      fitted[hull] = summaries
    }
    self.snapshot = snapshot
    transferredSections = Set(
      snapshot.world.compactMap {
        if case .legacySection(let section) = $0 { section.plan.section } else { nil }
      })
    self.fitted = fitted
  }

  var owner: UUID { snapshot.owner }
  var revision: UInt64 { snapshot.revision }
  var worldRevision: UInt64 { snapshot.worldRevision }
  func summaries(for hull: UUID) -> [AlienModuleKind: AlienAttachmentSummary] {
    fitted[hull] ?? Self.empty
  }

  /// Full order-independent semantic equality remains the authority for stale proposals.
  static func == (lhs: AlienStorageValidatedState, rhs: AlienStorageValidatedState) -> Bool {
    lhs.snapshot == rhs.snapshot
  }
}
