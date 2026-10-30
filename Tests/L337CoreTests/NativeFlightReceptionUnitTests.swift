import Foundation
import Testing

@testable import L337Core

/// Structural policy and codec fixtures only; these never mint native flight authority.
struct NativeFlightReceptionUnitTests {
  private func fixture() throws -> (
    NativeFlightReceptionState, NativeFlightReceptionSample, NativeFlightReceptionSample
  ) {
    let owner = UUID()
    let mission = UUID()
    let carrier = UUID()
    let epoch = UUID()
    let system = SystemIdentity(galaxy: 0, system: 7)
    let station = NativeMainStationIdentity(
      world: owner, system: system,
      resource: Game.worldResourceIdentity("main-station-v1:main-orbital:0:7"))
    let dock = NativeMainStationDockReceipt(
      station: station, actor: .init(system: system, visit: 1, entity: 1),
      commanderOwner: owner, sequence: 1, calendarSeconds: 0)
    let operation = try NativeFlightReception.permissionOperation(
      mission: mission, owner: owner, carrier: carrier, revision: 4, dock: dock, fit: [])
    let state = NativeFlightReceptionState(
      permission: .init(
        mission: mission, operation: operation, owner: owner, carrier: carrier,
        inventoryRevision: 4, dock: dock, fit: [], epoch: epoch))
    func sample(z: Double, time: Double) -> NativeFlightReceptionSample {
      .init(
        mission: mission, permission: operation, owner: owner, carrier: carrier,
        inventoryRevision: 4, station: station,
        player: .init(system: system, visit: 2, entity: 0),
        actor: .init(system: system, visit: 2, entity: 1),
        pose: .init(position: .init(0, 0, z)), stationPosition: .init(0, 0, 1200),
        relativeVelocity: .init(0, 0, 8), time: time, epoch: epoch)
    }
    return (state, sample(z: 0, time: 10), sample(z: 0.4, time: 10.05))
  }

