import Foundation
import Testing

@testable import EliteCore

/// Independent copy of the original eight-field wire shape, with its original synthesized codec.
private struct OriginalCustodyWireShape: Codable, Equatable {
  let owner: UUID
  var revision: UInt64
  var stationJourney: NativeStationPassengerJourneyState?
  var outlookJourney: NativeOrbitalOutlookJourneyState?
  var originalRescue: NativeOriginalRescueJourneyState?
  var orbitalEvacuation: NativeOriginalEvacuationState?
  var admissions: [NativePeopleAdmission]
  var transfers: [NativePeopleTransferReceipt]

  init(_ state: NativePeopleCustodyState) {
    owner = state.owner
    revision = state.revision
    stationJourney = state.stationJourney
    outlookJourney = state.outlookJourney
    originalRescue = state.originalRescue
    orbitalEvacuation = state.orbitalEvacuation
    admissions = state.admissions
    transfers = state.transfers
  }
}

struct NativePeopleCustodyValueTests {
  private let owner = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
  private let token = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

  @Test(arguments: [
    "owner", "revision", "stationJourney", "outlookJourney", "originalRescue",
    "orbitalEvacuation", "admissions", "transfers",
  ])
  func equalityAndSettersPreserveEveryOriginalField(field: String) throws {
    let original = fixture()
    let encoder = sortedEncoder()
    let bytes = try encoder.encode(original)
    var changed = original
    switch field {
    case "owner":
      var object = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
      object["owner"] = "00000000-0000-0000-0000-000000000003"
      changed = try JSONDecoder().decode(
        NativePeopleCustodyState.self, from: JSONSerialization.data(withJSONObject: object))
    case "revision": changed.revision = original.revision + 1
    case "stationJourney": changed.stationJourney = nil
    case "outlookJourney": changed.outlookJourney = nil
    case "originalRescue": changed.originalRescue = nil
    case "orbitalEvacuation": changed.orbitalEvacuation = nil
    case "admissions": changed.admissions = []
    case "transfers": changed.transfers = []
    default:
      Issue.record(Comment(rawValue: "Unrecognised custody field: " + field))
      return
    }
    #expect(changed != original && original != changed)
    #expect(try encoder.encode(original) == bytes)
    #expect(try backingIdentity(changed) != backingIdentity(original))
    #expect(try encoder.encode(changed) == encoder.encode(OriginalCustodyWireShape(changed)))
    #expect(try JSONDecoder().decode(NativePeopleCustodyState.self, from: bytes) == original)
  }

  @Test(arguments: [
    "revision", "stationJourney", "outlookJourney", "originalRescue", "orbitalEvacuation",
    "admissions", "transfers",
  ])
  func nestedAndArrayModifyDetachAllSevenMutableFields(field: String) throws {
    let original = fixture()
    let bytes = try sortedEncoder().encode(original)
    var changed = original
    #expect(try backingIdentity(changed) == backingIdentity(original))
    switch field {
    case "revision": changed.revision += 1
    case "stationJourney": changed.stationJourney?.terminalOperation = token
    case "outlookJourney": changed.outlookJourney?.terminalOperation = token
    case "originalRescue": changed.originalRescue?.terminalOperation = token
    case "orbitalEvacuation": changed.orbitalEvacuation?.terminalOperation = token
    case "admissions": changed.admissions.append(changed.admissions[0])
    case "transfers": changed.transfers.append(changed.transfers[0])
    default:
      Issue.record(Comment(rawValue: "Unrecognised mutable custody field: " + field))
      return
    }
    #expect(changed != original)
    #expect(try backingIdentity(changed) != backingIdentity(original))
    #expect(try sortedEncoder().encode(original) == bytes)
  }

  @Test func readsAndUniqueMutationKeepBackingAndLayoutSmall() throws {
    #expect(MemoryLayout<NativePeopleCustodyState>.size == MemoryLayout<UnsafeRawPointer>.size)
    #expect(MemoryLayout<NativePeopleCustodyState?>.size <= 2 * MemoryLayout<UnsafeRawPointer>.size)
    var unique = fixture()
    let identity = try backingIdentity(unique)
    _ = OriginalCustodyWireShape(unique)
    _ = try sortedEncoder().encode(unique)
    #expect(try backingIdentity(unique) == identity)
    unique.revision += 1
    #expect(try backingIdentity(unique) == identity)
    let retained = unique
    let bytes = try sortedEncoder().encode(retained)
    unique.originalRescue?.terminalOperation = token
    let detached = try backingIdentity(unique)
    #expect(detached != identity)
    unique.admissions.append(unique.admissions[0])
    #expect(try backingIdentity(unique) == detached)
    #expect(try sortedEncoder().encode(retained) == bytes)
  }

