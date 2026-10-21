import Foundation

/// A receiving record consumes only the original sealed crate, with positive quality at Confirm.
struct NativeInductionClinicReception: Codable, Sendable, Equatable {
  let operation: UUID
  let crateOperation: UUID
  let unit: UUID
  let coolingUnit: UUID
  let dock: NativeMainStationDockReceipt
  let carrier: UUID
  let inventoryRevision: UInt64
  let physicalTime: Double
  let flightSeconds: Double
  let remaining: Double

  func valid(crate: NativeInductionClinicCrate, owner: UUID) -> Bool {
    guard unit == crate.unit, coolingUnit == crate.coolingUnit,
      crateOperation == crate.operation, dock.valid, dock.commanderOwner == owner,
      dock.station.world == owner, dock.station.system == NativeWayfarerInduction.receiver,
      dock.sequence > crate.dock.sequence, dock.actor.visit > crate.dock.actor.visit,
      dock.calendarSeconds >= crate.dock.calendarSeconds,
      physicalTime.isFinite, physicalTime >= crate.physicalTime, physicalTime <= 1e12,
      let expected = try? crate.remaining(at: flightSeconds), expected > 0,
      remaining == expected
    else { return false }
    return operation
      == (try? NativeWayfarerInduction.continuationOperation(
        target: NativeWayfarerInduction.receivingTarget, previous: crate.operation,
        dock: dock, carrier: carrier, revision: inventoryRevision, flightSeconds: flightSeconds))
  }
}

/// The failed cassette remains workshop property; collection does not imply repair or reception.
struct NativeInductionWorkshopCassette: Codable, Sendable, Equatable {
  let operation: UUID
  let receptionOperation: UUID
  let unit: UUID
  let dock: NativeMainStationDockReceipt
  let carrier: UUID
  let inventoryRevision: UInt64
  let physicalTime: Double
  let flightSeconds: Double
  let condition: String

  func valid(reception: NativeInductionClinicReception, owner: UUID) -> Bool {
    guard receptionOperation == reception.operation,
      unit == NativeWayfarerInduction.cassetteUnit(owner: owner),
      condition == "failed-workshop-original", dock.valid, dock.commanderOwner == owner,
      dock.station.world == owner, dock.station.system == NativeWayfarerInduction.workshop,
      dock.sequence > reception.dock.sequence, dock.actor.visit > reception.dock.actor.visit,
      dock.calendarSeconds >= reception.dock.calendarSeconds,
      physicalTime.isFinite, physicalTime >= reception.physicalTime, physicalTime <= 1e12,
      flightSeconds.isFinite, flightSeconds >= reception.flightSeconds, flightSeconds <= 1e12
    else { return false }
    return operation
      == (try? NativeWayfarerInduction.continuationOperation(
        target: NativeWayfarerInduction.cassetteTarget, previous: reception.operation,
        dock: dock, carrier: carrier, revision: inventoryRevision, flightSeconds: flightSeconds))
  }
}

extension NativeWayfarerInductionState {
  var milestones: Set<Int> {
    var result: Set<Int> = [0]
    if crate != nil { result.insert(1) }
    if reception != nil { result.insert(2) }
    if cassette != nil { result.insert(3) }
    return result
  }

  func receiving(_ receipt: NativeInductionClinicReception) throws -> Self {
    guard valid, crate != nil, loss == nil, reception == nil, cassette == nil else {
      throw SaveError.invalidCommander
    }
    let next = Self(permission: permission, crate: crate, reception: receipt)
    guard next.valid else { throw SaveError.invalidCommander }
    return next
  }

  func collectingCassette(_ original: NativeInductionWorkshopCassette, freeTonnes: Int)
    throws -> Self
  {
    guard valid, reception != nil, cassette == nil, freeTonnes >= 1 else {
      throw SaveError.invalidCommander
    }
    let next = Self(permission: permission, crate: crate, reception: reception, cassette: original)
    guard next.valid else { throw SaveError.invalidCommander }
    return next
  }

  var continuationValid: Bool {
    if let reception {
      guard let crate, loss == nil,
        reception.valid(crate: crate, owner: permission.owner)
      else { return false }
    }
    if let cassette {
      guard let reception, cassette.valid(reception: reception, owner: permission.owner) else {
        return false
      }
      if let cassetteLoss {
        guard cassetteLoss.facts.valid, cassetteLoss.physicalTime.isFinite,
          cassetteLoss.physicalTime >= cassette.physicalTime, cassetteLoss.physicalTime <= 1e12,
          cassetteLoss.facts.visit >= cassette.dock.actor.visit,
          cassetteLoss.facts.context.flightSeconds >= cassette.flightSeconds
        else { return false }
      }
    } else if cassetteLoss != nil {
      return false
    }
    return true
  }
}

extension NativeWayfarerInduction {
  static let receivingTarget = "navidor-clinic-quality-receipt"
  static let cassetteTarget = "enmadan-return-cassette"
  static let cassetteItem = "return-cassette"
  static let cassettePayload = "induction-workshop-return-cassette"
  static let workshop = SystemIdentity(galaxy: 0, system: 0)
  static func cassetteUnit(owner: UUID) -> UUID {
    ScriptIdentity.uuid("induction-original-workshop-stock-v1:\(cassetteItem):\(owner):0:0:0")
  }
  static func continuationOperation(
    target: String, previous: UUID, dock: NativeMainStationDockReceipt,
    carrier: UUID, revision: UInt64, flightSeconds: Double
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "induction-continuation-v1:\(target):\(previous):\(try NativeFlightReception.hash(dock)):\(carrier):\(revision):\(flightSeconds.bitPattern)"
    )
  }
  // Keep the accepted opening pack's bytes/pin stable. This native projection describes the
  // now-supported continuation instead of changing historical acceptance or pickup evidence.
  static let currentBriefing =
    "SENN: Accept the Avenor induction after an ordinary delivery or recorded native sale. Keep one free tonne. Collect Renas's unique sealed clinic crate, then Confirm intact reception at Navidor before its original 1800 armed-flight-second allowance expires. At Enmadan, collect the original failed workshop cassette for Renas's repair desk. These four stages pay nothing and grant no accreditation or clue. Stages 5-14 remain unavailable."
}
