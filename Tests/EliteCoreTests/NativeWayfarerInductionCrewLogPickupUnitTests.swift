import Foundation
import Testing

@testable import EliteCore

/// Typed receipt/graph fixtures only, never a forged native pending contact or executed journey.
private struct CrewLogPickupFixture {
  let f: CrewLogProducerFixture
  let capture: NativeCrewLogCapture
  init() throws {
    let f = try CrewLogProducerFixture()
    self.f = f
    let carrier = f.parent.permission.carrier
    let scoop = EquipmentPurchaseItem(
      id: UUID(),
      node: .init(family: EquipmentRuntimeCatalog.utilityFamily(.fuelScoops), key: "Fuel Scoops"),
      location: EquipmentRuntimeCatalog.purchaseLocation(
        .init(hullInstanceID: carrier, slot: .utility(.fuelScoops))),
      provenance: .standard)
    var marker = try f.prepared(.recorder)
    marker.presence = .present
    marker.body.id = 44
    marker.body.position = .init(0, -45, 55)
    marker.body.physical = .init(
      identity: f.admission.recorder, population: .mission,
      npc: try NativeInductionCrewLogPack.initialResources(
        state: f.child(), actor: f.prepared(.recorder)))
    capture = .init(
      issue: f.authorization.operation, original: f.source.manifest.recorder,
      job: f.authorization.job,
      operation: NativeCrewLogCapture.identity(
        issue: f.authorization.operation, original: f.source.manifest.recorder),
      sequence: 101, actor: f.admission.recorder,
      collector: .init(system: NativeInductionCrewLogSource.location, visit: 30, entity: 0),
      carrier: carrier, inventoryRevision: 1, scoop: scoop, marker: marker,
      capturePoint: marker.body.position, relativeSpeed: 0,
      radius: try NativeInductionCrewLogSource.recorderRadius.get(),
      startTime: 20_001, physicalTime: 20_001.05, flightSeconds: 10_000.05, epoch: UUID())
  }
  func state() -> NativeInductionCrewLogState {
    var state = NativeInductionCrewLogState(authorization: f.authorization)
    state.admission = f.admission
    state.capture = capture
    return state
  }
  func parent() throws -> NativeWayfarerInductionState {
    try f.parent.collectingCrewLog(capture, freeTonnes: 1)
  }
  func changing(_ key: String, to value: Any) throws -> NativeCrewLogCapture {
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(capture)) as? [String: Any])
    object[key] = value
    return try JSONDecoder().decode(
      NativeCrewLogCapture.self, from: JSONSerialization.data(withJSONObject: object))
  }
  func commander() throws -> Commander {
    var commander = Commander()
    commander.savedEquipmentInventory = try .init(
      owner: f.source.manifest.owner, activeHull: capture.carrier)
    for _ in 0..<30 {
      commander.flightSimulation.enter(NativeInductionCrewLogSource.location, arriving: true)
    }
    for _ in 0..<3 { _ = commander.flightSimulation.allocateActor() }
    commander.flightSimulation.physicalTime = 20_002
    commander.scriptState.flightSeconds = 10_001
    commander.scriptState.nextEvent = 101
    commander.nativeStations = try .init(owner: f.source.manifest.owner)
    commander.nativeStations?.mainStations = [
      NativeWayfarerInductionUnitTests().dock(
        owner: f.source.manifest.owner, system: 211, visit: 30, sequence: 30
      ).station
    ]
    var parent = ScriptInstance(
      id: f.parent.permission.mission, definition: NativeWayfarerInduction.stateID,
      version: NativeWayfarerInduction.version, digest: NativeWayfarerInduction.digest)
    let leaf = try self.parent()
    parent.savedWayfarerInduction = leaf
    parent.payloads = leaf.payloads
    parent.milestones = leaf.milestones
    parent.acknowledge(100)
    parent.acknowledge(101)
    var child = f.child(state())
    child.acknowledge(101)
    child.milestones = [0]
    var actors: [String: ScriptOwnedActor] = [:]
    for (index, role) in NativeInductionCrewLogRole.allCases.enumerated() {
      var actor = try f.prepared(role)
      actor.presence = role == .recorder ? .outside : .present
      actor.body.id = 42 + index
      actor.body.physical = .init(
        identity: f.admission.actor(for: role), population: .mission,
        npc: try NativeInductionCrewLogPack.initialResources(
          state: f.child(), actor: f.prepared(role)))
      actors[role.rawValue] = actor
    }
    child.ownedEncounters = [
      NativeInductionCrewLogPack.encounter: .init(
        id: NativeInductionCrewLogPack.encounter, galaxy: 0, system: 211, admitted: true,
        actors: actors)
    ]
    commander.scriptState.instances = [parent.id: parent, child.id: child]
    return commander
  }
}

