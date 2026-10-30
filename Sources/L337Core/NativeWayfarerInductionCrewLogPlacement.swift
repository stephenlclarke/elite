import Foundation

enum NativeInductionCrewLogRole: String, Sendable, CaseIterable {
  case tender, launch, recorder
  var offset: Vector3 {
    switch self {
    case .tender: .init(60000, 20000, 0)
    case .launch: .init(60300, 20000, 0)
    case .recorder: .init(60000, 20000, 100)
    }
  }
  var propulsionAvailable: Bool { self == .launch }
  var weaponsAvailable: Bool { false }
}

extension NativeInductionCrewLogSource {
  /// The caller supplies the actual non-spinning reference, never the animated station-body pose.
  /// This prepares an initial pose; it grants no clearance and never repositions a retained actor.
  func initialPose(for role: NativeInductionCrewLogRole, reference: StationAnchor) throws
    -> ShipPose
  {
    guard reference.identity.system == Self.location, reference.identity.visit > 0,
      reference.identity.entity == 1, reference.position.finite,
      reference.orientation.validRotation,
      reference.orientation.x.cross(reference.orientation.y).dot(reference.orientation.z) > 0.9999
    else { throw SaveError.invalidCommander }
    let pose = ShipPose(
      position: reference.position + reference.orientation.apply(role.offset),
      orientation: reference.orientation)
    guard pose.position.finite, pose.position.length <= 1e9 else {
      throw SaveError.invalidCommander
    }
    return pose
  }
}
