import Foundation

extension Commander {
  /// The immutable storage witness already replayed the source and fitting history.
  /// Stored devices and fittings on another owned hull confer no flight capability.
  var fittedAlienHyperspaceDrivePolicy: HyperspaceDrivePolicy? {
    guard let hull = hullInstanceID, let storage = alienStorageState?.current,
      storage.owner == equipmentOwnerID,
      (storage.summaries(for: hull)[.hyperspaceDrive]?.count ?? 0) > 0
    else { return nil }
    return .alienFoundation
  }
}