  @Test func originalFlatLegacyBytesAndAllEightFieldCodecRemainExact() throws {
    let bytes = Data(
      #"{"admissions":[],"owner":"00000000-0000-0000-0000-000000000001","revision":0,"transfers":[]}"#
        .utf8)
    let empty = try JSONDecoder().decode(NativePeopleCustodyState.self, from: bytes)
    #expect(empty == NativePeopleCustodyState(owner: owner))
    #expect(try sortedEncoder().encode(empty) == bytes)
    let full = fixture()
    let originalBytes = try sortedEncoder().encode(OriginalCustodyWireShape(full))
    #expect(try sortedEncoder().encode(full) == originalBytes)
    let restored = try JSONDecoder().decode(NativePeopleCustodyState.self, from: originalBytes)
    #expect(restored == full)
    #expect(try sortedEncoder().encode(restored) == originalBytes)
    let root = try #require(JSONSerialization.jsonObject(with: originalBytes) as? [String: Any])
    #expect(
      Set(root.keys) == [
        "owner", "revision", "stationJourney", "outlookJourney", "originalRescue",
        "orbitalEvacuation",
        "admissions", "transfers",
      ])
    for field in ["admissions", "transfers"] {
      var oversized = root
      oversized[field] = Array(
        repeating: [String: String](), count: NativePeopleCustodyState.maximumPeople + 1)
      do {
        _ = try JSONDecoder().decode(
          NativePeopleCustodyState.self, from: JSONSerialization.data(withJSONObject: oversized))
        Issue.record(Comment(rawValue: "Oversized custody collection decoded: " + field))
      } catch SaveError.invalidCommander {
        // The original bounded decoder must reject the announced count before reading entries.
      }
    }
  }

  @Test func memberEqualityKeepsNaNAndSignedZeroSemantics() {
    let nan = fixture(clock: .nan)
    #expect(nan != nan)
    #expect(fixture(clock: 0) == fixture(clock: -0.0))
  }

  private func sortedEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return encoder
  }

  private func backingIdentity(_ state: NativePeopleCustodyState) throws -> ObjectIdentifier {
    let child = try #require(Mirror(reflecting: state).children.first)
    #expect(child.label == "storage")
    return ObjectIdentifier(child.value as AnyObject)
  }

  /// Raw records exercise storage and codec behavior, without claiming valid source authority.
  private func fixture(clock: Double = 0) -> NativePeopleCustodyState {
    var state = NativePeopleCustodyState(owner: owner)
    state.revision = 1
    addStationJourney(to: &state)
    addOutlookJourney(to: &state)
    addOriginalRescue(to: &state, clock: clock)
    addEvacuation(to: &state)
    let actor = ActorIdentity(system: .init(galaxy: 0, system: 7), visit: 1, entity: 0)
    let person = NativePersonReference.rescue(
      .init(
        owner: owner, batch: NativeOriginalRescueJourney.batch, ordinal: 0))
    state.admissions = [
      .init(
        person: person, origin: .originalRescuedPod, operation: token, actor: actor,
        collector: actor,
        owner: owner, hull: token, tool: token, inventoryRevision: 1, physicalTime: 0, epoch: token,
        revision: 1)
    ]
    state.transfers = [
      .init(
        operation: token, members: [person], kind: .care, dock: nil, collector: actor, owner: owner,
        physicalTime: 0, calendarSeconds: 0, beforeCash: 0, afterCash: 0, beforeSlaves: 0,
        afterSlaves: 0, price: 0, epoch: token, revision: 1)
    ]
    return state
  }

  private func dock() -> NativeMainStationDockReceipt {
    NativeWayfarerInductionUnitTests().dock(owner: owner, system: 7, visit: 1, sequence: 1)
  }

  @inline(never)
  private func addStationJourney(to state: inout NativePeopleCustodyState) {
    let dock = dock()
    state.stationJourney = .init(
      owner: owner,
      definition: .init(
        batch: NativeStationPassengerJourney.batch, sourceGalaxy: 0, sourceSystem: 7,
        destinationGalaxy: 0, destinationSystem: 185, people: []),
      version: "1", digest: NativeStationPassengerJourney.digest, source: dock.station,
      registration: dock, stationActor: dock.actor, people: [])
  }

  @inline(never)
  private func addOutlookJourney(to state: inout NativePeopleCustodyState) {
    let dock = dock()
    state.outlookJourney = .init(
      owner: owner,
      definition: .init(
        batch: NativeOrbitalOutlookJourney.batch, sourceGalaxy: 0, sourceSystem: 7,
        destinationGalaxy: 0, destinationSystem: 7, itinerary: [], people: []),
      version: "1", digest: NativeOrbitalOutlookJourney.digest, source: dock.station,
      registration: dock, stationActor: dock.actor, people: [])
  }

  @inline(never)
  private func addOriginalRescue(to state: inout NativePeopleCustodyState, clock: Double) {
    let dock = dock()
    state.originalRescue = .init(
      owner: owner,
      definition: .init(
        batch: NativeOriginalRescueJourney.batch, sourceGalaxy: 0, sourceSystem: 85,
        destinationGalaxy: 0, destinationSystem: 241, people: []),
      version: "1", digest: NativeOriginalRescueJourney.digest, registration: dock,
      registeredAt: clock, inventoryRevision: 1, operation: token, mission: token, carrier: token,
      reservedBerths: [])
  }

  @inline(never)
  private func addEvacuation(to state: inout NativePeopleCustodyState) {
    let dock = dock()
    state.orbitalEvacuation = .init(
      owner: owner,
      definition: .init(
        batch: NativeOriginalEvacuation.batch, sourceGalaxy: 0, sourceSystem: 7,
        destinationGalaxy: 0, destinationSystem: 185, people: []),
      version: "1", digest: NativeOriginalEvacuation.digest, source: dock.station,
      registration: dock, stationActor: dock.actor, people: [])
  }
}