  private func replacing<T: Codable>(_ value: T, key: String, with replacement: Any) throws -> T {
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    object[key] = replacement
    return try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: object))
  }

  @Test func positiveBoundedAlignedApproachRetainsExactAuthorityAndRoundTrips() throws {
    let (_, first, last) = try fixture()
    let reading = try NativeFlightReception.measure(first: first, last: last)
    #expect(reading.first == first && reading.last == last)
    #expect(NativeFlightReception.readingValid(reading))
    #expect(
      try JSONDecoder().decode(
        NativeFlightReceptionReading.self,
        from: JSONEncoder().encode(reading)) == reading)
    let forged = try replacing(reading, key: "authority", with: UUID().uuidString)
    #expect(!NativeFlightReception.readingValid(forged))
  }

  @Test func changedAuthorityClockOrUnmovedPoseCannotSupplyApproachEvidence() throws {
    let (_, first, last) = try fixture()
    for key in ["mission", "permission", "owner", "carrier", "epoch"] {
      let changed = try replacing(last, key: key, with: UUID().uuidString)
      #expect(throws: (any Error).self) {
        try NativeFlightReception.measure(first: first, last: changed)
      }
    }
    for time in [10.0, 10.2, 9.9] {
      let changed = try replacing(last, key: "time", with: time)
      #expect(throws: (any Error).self) {
        try NativeFlightReception.measure(first: first, last: changed)
      }
    }
    let samePose = try replacing(
      last, key: "pose",
      with:
        JSONSerialization.jsonObject(with: JSONEncoder().encode(first.pose)))
    #expect(throws: (any Error).self) {
      try NativeFlightReception.measure(first: first, last: samePose)
    }
    let changedFit = try replacing(last, key: "inventoryRevision", with: 5)
    #expect(throws: (any Error).self) {
      try NativeFlightReception.measure(first: first, last: changedFit)
    }
  }

  @Test func wrongAimRangeAndNonClosingMotionRefuseQualification() throws {
    let (_, first, _) = try fixture()
    for vector in [Vector3(0, 0, 900), Vector3(0, 0, 1600), Vector3(100, 0, 1200)] {
      let sample = try replacing(
        first, key: "stationPosition",
        with:
          JSONSerialization.jsonObject(with: JSONEncoder().encode(vector)))
      #expect(!sample.qualifies)
    }
    for vector in [Vector3(0, 0, 0), Vector3(0, 0, -8)] {
      let sample = try replacing(
        first, key: "relativeVelocity",
        with:
          JSONSerialization.jsonObject(with: JSONEncoder().encode(vector)))
      #expect(!sample.qualifies)
    }
  }

  @Test func receptionRequiresMeasuredSameBerthLaterDoorwayReceiptAndSeparatePermission() throws {
    let (initial, first, last) = try fixture()
    var state = initial
    let permission = state.permission
    let arrival = NativeMainStationDockReceipt(
      station: permission.dock.station, actor: last.actor, commanderOwner: permission.owner,
      sequence: 2, calendarSeconds: 5)
    #expect(!NativeFlightReception.returnReady(state, dock: arrival))
    state.reading = try NativeFlightReception.measure(first: first, last: last)
    #expect(NativeFlightReception.returnReady(state, dock: arrival))
    #expect(!NativeFlightReception.returnReady(state, dock: permission.dock))
    let foreign = try replacing(arrival, key: "commanderOwner", with: UUID().uuidString)
    #expect(!NativeFlightReception.returnReady(state, dock: foreign))
    let oldVisit = try replacing(
      arrival, key: "actor",
      with:
        JSONSerialization.jsonObject(with: JSONEncoder().encode(permission.dock.actor)))
    #expect(!NativeFlightReception.returnReady(state, dock: oldVisit))
    let (_, otherFirst, otherLast) = try fixture()
    state.reading = try NativeFlightReception.measure(first: otherFirst, last: otherLast)
    #expect(!NativeFlightReception.returnReady(state, dock: arrival))
  }

  @Test(arguments: [false, true])
  func strictLeafAndSharedSchemaPreserveLowerNativeFeatureGates(alien: Bool) throws {
    let (state, _, _) = try fixture()
    let leaf = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))
    let instance: [String: Any] = [
      "definition": NativeFlightReception.stateID,
      "digest": NativeFlightReception.digest, "savedFlightReception": leaf,
    ]
    func bytes(_ value: [String: Any]) throws -> Data {
      try JSONSerialization.data(withJSONObject: ["instances": ["tutorial": value]])
    }
    let schema = alien ? 60 : 59
    try ScriptSaveJSONPreflight.validateRepairLoopFields(
      try bytes(instance), part: .missions, schema: schema)
    #expect(throws: (any Error).self) {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(
        try bytes(instance), part: .missions, schema: schema - 2)
    }
    var missing = instance
    missing.removeValue(forKey: "savedFlightReception")
    #expect(throws: (any Error).self) {
      try NativeFlightReceptionSave.validateFields(
        try bytes(missing), part: .missions, schema: schema)
    }
    var unknown = try #require(leaf as? [String: Any])
    unknown["invented"] = true
    var forged = instance
    forged["savedFlightReception"] = unknown
    #expect(throws: (any Error).self) {
      try NativeFlightReceptionSave.validateFields(
        try bytes(forged), part: .missions, schema: schema)
    }
    var wrongDigest = instance
    wrongDigest["digest"] = String(repeating: "0", count: 64)
    #expect(throws: (any Error).self) {
      try NativeFlightReceptionSave.validateFields(
        try bytes(wrongDigest), part: .missions, schema: schema)
    }
    var nested = try #require(leaf as? [String: Any])
    var permission = try #require(nested["permission"] as? [String: Any])
    permission["unexpected"] = 1
    nested["permission"] = permission
    forged["savedFlightReception"] = nested
    #expect(throws: (any Error).self) {
      try NativeFlightReceptionSave.validateFields(
        try bytes(forged), part: .missions, schema: schema)
    }
    let lower = NativeFlightReceptionSave.lowerSchema(schema)
    #expect(lower == (alien ? 58 : 57))
    #expect(
      NativeMeasuredExtractionSave.lowerSchema(WayfarerFieldReliefSave.lowerSchema(lower))
        == (alien ? 54 : 53))
    #expect(NativeFlightReceptionSave.lowerSchema(nil) == nil)
    #expect(NativeFlightReceptionSave.lowerSchema(53) == 53)
  }

  @Test func bundledLessonPinsCurrentFitZeroPaymentAndClosedNativeDeclaration() throws {
    let pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledFlightReceptionDirectory)
    #expect(pack.digest == NativeFlightReception.digest)
    #expect(pack.manifest.stateID == NativeFlightReception.stateID)
    #expect(pack.missingCapabilities.isEmpty && pack.manifest.trial == nil)
    #expect(pack.manifest.mission.milestones.count == 3)
    var mixed = pack.manifest
    mixed.measuredExtraction = try ScriptPackLibrary.read(
      ScriptPackLibrary.bundledMeasuredExtractionDirectory
    ).manifest.measuredExtraction
    #expect(throws: (any Error).self) { try ScriptPackLibrary.validateFlightReception(mixed) }
    mixed = pack.manifest
    mixed.flightReception = nil
    #expect(throws: (any Error).self) { try ScriptPackLibrary.validateFlightReception(mixed) }
  }
}
