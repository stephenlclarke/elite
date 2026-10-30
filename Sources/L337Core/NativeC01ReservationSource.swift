import Foundation

/// Explicit L337 case data, issued by the native commission rather than inferred from scans.
struct NativeC01ReservationTerms: Codable, Sendable, Equatable {
  let declaration: String
  let mission: UUID
  let permission: UUID
  let owner: UUID
  let epoch: Double
  let firstSequence: UInt64
  init(
    mission: UUID, permission: UUID, owner: UUID, epoch: Double, firstSequence: UInt64,
    declaration: String = NativeC01ReservationSource.declaration
  ) {
    self.declaration = declaration
    self.mission = mission
    self.permission = permission
    self.owner = owner
    self.epoch = epoch
    self.firstSequence = firstSequence
  }
  var source: UUID { ScriptIdentity.uuid("c01-enmadan-booking-source-v1:\(owner):\(permission)") }
  func identity(_ role: String) -> UUID { ScriptIdentity.uuid("\(source):\(role)") }
  var valid: Bool {
    declaration == NativeC01ReservationSource.declaration
      && epoch.isFinite && (0...(1e12 - 750)).contains(epoch)
      && firstSequence > 0 && firstSequence < UInt64(Int64.max) - 5
  }
}

struct NativeC01ReservationBalances: Codable, Sendable, Equatable {
  var clinic = 500
  var freight = 500
  var contractor = 0
  var conserved: Bool {
    (0...1000).contains(clinic) && (0...1000).contains(freight)
      && (0...1000).contains(contractor) && clinic + freight + contractor == 1000
  }
}
struct NativeC01ReservationWindow: Codable, Sendable, Equatable {
  let start: Double
  let end: Double
  func shifted(_ offset: Double) -> Self { .init(start: start + offset, end: end + offset) }
  func overlap(_ other: Self) -> Double { max(0, min(end, other.end) - max(start, other.start)) }
}
struct NativeC01ReservationClaim: Codable, Sendable, Equatable {
  let id: UUID
  let operation: UUID
  let customer: UUID
  let certificate: UUID
  let certificateFingerprint: String
  let trueWindow: NativeC01ReservationWindow
  let localWindow: NativeC01ReservationWindow
  let sequence: UInt64
}
struct NativeC01ReservationPayment: Codable, Sendable, Equatable {
  let operation: UUID
  let claim: UUID
  let source: UUID
  let owner: UUID
  let customer: UUID
  let recipient: UUID
  let sequence: UInt64
  let physicalTime: Double
  let amount: Int
  let before: NativeC01ReservationBalances
  let after: NativeC01ReservationBalances
}
struct NativeC01ReservationProjection: Codable, Sendable, Equatable {
  var certificateIssued = false
  var allocation: UUID?
  var claims: [NativeC01ReservationClaim] = []
  var payments: [NativeC01ReservationPayment] = []
  var balances = NativeC01ReservationBalances()
  var availableUnits: Int { certificateIssued && allocation == nil ? 1 : 0 }
}
struct NativeC01ReservationEvent: Codable, Sendable, Equatable {
  enum Kind: String, Codable, Sendable, CaseIterable {
    case issue, reserveClinic, payClinic, contractorPromise, payFreight
  }
  let source: UUID
  let owner: UUID
  let operation: UUID
  let principal: UUID
  let kind: Kind
  let sequence: UInt64
  let physicalTime: Double
  let before: String
  let after: String
  let payment: NativeC01ReservationPayment?
}
struct NativeC01ClockContents: Codable, Sendable, Equatable {
  let version: Int
  let source: UUID
  let permission: UUID
  let lineage: UUID
  let ordinal: Int
  let claim: UUID
  let payment: UUID
  let certificate: UUID
  let certificateFingerprint: String
  let prefixRevision: Int
  let prefixFingerprint: String
  let reservationCounter: Int
  let offset: Double
  let localWindow: NativeC01ReservationWindow
}
struct NativeC01RecorderCalibration: Codable, Sendable, Equatable {
  let clockLineage: UUID
  let clockContents: String
  let offset: Double
}
struct NativeC01RecorderContents: Codable, Sendable, Equatable {
  let version: Int
  let source: UUID
  let permission: UUID
  let original: UUID
  let ledgerFingerprint: String
  let certificate: UUID
  let certificateFingerprint: String
  let controls: [UUID]
  let calibrations: [NativeC01RecorderCalibration]
}

