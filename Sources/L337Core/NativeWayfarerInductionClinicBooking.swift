import Foundation

struct NativeInductionClinicBooking: Codable, Sendable, Equatable {
  let operation: UUID
  let instance: UUID
  let sequence: UInt64
  let parent: UUID
  let commanderOwner: UUID
  let operatorOwner: UUID
  let source: UUID
  let issue: UUID
  let unit: UUID
  let epoch: UUID
  let familyDigest: String
  let offer: UUID
  let stockRevision: UInt64
  let window: NativeInductionCapacityReservation
  let route: NativeInductionClinicRoute
  let terms: WayfarerColdChainDefinition
  let dock: NativeMainStationDockReceipt
  let carrier: UUID
  let inventoryRevision: UInt64
  let runtimeEpoch: UUID
  let physicalTime: Double
  let flightSeconds: Double

  static func instance(source: UUID, unit: UUID, revision: UInt64) -> UUID {
    ScriptIdentity.uuid("induction-clinic-accepted-instance-v1:\(source):\(unit):\(revision)")
  }
  static func identity(
    instance: UUID, offer: UUID, window: UUID, dock: NativeMainStationDockReceipt,
    carrier: UUID, fit: UInt64, time: Double, flightSeconds: Double, sequence: UInt64
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "induction-clinic-actual-acceptance-v1:\(instance):\(offer):\(window):\(try NativeFlightReception.hash(dock)):\(carrier):\(fit):\(time.bitPattern):\(flightSeconds.bitPattern):\(sequence)"
    )
  }
  func valid(parent: NativeWayfarerInductionState) -> Bool {
    guard let source = parent.charterClinicSource, let capacity = parent.charterCapacity,
      self.source == source.identity, issue == source.issue.operation,
      self.parent == source.issue.parent, commanderOwner == source.issue.commanderOwner,
      operatorOwner == source.issue.operatorOwner, epoch == source.issue.epoch,
      familyDigest == source.issue.familyDigest, route.valid,
      terms == (try? source.issue.profile.terms(epoch: epoch, route: route)),
      let stockBefore = try? source.snapshot(at: stockRevision),
      stockBefore.units.contains(where: {
        $0.id == unit && $0.status == .available && $0.instance == nil
      }),
      instance == Self.instance(source: source.identity, unit: unit, revision: stockRevision),
      let before = try? capacity.snapshot(at: window.revision),
      window.owner == operatorOwner, window.consignment == instance,
      window == (try? before.quote(consignment: instance, unit: window.unit)),
      offer
        == (try? NativeInductionClinicQuote.identity(
          source: source, unit: unit, scope: .ownerStation,
          stockRevision: stockRevision, capacity: before, dock: dock, carrier: carrier,
          revision: inventoryRevision, runtimeEpoch: runtimeEpoch, route: route)),
      dock.valid, dock.commanderOwner == commanderOwner, dock.station == source.issue.dock.station,
      dock.sequence >= source.issue.dock.sequence,
      dock.actor.visit >= source.issue.dock.actor.visit,
      dock.calendarSeconds >= source.issue.dock.calendarSeconds,
      inventoryRevision < UInt64(Int64.max), physicalTime.isFinite,
      (source.issue.physicalTime...1e12).contains(physicalTime), flightSeconds.isFinite,
      (source.issue.flightSeconds...1e12).contains(flightSeconds),
      sequence > source.issue.sequence, sequence < UInt64(Int64.max)
    else { return false }
    return operation
      == (try? Self.identity(
        instance: instance, offer: offer, window: window.operation,
        dock: dock, carrier: carrier, fit: inventoryRevision, time: physicalTime,
        flightSeconds: flightSeconds, sequence: sequence))
  }
}

struct NativeInductionClinicUncollectedClose: Codable, Sendable, Equatable {
  enum Kind: String, Codable, Sendable { case cancelled, carrierExit, sourceLost }
  let operation: UUID
  let sequence: UInt64
  let instance: UUID
  let booking: UUID
  let stockRevision: UInt64
  let kind: Kind
  let window: NativeInductionCapacityReturn
  let player: ActorIdentity
  let carrier: UUID
  let inventoryRevision: UInt64
  let physicalTime: Double
  let flightSeconds: Double
  let dock: NativeMainStationDockReceipt?
  let loss: WayfarerColdChainPhysicalLoss?
  let sourceLoss: ScriptStationResource?

