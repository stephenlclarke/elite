import Foundation

/// Closed C08 terms, independent of generic W03's original fixed source/custodian contract.
struct NativeInductionSeedTerms: Codable, Sendable, Equatable {
  let source: WayfarerColdChainSite
  let objective: WayfarerColdChainSite
  let receiver: WayfarerColdChainSite
  let batch: String
  let stockUnits: Int
  let tonnes: Int
  let maximumActive: Int
  let route: [Int]
  let hazardTier: Int
  let flightAllowance: Double
  let rewardNative: Int
  var valid: Bool {
    let original = NativeInductionSeedProfile.original
    return source == original.source && objective == original.receiver
      && receiver == original.receiver
      && PackValidation.localID(batch) && batch.hasPrefix("c08-seed-")
      && stockUnits == 6 && tonnes == 3 && maximumActive == 3
      && (2...256).contains(route.count) && route.first == 162 && route.last == 91
      && Set(route).count == route.count && route.allSatisfy { (0..<256).contains($0) }
      && hazardTier == 0 && flightAllowance == 7200
      && rewardNative == 5100 + 950 * (route.count - 1)
  }
}
