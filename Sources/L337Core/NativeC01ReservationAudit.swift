import Foundation

/// Computed observations, never a caller-supplied completion or anomaly flag.
struct NativeC01ReservationFindings: Codable, Sendable, Equatable {
  let certificate: UUID
  let claims: [UUID]
  let payments: [UUID]
  let trueOverlap: Double
  let concealedClockOffset: Double
  let reservationCounterDifference: Int
}

enum NativeC01ReservationComparison {
  static func compare(
    source: NativeC01ReservationSource, clocks: [NativeC01ClockContents],
    recorder: NativeC01RecorderContents
  ) throws -> NativeC01ReservationFindings {
    guard clocks == source.clocks, recorder == source.recorder,
      clocks.count == 2, recorder.calibrations.count == 2,
      source.events.count == 5, source.revision == 5,
      recorder.source == source.terms.source, recorder.permission == source.terms.permission,
      recorder.original
        == NativeC01Surveyor.actor(
          mission: source.terms.mission, alias: NativeC01Surveyor.aliases[1]),
      recorder.ledgerFingerprint == source.events.last?.after,
      recorder.certificate == source.certificate,
      source.projection.claims.count == 2, source.projection.payments.count == 2,
      source.projection.allocation == source.projection.claims[0].id,
      source.projection.availableUnits == 0,
      source.projection.balances
        == NativeC01ReservationBalances(clinic: 0, freight: 0, contractor: 1000)
    else { throw SaveError.invalidCommander }
    let claims = source.projection.claims
    let payments = source.projection.payments
    guard Set(claims.map(\.id)).count == 2, Set(payments.map(\.operation)).count == 2,
      claims[0].certificate == claims[1].certificate,
      claims[0].certificate == source.certificate,
      claims[0].certificateFingerprint == claims[1].certificateFingerprint,
      recorder.certificateFingerprint == claims[0].certificateFingerprint,
      recorder.controls == claims.map(\.operation)
    else { throw SaveError.invalidCommander }
    var corrected: [NativeC01ReservationWindow] = []
    for index in 0..<2 {
      let claim = claims[index]
      let payment = payments[index]
      let clock = clocks[index]
      let calibration = recorder.calibrations[index]
      guard clock.ordinal == index, clock.source == source.terms.source,
        clock.permission == source.terms.permission,
        clock.lineage == NativeGlassMeridian.actor(mission: source.terms.mission, ordinal: index),
        clock.claim == claim.id, clock.payment == payment.operation,
        clock.certificate == claim.certificate,
        clock.certificateFingerprint == claim.certificateFingerprint,
        clock.localWindow == claim.localWindow,
        calibration.clockLineage == clock.lineage,
        calibration.clockContents == source.clockFingerprints[index],
        calibration.offset == clock.offset,
        payment.claim == claim.id, payment.customer == claim.customer,
        payment.source == source.terms.source, payment.owner == source.terms.owner,
        payment.recipient == source.contractor, payment.amount == 500,
        payment.before.conserved, payment.after.conserved,
        payment.after.contractor - payment.before.contractor == payment.amount,
        clock.prefixRevision == (index == 0 ? 3 : 5),
        clock.prefixFingerprint == source.events[clock.prefixRevision - 1].after
      else { throw SaveError.invalidCommander }
      let window = clock.localWindow.shifted(-calibration.offset)
      // Absolute native clocks are floating-point values. Correcting a +60s
      // offset can cross a binary exponent boundary; allow only arithmetic ULPs.
      let tolerance =
        8
        * max(
          window.start.ulp, window.end.ulp, claim.trueWindow.start.ulp, claim.trueWindow.end.ulp)
      guard abs(window.start - claim.trueWindow.start) <= tolerance,
        abs(window.end - claim.trueWindow.end) <= tolerance
      else { throw SaveError.invalidCommander }
      corrected.append(window)
    }
    let overlap = corrected[0].overlap(corrected[1])
    let offset = recorder.calibrations[1].offset - recorder.calibrations[0].offset
    let counter = clocks[1].reservationCounter - clocks[0].reservationCounter
    let tolerance = 8 * (corrected.flatMap { [$0.start.ulp, $0.end.ulp] }.max() ?? 0)
    let seconds = overlap.rounded()
    guard seconds == 30, abs(overlap - seconds) <= tolerance, offset == 60, counter == 1,
      clocks[0].localWindow.overlap(clocks[1].localWindow) == 0
    else { throw SaveError.invalidCommander }
    return .init(
      certificate: source.certificate, claims: claims.map(\.operation),
      payments: payments.map(\.operation), trueOverlap: seconds,
      concealedClockOffset: offset, reservationCounterDifference: counter)
  }
}

