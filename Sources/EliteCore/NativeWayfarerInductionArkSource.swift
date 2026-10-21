import Foundation

/// Invocation-local authored source. It cannot admit an actor, consume stock or award arrival.
struct NativeInductionArkSource: Sendable {
  let owner: UUID
  let mission: UUID
  let loanOperation: UUID
  let actor: UUID
  let source: SystemIdentity
  let destination: SystemIdentity
  let seeds: [UUID]
  let crew: [UUID]
  let physical: OriginalHullPhysicalContract
  let definition: ScriptNPCDefinition
  static let hull = "SH061"
  static let model = "asset:induction-original-haflinger"
  static let seedTonnes = 40
  static let crewCount = 6

  init(
    loan: NativeInductionVaultKeyLoan, permission: NativeInductionPermission,
    service: NativeInductionCassetteService
  ) throws {
    guard loan.valid(service: service, permission: permission),
      let original = OriginalFleetDefinitionData.definition(for: Self.hull),
      let performance = original.nativePerformance, performance.valid,
      performance.cargo >= Self.seedTonnes,
      let physical = try? OriginalHullPhysicalContract.haflinger.get()
    else { throw SaveError.invalidCommander }
    owner = permission.owner
    mission = permission.mission
    loanOperation = loan.operation
    actor = Self.actorIdentity(mission: mission, loan: loanOperation)
    source = NativeWayfarerInduction.seedSource
    destination = NativeWayfarerInduction.seedReceiver
    let namespace = "induction-original-ark-stock-v1:\(owner):\(actor)"
    seeds = (0..<Self.seedTonnes).map { ScriptIdentity.uuid("\(namespace):seed:\($0)") }
    crew = (0..<Self.crewCount).map { ScriptIdentity.uuid("\(namespace):crew:\($0)") }
    self.physical = physical
    definition = try Self.definition(physical: physical, performance: performance)
  }

  static func actorIdentity(mission: UUID, loan: UUID) -> UUID {
    ScriptIdentity.uuid("induction-original-seed-ark-v1:\(mission):\(loan)")
  }

  static func profile() throws -> ScriptNPCDefinition {
    guard let original = OriginalFleetDefinitionData.definition(for: hull),
      let performance = original.nativePerformance, performance.valid
    else { throw SaveError.invalidCommander }
    return try definition(
      physical: OriginalHullPhysicalContract.haflinger.get(), performance: performance)
  }

  /// Keep source units explicit: ordinary flight uses 18 m/s per speed unit and 0.1 LY per fuel unit.
  private static func definition(
    physical: OriginalHullPhysicalContract, performance: ShipPerformance
  ) throws -> ScriptNPCDefinition {
    let definition = ScriptNPCDefinition(
      id: "induction-original-seed-ark", name: "Registered Enlirin seed ark / Haflinger",
      source: "Original SH061 specifications " + physical.specificationSHA256,
      basis: physical.unitBasis
        + " Existing native flight conversion: speed/acceleration x18; fuel x0.1 LY. One finite internal fitted drive uses the original hull energy ceiling. Finite 40t custodian seed stores and six crew are separate from the player key and cabins.",
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
          id: "drive", model: model, scale: 0.05, position: .init(0, 0, -1.8),
          orientation: .init(), energy: performance.energy, solid: false, weapons: [])
      ])
    guard definition.valid else { throw SaveError.invalidCommander }
    return definition
  }

  var models: [String: ShipDesign] { [Self.model: physical.model.nativeDesign] }

  private static let authenticatedModels: Result<[String: String], any Error> = Result {
    let original = try OriginalHullPhysicalContract.haflinger.get().model.nativeDesign
    return [model: ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry(original))]
  }

  func matchesFit(_ fit: ScriptNPCFit) -> Bool {
    guard valid, fit.valid, fit.definition == definition,
      let expected = try? Self.authenticatedModels.get()
    else { return false }
    return fit.models == expected
  }

  var valid: Bool {
    mission == NativeWayfarerInduction.mission(owner: owner)
      && actor == Self.actorIdentity(mission: mission, loan: loanOperation)
      && source == NativeWayfarerInduction.seedSource
      && destination == NativeWayfarerInduction.seedReceiver
      && seeds.count == Self.seedTonnes && Set(seeds).count == Self.seedTonnes
      && crew.count == Self.crewCount && Set(crew).count == Self.crewCount
      && Set(seeds).isDisjoint(with: crew)
      && physical.id == Self.hull && definition.valid
      && definition.scale == physical.metresPerSourceUnit
  }
}
