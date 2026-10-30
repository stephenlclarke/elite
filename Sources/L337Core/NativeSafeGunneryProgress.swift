import Foundation

enum NativeSafeGunneryProgressError: Error, Equatable, Sendable {
  case invalidPractice, foreignReceipt, duplicateReceipt
}

/// Three authentic first-hit observations only. Ceasefire and terminal authority are separate.
/// The immutable original retains the actual native allocations rather than narrative labels.
struct NativeSafeGunneryProgress: Codable, Sendable, Equatable {
  let original: NativePracticeState
  private(set) var hits: [NativePracticeHitReceipt] = []

  init(beginning practice: NativePracticeState) throws {
    guard practice.valid, practice.permission.lesson == .gunnery,
      practice.endedAt == nil, practice.hits.isEmpty
    else { throw NativeSafeGunneryProgressError.invalidPractice }
    original = practice
  }

  var valid: Bool {
    original.valid && original.permission.lesson == .gunnery && original.endedAt == nil
      && original.hits.isEmpty && hits.count <= original.beacons.count
      && Set(hits.map(\.target)).count == hits.count
      && Set(hits.map { $0.origin.emissionID }).count == hits.count
      && hits.allSatisfy { $0.valid(in: original) && [.laser, .missile].contains($0.kind) }
  }

  var threeDistinctHits: Bool {
    valid && Set(hits.map(\.target)) == Set(original.beacons.map(\.identity))
  }

  func matches(_ provider: NativePracticeState) -> Bool {
    valid && provider.valid && provider.permission == original.permission
      && provider.beacons == original.beacons
      && hits.allSatisfy { provider.hits.contains($0) }
  }

  mutating func record(_ receipt: NativePracticeHitReceipt, provider: NativePracticeState) throws {
    guard matches(provider), provider.endedAt == nil,
      provider.hits.contains(receipt), receipt.valid(in: original),
      [.laser, .missile].contains(receipt.kind)
    else { throw NativeSafeGunneryProgressError.foreignReceipt }
    guard
      !hits.contains(where: {
        $0.target == receipt.target || $0.origin.emissionID == receipt.origin.emissionID
      })
    else { throw NativeSafeGunneryProgressError.duplicateReceipt }
    hits.append(receipt)
  }

  /// Catch up only from retained authenticated receipts, including after cold restoration.
  /// Missing bodies, proximity and a caller-supplied count cannot enter this reducer.
  func observing(_ provider: NativePracticeState) throws -> Self {
    guard matches(provider), provider.endedAt == nil else {
      throw NativeSafeGunneryProgressError.invalidPractice
    }
    var next = self
    for receipt in provider.hits where !next.hits.contains(receipt) {
      try next.record(receipt, provider: provider)
    }
    return next
  }
}
