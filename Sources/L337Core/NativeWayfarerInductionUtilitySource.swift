import Foundation

enum NativeInductionUtilityRole: String, CaseIterable, Sendable, Codable {
  case inlet, buffer, `return`
  var target: String { "utility-handoff-" + rawValue }
  var offset: Vector3 {
    switch self {
    case .inlet: .init(60000, 20000, 0)
    case .buffer: .init(60300, 20000, 0)
    case .return: .init(60600, 20000, 0)
    }
  }
  var initialFault: String { self == .buffer ? "relay-disconnected" : "valve-closed" }
}

/// Explicit initial Enron design, in physical metres; never a repaired/received-work claim.
struct NativeInductionUtilitySource: Sendable {
  static let location = SystemIdentity(galaxy: 0, system: 190)
  static let model = "asset:induction-enron-service-enclosure"
  static let geometry = ShipDesign(
    vertices: [
      [-3, -3, -3], [3, -3, -3], [3, 3, -3], [-3, 3, -3], [-3, -3, 3], [3, -3, 3], [3, 3, 3],
      [-3, 3, 3],
    ],
    faces: [
      [0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5],
    ],
    license: "MIT",
    source: "Original Enron external service enclosure, explicit6m-per-side native metre design")
  static let profile = ScriptNPCDefinition(
    id: "induction-enron-service-module", name: "Enron crew-owned external service module",
    source:
      "Explicit original C08 Enron utility source; finite crew-owned kit and mechanical fault",
    basis:
      "Stationary uncrewed6m enclosure in physical metres. Local utility crew retain control. No ship, salvage, cargo or player equipment grant.",
    model: model, scale: 1, energy: 100, recharge: 0, speed: 0, acceleration: 0,
    pitch: 0, yaw: 0, roll: 0, missiles: 0, fuel: 0, drive: nil,
    ecm: false, bounty: 0, lasers: [], components: [])
  let owner: UUID
  let parent: UUID
  let reception: UUID
  let issue: UUID
  init(parent: NativeWayfarerInductionState) throws {
    guard parent.valid, let reception = parent.rescueReception else {
      throw SaveError.invalidCommander
    }
    owner = parent.permission.owner
    self.parent = parent.permission.mission
    self.reception = reception.operation
    issue = Self.issueIdentity(owner: owner, parent: self.parent, receiving: reception.operation)
  }
  static func issueIdentity(owner: UUID, parent: UUID, receiving: UUID) -> UUID {
    ScriptIdentity.uuid(
      "induction-original-enron-utility-source-v1:\(owner):\(parent):\(receiving)")
  }
  static func moduleIdentity(issue: UUID, role: NativeInductionUtilityRole) -> UUID {
    ScriptIdentity.uuid("\(issue):module:\(role.rawValue)")
  }
  static func kitIdentity(issue: UUID, role: NativeInductionUtilityRole) -> UUID {
    ScriptIdentity.uuid("\(issue):crew-repair-kit:\(role.rawValue)")
  }
  static func operatorIdentity(issue: UUID) -> UUID {
    ScriptIdentity.uuid("\(issue):local-utility-crew")
  }
  var operatorID: UUID { Self.operatorIdentity(issue: issue) }
  func module(_ role: NativeInductionUtilityRole) -> UUID {
    Self.moduleIdentity(issue: issue, role: role)
  }
  func kit(_ role: NativeInductionUtilityRole) -> UUID {
    Self.kitIdentity(issue: issue, role: role)
  }
  func initialPose(_ role: NativeInductionUtilityRole, reference: StationAnchor) throws -> ShipPose
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
  static var geometryHash: String {
    get throws { ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry(geometry)) }
  }
  func matchesFit(_ fit: ScriptNPCFit) -> Bool {
    fit.valid && fit.definition == Self.profile
      && fit.models == [Self.model: (try? Self.geometryHash) ?? ""]
  }
}
