import Foundation
import Testing

@testable import EliteCore

struct InductionArkProducerFixture {
  let key: NativeInductionVaultKeyLoan
  let parent: NativeWayfarerInductionState
  let source: NativeInductionArkSource
  let authorization: NativeArkLaunchAuthorization
  init(escortReach: Double = 7) throws {
    let f = try InductionVaultKeyFixture()
    key = try f.key()
    parent = try f.serviced.borrowingVaultKey(key, freeTonnes: 1)
    source = try .init(
      loan: key, permission: parent.permission, service: #require(parent.cassetteService))
    let route = try NativeArkRoutePlan(source: source, escortReachLY: escortReach)
    let job = NativeInductionArkPack.instance(registeredArk: source.actor)
    let operation = try NativeArkLaunchAuthorization.identity(
      registeredArk: source.actor, dock: key.dock, carrier: key.carrier,
      revision: key.inventoryRevision, physicalTime: 400, route: route)
    authorization = .init(
      owner: source.owner, parent: source.mission, job: job, registeredArk: source.actor,
      actor: NativeInductionArkPack.actor(instance: job), operation: operation,
      stockIssue: ScriptIdentity.uuid("native-ark-initial-stock-v1:\(source.actor):\(operation)"),
      loanOperation: key.operation, sequence: 10, dock: key.dock, carrier: key.carrier,
      inventoryRevision: key.inventoryRevision, physicalTime: 400, flightSeconds: 450,
      route: route, seeds: source.seeds, crew: source.crew)
  }
  func state() throws -> NativeInductionArkState {
    .init(authorization: authorization, fuel: try .init(source: source))
  }
  var link: NativeInductionArkLink {
    .init(
      job: authorization.job, registeredArk: source.actor,
      operation: authorization.operation, loanOperation: key.operation)
  }
  func child(_ state: NativeInductionArkState) -> ScriptInstance {
    var child = ScriptInstance(
      id: authorization.job, definition: NativeInductionArkPack.stateID,
      version: NativeInductionArkPack.version, digest: NativeInductionArkPack.digest)
    child.savedNativeArk = state
    return child
  }
}

struct NativeWayfarerInductionArkProducerUnitTests {
  @Test func launchConsumesOnlyOneOriginalRegistrationAndKeepsKeyMassAndEarlierReceipts() throws {
    let f = try InductionArkProducerFixture()
    let registered = try f.parent.registeringArk(f.link)
    #expect(f.authorization.valid(source: f.source, key: f.key))
    #expect(registered.valid && registered.ark == f.link)
    #expect(registered.permission == f.parent.permission && registered.seedKey == f.key)
    #expect(registered.cassetteService == f.parent.cassetteService)
    #expect(
      registered.payloads == f.parent.payloads && registered.milestones == [0, 1, 2, 3, 4, 5])
    #expect(registered.action(at: NativeWayfarerInduction.seedSource) == .progress)
    #expect(throws: (any Error).self) { try registered.registeringArk(f.link) }
    let foreign = try InductionArkProducerFixture()
    #expect(!f.authorization.valid(source: foreign.source, key: foreign.key))
    #expect(throws: (any Error).self) { try f.parent.registeringArk(foreign.link) }
    let restored = try JSONDecoder().decode(
      NativeWayfarerInductionState.self, from: JSONEncoder().encode(registered))
    #expect(restored == registered && restored.valid && restored.ark == f.link)
  }