extension NativeC01RecorderContents {
  private enum CodingKeys: String, CodingKey {
    case version, source, permission, original, ledgerFingerprint, certificate
    case certificateFingerprint, controls, calibrations
  }
  init(from decoder: any Decoder) throws {
    try NativeUtilityCoding.require(
      decoder,
      [
        "version", "source", "permission", "original", "ledgerFingerprint", "certificate",
        "certificateFingerprint", "controls", "calibrations",
      ])
    let c = try decoder.container(keyedBy: CodingKeys.self)
    version = try c.decode(Int.self, forKey: .version)
    source = try c.decode(UUID.self, forKey: .source)
    permission = try c.decode(UUID.self, forKey: .permission)
    original = try c.decode(UUID.self, forKey: .original)
    ledgerFingerprint = try c.decode(String.self, forKey: .ledgerFingerprint)
    certificate = try c.decode(UUID.self, forKey: .certificate)
    certificateFingerprint = try c.decode(String.self, forKey: .certificateFingerprint)
    controls = try NativeUtilityCoding.array(UUID.self, key: .controls, container: c, limit: 2)
    calibrations = try NativeUtilityCoding.array(
      NativeC01RecorderCalibration.self, key: .calibrations, container: c, limit: 2)
  }
}

/// Immutable source facts. Construction/replay performs each finite native operation; no paid flag.
/// Live installation is restricted separately to the genuine fresh commission publication.
final class NativeC01ReservationSource: Codable, Sendable, Equatable {
  static let declaration = "c01-reservation-case-v1"
  let terms: NativeC01ReservationTerms
  let events: [NativeC01ReservationEvent]
  let clocks: [NativeC01ClockContents]
  let recorder: NativeC01RecorderContents
  private let retainedProjection: NativeC01ReservationProjection
  private let retainedFingerprint: String
  let recorderFingerprint: String
  let clockFingerprints: [String]
  var fingerprint: String { retainedFingerprint }
  var revision: Int { events.count }
  var lastSequence: UInt64 { terms.firstSequence + 4 }
  var unit: UUID { terms.identity("slot-001") }
  var certificate: UUID { terms.identity("certificate-001") }
  var portAuthority: UUID { terms.identity("port-authority") }
  var contractor: UUID { terms.identity("contractor") }
  var clinicCustomer: UUID { terms.identity("clinic-booking-customer") }
  var freightCustomer: UUID { terms.identity("freight-booking-customer") }
  var sorel: UUID { terms.identity("sorel-auditor") }
  var projection: NativeC01ReservationProjection { retainedProjection }

  init(permission: NativeGlassMeridianPermission, firstSequence: UInt64) throws {
    let terms = NativeC01ReservationTerms(
      mission: permission.mission,
      permission: permission.operation, owner: permission.owner,
      epoch: permission.physicalTime, firstSequence: firstSequence)
    let result = try Self.project(terms)
    self.terms = terms
    retainedProjection = result.projection
    events = result.events
    clocks = result.clocks
    recorder = result.recorder
    recorderFingerprint = try Self.hash(result.recorder)
    clockFingerprints = result.recorder.calibrations.map(\.clockContents)
    retainedFingerprint = try Self.hash(
      Snapshot(terms: terms, events: events, clocks: clocks, recorder: recorder))
  }