struct NativeWayfarerInductionCrewLogPickupUnitTests {
  @Test func originalPickupReservesExactlyOneTonneAndOnlyStageEightWithoutBoardingOrReward() throws
  {
    let f = try CrewLogPickupFixture()
    let next = try f.parent()
    let reception = try #require(f.f.parent.seedReception)
    #expect(f.capture.valid(permission: f.f.parent.permission, reception: reception))
    #expect(next.valid && next.crewLog == f.capture && next.crewLogLoss == nil)
    #expect(next.payloads == [NativeWayfarerInduction.crewLogPayload: 1])
    #expect(next.milestones == [0, 1, 2, 3, 4, 5, 6, 7] && !next.milestones.contains(8))
    #expect(
      next.permission == f.f.parent.permission && next.seedReception == f.f.parent.seedReception)
    #expect(
      next.seedKey == f.f.parent.seedKey && next.cassetteService == f.f.parent.cassetteService)
    #expect(f.state().livingCrew == f.f.source.manifest.crew)
    let encoded = try JSONEncoder().encode(next)
    #expect(encoded.count <= 16_384)
    let restored = try JSONDecoder().decode(NativeWayfarerInductionState.self, from: encoded)
    #expect(restored == next && restored.payloads == next.payloads)
  }

  @Test func duplicateForeignOrFullHoldPickupCannotReplaceTheOriginalUnitOrEarlierHistory() throws {
    let f = try CrewLogPickupFixture()
    #expect(throws: (any Error).self) { try f.f.parent.collectingCrewLog(f.capture, freeTonnes: 0) }
    #expect(throws: (any Error).self) { try f.parent().collectingCrewLog(f.capture, freeTonnes: 1) }
    let foreign = try CrewLogPickupFixture()
    #expect(throws: (any Error).self) {
      try f.f.parent.collectingCrewLog(foreign.capture, freeTonnes: 1)
    }
    let substitute = try f.changing("original", to: UUID().uuidString)
    #expect(throws: (any Error).self) {
      try f.f.parent.collectingCrewLog(substitute, freeTonnes: 1)
    }
    #expect(f.f.parent.payloads.isEmpty && f.f.parent.crewLog == nil)
    #expect(f.f.parent.seedReception != nil && f.f.parent.milestones == [0, 1, 2, 3, 4, 5, 6])
  }

  @Test func safeScoopRequiresTheMeasuredPackageInsideEveryApertureAxisAtNativeRelativeSpeed()
    throws
  {
    let radius = try NativeInductionCrewLogSource.recorderRadius.get()
    let limit = ScoopApproachController.maximumRelativeSpeed
    #expect(
      NativeCrewLogCapture.approachAllowed(point: .init(0, -45, 55), radius: radius, speed: limit))
    for point in [
      Vector3(17, -45, 55), .init(0, -28, 55), .init(0, -45, 72), .init(0, 0, 55),
      .init(0, -45, -55), .init(.nan, -45, 55),
    ] {
      #expect(!NativeCrewLogCapture.approachAllowed(point: point, radius: radius, speed: 0))
    }
    for speed in [-1, limit + 0.01, Double.nan, .infinity] {
      #expect(
        !NativeCrewLogCapture.approachAllowed(
          point: .init(0, -45, 55), radius: radius, speed: speed))
    }
    for invalidRadius in [0, 16.01, Double.nan] {
      #expect(
        !NativeCrewLogCapture.approachAllowed(
          point: .init(0, -45, 55), radius: invalidRadius, speed: 0))
    }
  }

  @Test func receiptNeedsTheActualFittedScoopOriginalPhysicalMarkerAndPositiveNativeFrame() throws {
    let f = try CrewLogPickupFixture()
    let reception = try #require(f.f.parent.seedReception)
    for changed in [
      try f.changing("radius", to: f.capture.radius + 0.01),
      try f.changing("physicalTime", to: f.capture.startTime),
      try f.changing("physicalTime", to: f.capture.startTime + 0.11),
      try f.changing("sequence", to: 0), try f.changing("carrier", to: UUID().uuidString),
    ] {
      #expect(!changed.valid(permission: f.f.parent.permission, reception: reception))
    }
    var scoop = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(f.capture.scoop)) as? [String: Any])
    scoop["location"] = ["hull": f.capture.carrier.uuidString, "slot": "utility.ecm"]
    let unfitted = try f.changing("scoop", to: scoop)
    #expect(!unfitted.valid(permission: f.f.parent.permission, reception: reception))
    var marker = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(f.capture.marker)) as? [String: Any])
    marker["presence"] = "outside"
    #expect(
      try !f.changing("marker", to: marker).valid(
        permission: f.f.parent.permission, reception: reception))
    var state = f.state()
    state.capture = try f.changing("issue", to: UUID().uuidString)
    #expect(!state.shapeValid(parent: try f.parent()))
  }

  @Test func laterActualCarrierLossReleasesOnlyTheRecorderTonneAndKeepsOriginalPickupAndCrew()
    throws
  {
    let f = try CrewLogPickupFixture()
    let held = try f.parent()
    let context = ScriptEventContext(
      galaxy: 0, system: 211, docked: false, mainStation: false,
      revision: 10, frameSeconds: 0.1, localSeconds: 10_001, flightSeconds: 10_001,
      calendarSeconds: 100_001, transitSeconds: 0, playerPosition: .init(0, 0, 0))
    let loss = NativeInductionCrateLoss(
      carrier: f.capture.carrier, physicalTime: 20_002,
      facts: .init(cause: .shipDestroyed, sequence: 102, context: context, energy: 0, visit: 30))
    let lost = try held.losing(loss)
    #expect(lost.valid && lost.payloads.isEmpty && lost.crewLogLoss == loss)
    #expect(lost.crewLog == held.crewLog && lost.milestones == held.milestones)
    #expect(lost.seedKeyLoss == nil && lost.seedReception == held.seedReception)
    #expect(lost.permission == held.permission && f.state().livingCrew.count == 2)
    #expect(throws: (any Error).self) { try lost.collectingCrewLog(f.capture, freeTonnes: 1) }
    let falseLoss = NativeInductionCrateLoss(
      carrier: f.capture.carrier, physicalTime: 20_002,
      facts: .init(cause: .shipDestroyed, sequence: 102, context: context, energy: 1, visit: 30))
    #expect(throws: (any Error).self) { try held.losing(falseLoss) }
    let restored = try JSONDecoder().decode(
      NativeWayfarerInductionState.self, from: JSONEncoder().encode(lost))
    #expect(restored == lost && restored.payloads.isEmpty)
  }

  @Test func owningGraphRequiresBothPickupReceiptsAcknowledgementsAndOriginalRemovedUnit() throws {
    let f = try CrewLogPickupFixture()
    let original = try f.commander()
    #expect(NativeInductionCrewLogSave.validateClaims(original))
    let logical = NativeInductionCrewLogPack.actor(job: f.capture.job, role: .recorder)
    #expect(NativeInductionCrewLogPack.consumed(logical, commander: original))
    #expect(
      !NativeInductionCrewLogPack.consumed(
        NativeInductionCrewLogPack.actor(job: f.capture.job, role: .launch), commander: original))
    #expect(original.nativePeople == nil)
    var changed = original
    changed.scriptState.instances[f.capture.job]?.savedNativeCrewLog?.capture = nil
    #expect(!NativeInductionCrewLogSave.validateClaims(changed))
    changed = original
    changed.scriptState.instances[f.capture.job]?.ownedEncounters[
      NativeInductionCrewLogPack.encounter]?.actors["recorder"]?.presence = .present
    #expect(!NativeInductionCrewLogSave.validateClaims(changed))
    changed = original
    changed.scriptState.instances[f.capture.job] = nil
    #expect(!NativeInductionCrewLogSave.validateClaims(changed))
  }

  @Test func closedPickupEnvelopePreservesSourceOnlySavesAndRejectsEarlyOrUnknownPickupClaims()
    throws
  {
    let f = try CrewLogPickupFixture()
    let state = f.state()
    let child = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
    let parent = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(f.parent())) as? [String: Any])
    func bytes(_ child: [String: Any], parent: [String: Any]? = nil) throws -> Data {
      var values: [String: Any] = [
        f.capture.job.uuidString: [
          "definition": NativeInductionCrewLogPack.stateID,
          "digest": NativeInductionCrewLogPack.digest, "savedNativeCrewLog": child,
        ]
      ]
      if let parent {
        values[f.f.parent.permission.mission.uuidString] = [
          "definition": NativeWayfarerInduction.stateID, "digest": NativeWayfarerInduction.digest,
          "savedWayfarerInduction": parent,
        ]
      }
      return try JSONSerialization.data(withJSONObject: ["instances": values])
    }
    for schema in [85, 86] {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(
        bytes(child, parent: parent), part: .missions, schema: schema)
    }
    for schema in [81, 82, 83, 84, 87] {
      #expect(throws: (any Error).self) {
        try NativeInductionCrewLogSave.validateFields(bytes(child), part: .missions, schema: schema)
      }
    }
    var sourceOnly = child
    sourceOnly["capture"] = nil
    for schema in [83, 84, 85, 86] {
      try NativeInductionCrewLogSave.validateFields(
        bytes(sourceOnly), part: .missions, schema: schema)
    }
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogSave.validateFields(
        bytes(sourceOnly, parent: parent), part: .missions, schema: 83)
    }
    var altered = child
    var capture = try #require(altered["capture"] as? [String: Any])
    capture["manufacturedRescue"] = true
    altered["capture"] = capture
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogSave.validateFields(bytes(altered), part: .missions, schema: 85)
    }
    #expect(NativeInductionArkSave.isAlien(84) && NativeInductionArkSave.isAlien(86))
    #expect(!NativeInductionArkSave.isAlien(85))
  }

  @Test func optionalSalvageGuidanceKeepsTheSamePhysicalScoopAndDoesNotRequireCabins() throws {
    let f = try CrewLogPickupFixture()
    let metadata = SalvageTargetMetadata(
      category: .cargo, ownership: .missionProtected, claimant: nil,
      wreck: nil, section: nil, lot: nil,
      bounds: .init(center: .init(0, 0, 0), radius: f.capture.radius), workSurfaces: [])
    let candidate = WorkTargetCandidate(
      identity: f.capture.actor, kind: .recoverable(metadata, payload: nil),
      isLive: true, frontVisible: true, distance: 100, singleScoopCompatible: true,
      inductionCrewLog: .init(original: f.capture.original, fits: true))
    let decision = WorkTargetSelection.evaluate(
      candidate, system: f.capture.actor.system, visit: 30,
      capabilities: .init(
        core: .military, miningModule: false, salvageModule: true, fuelScoops: true))
    #expect(decision == .eligible(.autoScoop(.salvage)))
    let noScoops = WorkTargetSelection.evaluate(
      candidate, system: f.capture.actor.system, visit: 30,
      capabilities: .init(
        core: .military, miningModule: false, salvageModule: true, fuelScoops: false))
    #expect(noScoops == .refused(.missingFuelScoops))
  }
}