  @Test func routeFitsBothTheOriginalArkAndEscortWithoutChangingAuthoredDriveOrTank() throws {
    let f = try InductionArkProducerFixture()
    let route = f.authorization.route
    #expect(route.matches(source: f.source) && route.routingReachLY == 7)
    #expect(route.driveReachLY == 9 && route.initialFuelLY == 13)
    #expect(route.legDistancesLY.allSatisfy { $0 > 0 && $0 <= 7 })
    #expect(route.worldKeys.first == "G01-S162" && route.worldKeys.last == "G01-S091")
    #expect(route.minimumAdditionalFuelLY > 0)
    for reach in [0, -1, Double.nan] {
      #expect(throws: (any Error).self) {
        try NativeArkRoutePlan(source: f.source, escortReachLY: reach)
      }
    }
    let restored = try JSONDecoder().decode(
      NativeArkRoutePlan.self, from: JSONEncoder().encode(route))
    #expect(restored == route && restored.matches(source: f.source))
  }

  @Test func admissionAndPhysicalLossKeepOriginalManifestsWithoutManufacturingCrewOrReceiving()
    throws
  {
    let f = try InductionArkProducerFixture()
    let initial = try f.state()
    #expect(initial.shapeValid(source: f.source, key: f.key))
    #expect(initial.admission == nil && initial.livingCrew == 0 && initial.intactSeedTonnes == 0)
    let actor = ActorIdentity(system: NativeWayfarerInduction.seedSource, visit: 6, entity: 2)
    let admitted = initial.replacing(admission: .init(actor: actor, physicalTime: 401))
    #expect(admitted.shapeValid(source: f.source, key: f.key))
    #expect(admitted.livingCrew == 6 && admitted.intactSeedTonnes == 40)
    let lost = admitted.replacing(loss: .init(actor: actor, observedPhysicalTime: 450))
    #expect(lost.shapeValid(source: f.source, key: f.key))
    #expect(lost.livingCrew == 0 && lost.intactSeedTonnes == 0)
    #expect(lost.authorization == initial.authorization && lost.fuel == initial.fuel)
    #expect(lost.authorization.crew.count == 6 && lost.authorization.seeds.count == 40)
    #expect(
      !initial.replacing(loss: .init(actor: actor, observedPhysicalTime: 450))
        .shapeValid(source: f.source, key: f.key))
    #expect(
      !initial.replacing(
        admission: .init(
          actor: .init(system: NativeWayfarerInduction.seedReceiver, visit: 7, entity: 2),
          physicalTime: 401)
      )
      .shapeValid(source: f.source, key: f.key))
    let restored = try JSONDecoder().decode(
      NativeInductionArkState.self, from: JSONEncoder().encode(lost))
    #expect(restored == lost && restored.shapeValid(source: f.source, key: f.key))
  }

  @Test func hopReferencesBindExistingNativeLegIdentityAndRefuseForeignJobsAndUnboundedRetries()
    throws
  {
    let f = try InductionArkProducerFixture()
    let a = f.authorization
    let request = "native-ark-hop-0-0"
    let reference = NativeArkHopReference(
      hop: 0, attempt: 0,
      leg: NativeWormholeLeg.identity(
        instance: a.job, actor: a.actor, request: request))
    #expect(reference.valid(authorization: a) && reference.request == request)
    #expect(
      !NativeArkHopReference(hop: 0, attempt: 128, leg: reference.leg).valid(authorization: a))
    #expect(!NativeArkHopReference(hop: -1, attempt: 0, leg: reference.leg).valid(authorization: a))
    #expect(!NativeArkHopReference(hop: 0, attempt: 0, leg: UUID()).valid(authorization: a))
    let foreign = try InductionArkProducerFixture()
    #expect(!reference.valid(authorization: foreign.authorization))
    #expect(try !f.state().replacing(legs: [reference]).shapeValid(source: f.source, key: f.key))
  }

  @Test func internalPackPinsOriginalGeometryAndOnlyRequestsActualNativeAdmission() throws {
    let pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledInductionArkDirectory)
    #expect(NativeInductionArkPack.matches(pack))
    #expect(pack.digest == NativeInductionArkPack.digest)
    #expect(pack.manifest.mission.parentOnly == nil && pack.manifest.trial == nil)
    #expect(pack.manifest.board == nil && pack.manifest.encounters?.first?.actors.count == 1)
    let model = try #require(pack.models[NativeInductionArkSource.model])
    let source = try InductionArkProducerFixture().source
    #expect(model == source.physical.model.nativeDesign)
    #expect(pack.manifest.npcs == [source.definition])
    #expect(
      pack.manifest.handlers.map(\.event) == [
        "mission.accepted", "timer.fired", "encounter.admitted",
      ])
  }

  @Test func arkEnvelopeRefusesOldMisplacedUnknownAndHalfPinnedServiceClaims() throws {
    let f = try InductionArkProducerFixture()
    let child = f.child(try f.state())
    let childObject = try #require(
      try JSONSerialization.jsonObject(with: JSONEncoder().encode(child)) as? [String: Any])
    func data(_ object: [String: Any]) throws -> Data {
      try JSONSerialization.data(withJSONObject: ["instances": [child.id.uuidString: object]])
    }
    for schema in [NativeInductionArkSave.version, NativeInductionArkSave.alienVersion] {
      try NativeInductionArkSave.validateFields(data(childObject), part: .missions, schema: schema)
    }
    #expect(throws: (any Error).self) {
      try NativeInductionArkSave.validateFields(
        data(childObject), part: .missions, schema: NativeWayfarerInductionSave.version)
    }
    var unknown = childObject
    var leaf = try #require(unknown["savedNativeArk"] as? [String: Any])
    leaf["received"] = true
    unknown["savedNativeArk"] = leaf
    #expect(throws: (any Error).self) {
      try NativeInductionArkSave.validateFields(
        data(unknown), part: .missions, schema: NativeInductionArkSave.version)
    }
    var halfPinned = childObject
    halfPinned["definition"] = "another/mission"
    #expect(throws: (any Error).self) {
      try NativeInductionArkSave.validateFields(
        data(halfPinned), part: .missions, schema: NativeInductionArkSave.version)
    }
    let misplaced = try JSONSerialization.data(withJSONObject: [
      "savedScriptState": ["instances": [child.id.uuidString: childObject]]
    ])
    #expect(throws: (any Error).self) {
      try NativeInductionArkSave.validateFields(
        misplaced, part: .commander, schema: NativeInductionArkSave.version)
    }
  }
}