  static func hash<T: Encodable>(_ value: T) throws -> String {
    let object = try JSONSerialization.jsonObject(
      with: JSONEncoder().encode(value), options: [.fragmentsAllowed])
    return ScriptPackLibrary.hash(
      try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .fragmentsAllowed]))
  }
  static func certificateFingerprint(_ terms: NativeC01ReservationTerms) throws -> String {
    struct Certificate: Encodable {
      let declaration: String
      let source: UUID
      let unit: UUID
      let certificate: UUID
      let issuer: UUID
      let holder: UUID
      let lane: SystemIdentity
    }
    return try hash(
      Certificate(
        declaration: declaration, source: terms.source,
        unit: terms.identity("slot-001"), certificate: terms.identity("certificate-001"),
        issuer: terms.identity("port-authority"), holder: terms.identity("clinic-booking-customer"),
        lane: NativeGlassMeridian.objective))
  }
  private struct Result: Sendable {
    let projection: NativeC01ReservationProjection
    let events: [NativeC01ReservationEvent]
    let clocks: [NativeC01ClockContents]
    let recorder: NativeC01RecorderContents
  }
  private struct Snapshot: Codable {
    let terms: NativeC01ReservationTerms
    let events: [NativeC01ReservationEvent]
    let clocks: [NativeC01ClockContents]
    let recorder: NativeC01RecorderContents
  }

  private static func project(_ terms: NativeC01ReservationTerms) throws -> Result {
    guard terms.valid else { throw SaveError.invalidCommander }
    var state = NativeC01ReservationProjection()
    var events: [NativeC01ReservationEvent] = []
    for kind in NativeC01ReservationEvent.Kind.allCases {
      let event = try applying(kind, terms: terms, state: &state, previous: events)
      events.append(event)
    }
    guard state.certificateIssued, state.allocation == terms.identity("claim-001"),
      state.availableUnits == 0, state.claims.count == 2, state.payments.count == 2,
      state.balances == .init(clinic: 0, freight: 0, contractor: 1000)
    else { throw SaveError.invalidCommander }
    let certificate = try certificateFingerprint(terms)
    var clocks: [NativeC01ClockContents] = []
    for ordinal in 0..<2 {
      let claim = state.claims[ordinal]
      let prefix = events[ordinal == 0 ? 2 : 4]
      clocks.append(
        .init(
          version: 1, source: terms.source, permission: terms.permission,
          lineage: NativeGlassMeridian.actor(mission: terms.mission, ordinal: ordinal),
          ordinal: ordinal,
          claim: claim.id, payment: state.payments[ordinal].operation,
          certificate: claim.certificate, certificateFingerprint: certificate,
          prefixRevision: ordinal == 0 ? 3 : 5, prefixFingerprint: prefix.after,
          reservationCounter: ordinal + 1, offset: ordinal == 0 ? 0 : 60,
          localWindow: claim.localWindow))
    }
    let recorder = NativeC01RecorderContents(
      version: 1, source: terms.source,
      permission: terms.permission,
      original: NativeC01Surveyor.actor(
        mission: terms.mission, alias: NativeC01Surveyor.aliases[1]),
      ledgerFingerprint: try hash(state), certificate: terms.identity("certificate-001"),
      certificateFingerprint: certificate, controls: state.claims.map(\.operation),
      calibrations: try clocks.enumerated().map { index, clock in
        .init(
          clockLineage: clock.lineage, clockContents: try hash(clock), offset: index == 0 ? 0 : 60)
      })
    return .init(projection: state, events: events, clocks: clocks, recorder: recorder)
  }

  /// A duplicate, reordered or already-paid native operation cannot debit or allocate again.
  static func applying(
    _ kind: NativeC01ReservationEvent.Kind, terms: NativeC01ReservationTerms,
    state: inout NativeC01ReservationProjection, previous: [NativeC01ReservationEvent]
  ) throws -> NativeC01ReservationEvent {
    guard terms.valid, previous.count < 5,
      NativeC01ReservationEvent.Kind.allCases[previous.count] == kind,
      previous.allSatisfy({ $0.source == terms.source && $0.owner == terms.owner }),
      state.claims.count <= 2, state.payments.count <= 2, state.balances.conserved
    else { throw SaveError.invalidCommander }
    var next = state
    let before = try hash(state)
    guard previous.last?.after == nil || previous.last?.after == before,
      previous.enumerated().allSatisfy({ index, receipt in
        receipt.kind == NativeC01ReservationEvent.Kind.allCases[index]
          && receipt.operation == terms.identity("event-" + receipt.kind.rawValue)
          && receipt.sequence == terms.firstSequence + UInt64(index)
          && receipt.physicalTime == terms.epoch
      }),
      zip(previous, previous.dropFirst()).allSatisfy({ $0.after == $1.before })
    else { throw SaveError.invalidCommander }
    let sequence = terms.firstSequence + UInt64(previous.count)
    let operation = terms.identity("event-" + kind.rawValue)
    guard !previous.contains(where: { $0.operation == operation }) else {
      throw SaveError.invalidCommander
    }
    let principal: UUID
    var payment: NativeC01ReservationPayment?
    switch kind {
    case .issue:
      guard !next.certificateIssued, next.allocation == nil, next.claims.isEmpty,
        next.payments.isEmpty,
        next.balances == NativeC01ReservationBalances()
      else { throw SaveError.invalidCommander }
      next.certificateIssued = true
      principal = terms.identity("port-authority")
    case .reserveClinic, .contractorPromise:
      let original = kind == .reserveClinic
      guard next.certificateIssued,
        next.claims.count == (original ? 0 : 1), next.payments.count == (original ? 0 : 1),
        original ? next.availableUnits == 1 : next.availableUnits == 0,
        original ? next.allocation == nil : next.allocation == terms.identity("claim-001")
      else { throw SaveError.invalidCommander }
      let claim = terms.identity(original ? "claim-001" : "claim-002")
      let window = NativeC01ReservationWindow(
        start: terms.epoch + (original ? 600 : 630),
        end: terms.epoch + (original ? 660 : 690))
      let customer = terms.identity(
        original ? "clinic-booking-customer" : "freight-booking-customer")
      next.claims.append(
        .init(
          id: claim, operation: operation, customer: customer,
          certificate: terms.identity("certificate-001"),
          certificateFingerprint: try certificateFingerprint(terms),
          trueWindow: window, localWindow: window.shifted(original ? 0 : 60), sequence: sequence))
      if original { next.allocation = claim }
      principal = original ? customer : terms.identity("contractor")
    case .payClinic, .payFreight:
      let original = kind == .payClinic
      let index = original ? 0 : 1
      guard next.claims.count == index + 1, next.payments.count == index,
        next.allocation == terms.identity("claim-001"),
        original ? next.balances.clinic == 500 : next.balances.freight == 500
      else { throw SaveError.invalidCommander }
      let balances = next.balances
      if original { next.balances.clinic -= 500 } else { next.balances.freight -= 500 }
      next.balances.contractor += 500
      principal = next.claims[index].customer
      payment = .init(
        operation: operation, claim: next.claims[index].id,
        source: terms.source, owner: terms.owner, customer: principal,
        recipient: terms.identity("contractor"), sequence: sequence, physicalTime: terms.epoch,
        amount: 500, before: balances, after: next.balances)
      next.payments.append(payment!)
    }
    guard next.balances.conserved else { throw SaveError.invalidCommander }
    let receipt = NativeC01ReservationEvent(
      source: terms.source, owner: terms.owner,
      operation: operation, principal: principal, kind: kind, sequence: sequence,
      physicalTime: terms.epoch, before: before, after: try hash(next), payment: payment)
    state = next
    return receipt
  }

  private enum CodingKeys: String, CodingKey { case terms, events, clocks, recorder }
  func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(terms, forKey: .terms)
    try c.encode(events, forKey: .events)
    try c.encode(clocks, forKey: .clocks)
    try c.encode(recorder, forKey: .recorder)
  }
  init(from decoder: any Decoder) throws {
    try NativeUtilityCoding.require(decoder, ["terms", "events", "clocks", "recorder"])
    let c = try decoder.container(keyedBy: CodingKeys.self)
    terms = try c.decode(NativeC01ReservationTerms.self, forKey: .terms)
    events = try NativeUtilityCoding.array(
      NativeC01ReservationEvent.self, key: .events, container: c, limit: 5)
    clocks = try NativeUtilityCoding.array(
      NativeC01ClockContents.self, key: .clocks, container: c, limit: 2)
    recorder = try c.decode(NativeC01RecorderContents.self, forKey: .recorder)
    let expected = try Self.project(terms)
    retainedProjection = expected.projection
    recorderFingerprint = try Self.hash(expected.recorder)
    clockFingerprints = expected.recorder.calibrations.map(\.clockContents)
    guard events == expected.events, clocks == expected.clocks, recorder == expected.recorder else {
      throw SaveError.invalidCommander
    }
    retainedFingerprint = try Self.hash(
      Snapshot(terms: terms, events: events, clocks: clocks, recorder: recorder))
  }
  static func decodeClosed(_ data: Data) throws -> NativeC01ReservationSource {
    guard data.count <= 65_536 else { throw SaveError.invalidCommander }
    try ScriptSaveJSONPreflight.validate(data)
    let source = try JSONDecoder().decode(Self.self, from: data)
    guard let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      (raw as NSDictionary).isEqual(
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(source)))
    else { throw SaveError.invalidCommander }
    return source
  }
  static func == (lhs: NativeC01ReservationSource, rhs: NativeC01ReservationSource) -> Bool {
    lhs.terms == rhs.terms && lhs.events == rhs.events && lhs.clocks == rhs.clocks
      && lhs.recorder == rhs.recorder
  }
}