  static func identity(
    booking: UUID, stockRevision: UInt64, kind: Kind, window: UUID, player: ActorIdentity,
    carrier: UUID, fit: UInt64, time: Double, flightSeconds: Double, sequence: UInt64
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "induction-clinic-uncollected-close-v1:\(booking):\(stockRevision):\(kind.rawValue):\(window):\(try NativeFlightReception.hash(player)):\(carrier):\(fit):\(time.bitPattern):\(flightSeconds.bitPattern):\(sequence)"
    )
  }
  func valid(booking: NativeInductionClinicBooking, parent: NativeWayfarerInductionState) -> Bool {
    guard self.booking == booking.operation, instance == booking.instance,
      let capacity = parent.charterCapacity, let source = parent.charterClinicSource,
      let before = try? capacity.snapshot(at: window.revision),
      window
        == (try? before.returnQuote(reservation: booking.window.operation, reason: .cancelled)),
      window.owner == booking.operatorOwner, stockRevision > booking.stockRevision,
      sequence > booking.sequence,
      sequence < UInt64(Int64.max),
      player.entity == 0, player.visit >= booking.dock.actor.visit,
      player.visit < UInt64(Int64.max),
      (0..<8).contains(player.system.galaxy), (0...256).contains(player.system.system),
      carrier == booking.carrier, inventoryRevision >= booking.inventoryRevision,
      inventoryRevision < UInt64(Int64.max), physicalTime.isFinite,
      (booking.physicalTime...1e12).contains(physicalTime), flightSeconds.isFinite,
      (booking.flightSeconds...1e12).contains(flightSeconds)
    else { return false }
    if let dock {
      guard dock.valid, dock.commanderOwner == booking.commanderOwner,
        dock.actor.system == player.system, dock.actor.visit == player.visit,
        dock.sequence >= booking.dock.sequence
      else { return false }
    }
    switch kind {
    case .cancelled: guard loss == nil, sourceLoss == nil else { return false }
    case .carrierExit:
      guard let loss, loss.valid, sourceLoss == nil, dock == nil,
        loss.sequence == sequence, loss.visit == player.visit,
        loss.context.flightSeconds == flightSeconds,
        loss.context.galaxy == player.system.galaxy, loss.context.system == player.system.system
      else { return false }
    case .sourceLost:
      guard loss == nil, let sourceLoss, sourceLoss.valid, sourceLoss.destroyed,
        sourceLoss.energy == 0,
        sourceLoss.identity == source.issue.dock.station.resource,
        sourceLoss.key == source.issue.profile.source.resourceKey
      else { return false }
    }
    return operation
      == (try? Self.identity(
        booking: self.booking, stockRevision: stockRevision, kind: kind, window: window.operation,
        player: player, carrier: carrier, fit: inventoryRevision, time: physicalTime,
        flightSeconds: flightSeconds, sequence: sequence))
  }
}

final class NativeInductionClinicContract: Codable, Sendable, Equatable {
  let booking: NativeInductionClinicBooking
  let close: NativeInductionClinicUncollectedClose?
  let custody: NativeInductionClinicCustody?
  init(
    booking: NativeInductionClinicBooking, close: NativeInductionClinicUncollectedClose? = nil,
    custody: NativeInductionClinicCustody? = nil
  ) {
    self.booking = booking
    self.close = close
    self.custody = custody
  }
  var reservedCargoTonnes: Int { close == nil && custody == nil ? booking.terms.tonnes : 0 }
  var outcome: ScriptOutcome {
    custody?.outcome ?? (close == nil ? .active : close?.kind == .cancelled ? .abandoned : .failed)
  }
  func valid(parent: NativeWayfarerInductionState) -> Bool {
    booking.valid(parent: parent) && !(close != nil && custody != nil)
      && (close?.valid(booking: booking, parent: parent) ?? true)
      && (custody?.valid(booking: booking, parent: parent) ?? true)
  }
  static func == (lhs: NativeInductionClinicContract, rhs: NativeInductionClinicContract) -> Bool {
    lhs === rhs
      || (lhs.booking == rhs.booking && lhs.close == rhs.close && lhs.custody == rhs.custody)
  }
}