struct NativeC01ReservationReadPin: Codable, Sendable, Equatable {
  let mission: UUID
  let missionRevision: UInt64
  let owner: UUID
  let source: UUID
  let sourceRevision: Int
  let sourceFingerprint: String
  let recorderContents: String
  let captureOperation: UUID
  let recorderActor: ActorIdentity
  let readings: [UUID]
  let clockContents: [String]
  let dock: NativeMainStationDockReceipt
  let epoch: UUID
  let carrier: UUID
  let inventoryRevision: UInt64
}

/// Historical Codable facts are not an input to any live confirmation API.
final class NativeC01ReservationAuditReceipt: Codable, Sendable, Equatable {
  static let target = "sorel-ledger-audit"
  static let localStage = "audit-reservations"
  static let stage = "l337.glass-meridian/" + localStage
  static let event = "mission_contact_confirmed"
  let operation: UUID
  let sequence: UInt64
  let physicalTime: Double
  let pin: NativeC01ReservationReadPin
  let auditor: UUID
  let ledgerOwner: UUID
  let consent: UUID
  let target: String
  let stage: String
  let event: String
  let findings: NativeC01ReservationFindings

  private init(
    sequence: UInt64, time: Double, pin: NativeC01ReservationReadPin,
    source: NativeC01ReservationSource, consent: UUID, findings: NativeC01ReservationFindings
  ) {
    self.operation = Self.operation(source: source.terms.source)
    self.sequence = sequence
    physicalTime = time
    self.pin = pin
    auditor = source.sorel
    ledgerOwner = source.portAuthority
    self.consent = consent
    target = Self.target
    stage = Self.stage
    event = Self.event
    self.findings = findings
  }

  static func operation(source: UUID) -> UUID {
    ScriptIdentity.uuid("c01-enmadan-audit-receipt-v1:\(source)")
  }

  /// The two read authorities stay private and can only be obtained from the current native game.
  private struct LedgerRead {
    let source: NativeC01ReservationSource
    let arrival: NativeMainStationArrivalContext
    init(_ game: borrowing Game) throws {
      guard !game.paused, game.trialTitle == nil, !game.isMissionTrial, game.energy > 0,
        game.scriptDurabilityAvailable, game.commander.equipmentStateValid,
        let tonnes = game.commander.checkedCargoTonnes, tonnes <= game.commander.tradeCargoCapacity,
        game.systemIdentity == .init(galaxy: 0, system: 0),
        let pack = game.glassMeridianPack,
        let mission = game.glassMeridianMission, mission.outcome == .active,
        mission.definition == pack.manifest.stateID, mission.version == pack.manifest.version,
        mission.digest == pack.digest, mission.suspension == nil,
        let state = mission.savedGlassMeridian,
        let source = state.reservationCase?.source,
        source.terms.owner == game.commander.equipmentOwnerID,
        let dock = game.commander.nativeStations?.currentMainDock,
        let arrival = game.nativeMainStationArrivalContext(for: dock.station),
        game.acceptsNativeMainStationArrivalContext(arrival),
        arrival.receipt == dock, dock.station.system == .init(galaxy: 0, system: 0),
        NativeC01ReservationAuditSave.sourceValid(mission, commander: game.commander)
      else { throw SaveError.invalidCommander }
      self.source = source
      self.arrival = arrival
    }
  }

