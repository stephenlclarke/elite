import Foundation

/// One original consignment. These identities describe stock, not actual admission or rescue.
struct NativeInductionCrewLogManifest: Codable, Sendable, Equatable {
  let owner: UUID
  let mission: UUID
  let commission: UUID
  let custodian: UUID
  let tender: UUID
  let launch: UUID
  let recorder: UUID
  let crew: [UUID]

  init(permission: NativeInductionPermission) {
    owner = permission.owner
    mission = permission.mission
    commission = permission.operation
    let namespace =
      "induction-cevilis-custody-v1:\(permission.owner):\(permission.mission):\(permission.operation)"
    custodian = ScriptIdentity.uuid("\(namespace):custodian")
    tender = ScriptIdentity.uuid("\(namespace):tender")
    launch = ScriptIdentity.uuid("\(namespace):launch")
    recorder = ScriptIdentity.uuid("\(namespace):recorder")
    crew = (0..<2).map { ScriptIdentity.uuid("\(namespace):crew:\($0)") }
  }

  func valid(permission: NativeInductionPermission) -> Bool {
    self == Self(permission: permission)
      && mission == NativeWayfarerInduction.mission(owner: owner)
      && Set([custodian, tender, launch, recorder] + crew).count == 6
  }

  /// Both people are already in the separate launch. The tender and recorder hold no people.
  func occupants(of actor: UUID) -> [UUID] { actor == launch ? crew : [] }
  var receivingShelter: SystemIdentity { NativeInductionCrewLogSource.receiver }
  var massTonnes: Int { 1 }
}

/// Invocation-local preparation only. Runtime must still admit the exact actors and collect the unit.
struct NativeInductionCrewLogSource: Sendable {
  static let location = SystemIdentity(galaxy: 0, system: 211)
  static let receiver = SystemIdentity(galaxy: 0, system: 0)
  static let hull = "SH029"
  static let model = "asset:induction-original-burro"
  static let recorderModel = "catalogue:SH058"
  static let recorderGeometry = "5362f0948c8a6f1b2acc770b100f746ff3f55799db7c0c53261f02943c6a680e"
  static let recorderScale = 0.2
  let manifest: NativeInductionCrewLogManifest
  let physical: OriginalHullPhysicalContract
  let ship: ScriptNPCDefinition
  let recorder: ScriptNPCDefinition
  let recorderDesign: ShipDesign

  static let flightProfile: Result<ScriptNPCDefinition, any Error> = Result {
    guard let performance = OriginalFleetDefinitionData.definition(for: hull)?.nativePerformance,
      performance.valid
    else { throw SaveError.invalidCommander }
    return shipProfile(
      physical: try OriginalHullPhysicalContract.burro.get(), performance: performance)
  }

  init(parent: NativeWayfarerInductionState) throws {
    guard parent.valid, parent.seedReception != nil,
      let performance = OriginalFleetDefinitionData.definition(for: Self.hull)?.nativePerformance,
      performance.valid,
      let recorderDesign = try? Self.authenticatedRecorder.get()
    else { throw SaveError.invalidCommander }
    let physical = try OriginalHullPhysicalContract.burro.get()
    manifest = .init(permission: parent.permission)
    self.physical = physical
    ship = Self.shipProfile(physical: physical, performance: performance)
    recorder = Self.recorderProfile()
    self.recorderDesign = recorderDesign
    guard manifest.valid(permission: parent.permission), ship.valid, recorder.valid,
      recorderDesign.rawMesh.vertices.allSatisfy({
        $0.finite && ($0 * Self.recorderScale).length <= 16
      })
    else { throw SaveError.invalidCommander }
  }

  /// The two hulls share unchanged source performance. Mechanical failure is retained condition,
  /// not a rewritten hull specification, hostile attack, EMP discharge or kill receipt.
  static func shipProfile(
    physical: OriginalHullPhysicalContract, performance: ShipPerformance
  ) -> ScriptNPCDefinition {
    .init(
      id: "induction-cevilis-burro", name: "Cevilis custodian service Burro",
      source: "Original SH029 specifications " + physical.specificationSHA256,
      basis: physical.unitBasis
        + " Existing native conversion: speed/acceleration x18, fuel x0.1 LY. Distinct tender and marked two-person launch identities. Tender propulsion/weapons are mechanically unavailable; no hull or equipment ownership transfers.",
      model: model, scale: physical.metresPerSourceUnit,
      energy: performance.energy, recharge: performance.recharge,
      speed: performance.speed * 18, acceleration: performance.acceleration * 18,
      pitch: performance.pitch, yaw: performance.yaw, roll: performance.roll,
      missiles: performance.missiles, fuel: Double(performance.fuel) / 10,
      drive: .init(
        component: "drive", rangeLightYears: performance.jump,
        activationSeconds: performance.spool, massLockScale: 1,
        fuelUnit: "native-light-years"),
      ecm: false, bounty: 0, lasers: [],
      components: [
        .init(
          id: "drive", model: model, scale: 0.05, position: .init(0, 0, -1),
          orientation: .init(), energy: performance.energy, solid: false, weapons: [])
      ])
  }

  static func recorderProfile() -> ScriptNPCDefinition {
    .init(
      id: "induction-crew-custody-recorder", name: "Original Cevilis crew custody recorder",
      source: "C08 original custodian recorder; shared authenticated physical package only",
      basis:
        "One protected tonne. Identifies the original two launch occupants and Enmadan shelter. Passive package at W03 physical scale; distinct source, serial and custody. No W03 mission, reward, clue or player cabins.",
      model: recorderModel, scale: recorderScale, energy: 100, recharge: 0,
      speed: 0, acceleration: 0, pitch: 0, yaw: 0, roll: 0, missiles: 0, fuel: 0,
      drive: nil, ecm: false, bounty: 0, lasers: [], components: [])
  }

  var models: [String: ShipDesign] {
    [Self.model: physical.model.nativeDesign, Self.recorderModel: recorderDesign]
  }

  private static let authenticatedRecorder: Result<ShipDesign, any Error> = Result {
    guard let design = ShipCatalogue.ship("SH058")?.design,
      ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry(design)) == recorderGeometry
    else { throw SaveError.invalidCommander }
    return design
  }

  static let recorderRadius: Result<Double, any Error> = Result {
    let design = try authenticatedRecorder.get()
    guard let radius = design.rawMesh.vertices.map({ ($0 * recorderScale).length }).max(),
      radius.isFinite, radius > 0, radius <= 16
    else { throw SaveError.invalidCommander }
    return radius
  }

  private static let authenticatedModels: Result<[String: String], any Error> = Result {
    [
      model: ScriptPackLibrary.hash(
        try ScriptPackLibrary.canonicalGeometry(
          OriginalHullPhysicalContract.burro.get().model.nativeDesign)),
      recorderModel: recorderGeometry,
    ]
  }

  func matchesFit(_ fit: ScriptNPCFit, recorder: Bool) -> Bool {
    let expected = recorder ? self.recorder : ship
    guard fit.valid, fit.definition == expected,
      let hashes = try? Self.authenticatedModels.get(), let hash = hashes[expected.model]
    else { return false }
    return fit.models == [expected.model: hash]
  }
}