  private struct RecorderRead {
    let contents: NativeC01RecorderContents
    let capture: NativeC01SurveyorCapture
    let readings: [NativeGlassMeridianReading]
    let clocks: [NativeC01ClockContents]
    init(_ game: borrowing Game, source: NativeC01ReservationSource) throws {
      guard let mission = game.glassMeridianMission,
        let state = mission.savedGlassMeridian,
        let surveyor = state.surveyor, surveyor.held, let capture = surveyor.capture,
        NativeGlassMeridian.readingsValid(state), NativeGlassMeridian.lossesValid(state),
        NativeC01SurveyorSave.valid(mission, commander: game.commander),
        state.readings.count == 2, source.terms.epoch <= surveyor.source.physicalTime,
        source.terms.epoch <= capture.startTime,
        capture.marker.identity == source.recorder.original,
        capture.marker.body.physical != nil,
        Set(state.readings.map { $0.reading.ordinal }) == [0, 1],
        state.readings.allSatisfy({ source.terms.epoch <= $0.reading.start })
      else { throw SaveError.invalidCommander }
      self.contents = source.recorder
      self.capture = capture
      self.readings = state.readings.sorted { $0.reading.ordinal < $1.reading.ordinal }
      self.clocks = try self.readings.map {
        guard let contents = NativeGlassMeridian.reservationContents(for: $0, in: state) else {
          throw SaveError.invalidCommander
        }
        return contents
      }
    }
  }

  static func currentPin(in game: borrowing Game) throws -> NativeC01ReservationReadPin {
    let ledger = try LedgerRead(game)
    let recorder = try RecorderRead(game, source: ledger.source)
    guard let mission = game.glassMeridianMission,
      let carrier = game.commander.hullInstanceID,
      let inventory = game.commander.equipmentInventory,
      inventory.owner == ledger.source.terms.owner,
      let actor = recorder.capture.marker.body.physical?.identity
    else { throw SaveError.invalidCommander }
    return .init(
      mission: mission.id, missionRevision: mission.revision,
      owner: ledger.source.terms.owner, source: ledger.source.terms.source,
      sourceRevision: ledger.source.revision, sourceFingerprint: ledger.source.fingerprint,
      recorderContents: ledger.source.recorderFingerprint,
      captureOperation: recorder.capture.operation, recorderActor: actor,
      readings: recorder.readings.map { $0.reading.operation },
      clockContents: ledger.source.clockFingerprints,
      dock: ledger.arrival.receipt, epoch: ledger.arrival.runtimeEpoch,
      carrier: carrier, inventoryRevision: inventory.revision)
  }

  /// Caller supplies review consent only. All read facts and findings are obtained again here.
  static func readAndCompare(
    in game: borrowing Game, pin: NativeC01ReservationReadPin, consent: UUID
  ) throws -> NativeC01ReservationAuditReceipt {
    let ledger = try LedgerRead(game)
    let recorder = try RecorderRead(game, source: ledger.source)
    guard try currentPin(in: game) == pin,
      game.commander.scriptState.nextEvent < UInt64(Int64.max) - 1,
      game.glassMeridianMission?.savedGlassMeridian?.reservationCase?.audit == nil
    else { throw SaveError.invalidCommander }
    let findings = try NativeC01ReservationComparison.compare(
      source: ledger.source, clocks: recorder.clocks, recorder: recorder.contents)
    return .init(
      sequence: game.commander.scriptState.nextEvent + 1,
      time: game.commander.flightSimulation.physicalTime, pin: pin,
      source: ledger.source, consent: consent, findings: findings)
  }

  static func == (lhs: NativeC01ReservationAuditReceipt, rhs: NativeC01ReservationAuditReceipt)
    -> Bool
  {
    lhs.operation == rhs.operation && lhs.sequence == rhs.sequence
      && lhs.physicalTime == rhs.physicalTime && lhs.pin == rhs.pin
      && lhs.auditor == rhs.auditor && lhs.ledgerOwner == rhs.ledgerOwner
      && lhs.consent == rhs.consent && lhs.target == rhs.target && lhs.stage == rhs.stage
      && lhs.event == rhs.event && lhs.findings == rhs.findings
  }
}

final class NativeC01ReservationLossObservation: Codable, Sendable, Equatable {
  let sequence: UInt64
  let audit: UUID
  let loss: NativeC01SurveyorLoss
  init(sequence: UInt64, audit: UUID, loss: NativeC01SurveyorLoss) {
    self.sequence = sequence
    self.audit = audit
    self.loss = loss
  }
  static func == (
    lhs: NativeC01ReservationLossObservation, rhs: NativeC01ReservationLossObservation
  ) -> Bool {
    lhs.sequence == rhs.sequence && lhs.audit == rhs.audit && lhs.loss == rhs.loss
  }
}
struct NativeC01ReservationState: Codable, Sendable, Equatable {
  let source: NativeC01ReservationSource
  var audit: NativeC01ReservationAuditReceipt?
  var laterLoss: NativeC01ReservationLossObservation?
}
