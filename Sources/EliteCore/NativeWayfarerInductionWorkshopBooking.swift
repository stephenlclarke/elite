import Foundation

struct NativeInductionWorkshopBooking: Codable, Sendable, Equatable {
  let operation: UUID
  let instance: UUID
  let sequence: UInt64
  let parent: UUID
  let commanderOwner: UUID
  let operatorOwner: UUID
  let source: UUID
  let issue: UUID
  let unit: UUID
  let serial: UUID
  let epoch: UUID
  let familyDigest: String
  let offer: UUID
  let stockRevision: UInt64
  let window: NativeInductionCapacityReservation
  let route: NativeInductionWorkshopRoute
  let rewardNative: Int
  let dock: NativeMainStationDockReceipt
  let carrier: UUID
  let inventoryRevision: UInt64
  let runtimeEpoch: UUID
  let physicalTime: Double
  let flightSeconds: Double
  static func identity(
    instance: UUID, offer: UUID, window: UUID, time: Double,
    flightSeconds: Double, sequence: UInt64
  ) -> UUID {
    ScriptIdentity.uuid(
      "induction-original-workshop-acceptance-v1:\(instance):\(offer):\(window):\(time.bitPattern):\(flightSeconds.bitPattern):\(sequence)"
    )
  }
  func valid(parent: NativeWayfarerInductionState) -> Bool {
    guard let source = parent.charterWorkshopSource, let capacity = parent.charterCapacity,
      self.parent == source.issue.parent, self.source == source.identity,
      issue == source.issue.operation,
      commanderOwner == source.issue.commanderOwner, operatorOwner == source.issue.operatorOwner,
      epoch == source.issue.epoch, familyDigest == source.issue.familyDigest, route.valid,
      rewardNative == (try? source.issue.profile.reward(route: route)),
      let stockBefore = try? source.snapshot(at: stockRevision),
      let stock = stockBefore.units.first(where: {
        $0.id == unit && $0.serial == serial && $0.status == .available && $0.instance == nil
      }),
      instance
        == NativeInductionWorkshopSource.instance(
          source: source.identity, unit: unit, revision: stockRevision),
      let before = try? capacity.snapshot(at: window.revision),
      window.owner == operatorOwner, window.consignment == instance,
      window == (try? before.quote(consignment: instance, unit: window.unit)),
      offer
        == (try? NativeInductionWorkshopQuote.identity(
          source: source, unit: stock, scope: .ownerStation,
          stockRevision: stockRevision, capacity: before, dock: dock, carrier: carrier,
          fit: inventoryRevision, runtimeEpoch: runtimeEpoch, route: route)),
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
      == Self.identity(
        instance: instance, offer: offer, window: window.operation,
        time: physicalTime, flightSeconds: flightSeconds, sequence: sequence)
  }
}

struct NativeInductionWorkshopPickup: Codable, Sendable, Equatable {
  let operation: UUID
  let booking: UUID
  let contact: WayfarerColdChainContact
  let carrier: UUID
  let inventoryRevision: UInt64
  let physicalTime: Double
  static func identity(
    booking: UUID, contact: WayfarerColdChainContact, carrier: UUID, fit: UInt64, time: Double
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "induction-original-workshop-pickup-v1:\(booking):\(try NativeFlightReception.hash(contact)):\(carrier):\(fit):\(time.bitPattern)"
    )
  }
  func valid(booking: NativeInductionWorkshopBooking) -> Bool {
    self.booking == booking.operation && contact.valid && contact.sequence > booking.sequence
      && contact.dock.station == booking.dock.station
      && contact.dock.commanderOwner == booking.commanderOwner
      && contact.dock.sequence >= booking.dock.sequence
      && contact.dock.actor.visit >= booking.dock.actor.visit
      && contact.context.flightSeconds >= booking.flightSeconds
      && carrier == booking.carrier && inventoryRevision >= booking.inventoryRevision
      && inventoryRevision < UInt64(Int64.max) && physicalTime.isFinite
      && (booking.physicalTime...1e12).contains(physicalTime)
      && operation
        == (try? Self.identity(
          booking: self.booking, contact: contact, carrier: carrier,
          fit: inventoryRevision, time: physicalTime))
  }
}

struct NativeInductionWorkshopService: Codable, Sendable, Equatable {
  let operation: UUID
  let pickup: UUID
  let unit: UUID
  let serial: UUID
  let contact: WayfarerColdChainContact
  let carrier: UUID
  let inventoryRevision: UInt64
  let physicalTime: Double
  let before: NativeRepairLoopCondition
  let after: NativeRepairLoopCondition
  static func identity(
    pickup: UUID, unit: UUID, serial: UUID, contact: WayfarerColdChainContact,
    carrier: UUID, fit: UInt64, time: Double
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "induction-original-workshop-service-v1:\(pickup):\(unit):\(serial):\(try NativeFlightReception.hash(contact)):\(carrier):\(fit):\(time.bitPattern)"
    )
  }
  func valid(booking: NativeInductionWorkshopBooking, pickup: NativeInductionWorkshopPickup) -> Bool
  {
    self.pickup == pickup.operation && unit == booking.unit && serial == booking.serial
      && contact.valid && contact.sequence > pickup.contact.sequence
      && NativeInductionWorkshopProfile.original.workshop.matches(contact.dock.station)
      && contact.dock.commanderOwner == booking.commanderOwner
      && contact.dock.sequence > pickup.contact.dock.sequence
      && contact.dock.actor.visit > pickup.contact.dock.actor.visit
      && contact.context.flightSeconds >= pickup.contact.context.flightSeconds
      && contact.context.calendarSeconds >= pickup.contact.context.calendarSeconds
      && carrier == pickup.carrier && inventoryRevision >= pickup.inventoryRevision
      && inventoryRevision < UInt64(Int64.max) && physicalTime.isFinite
      && (pickup.physicalTime...1e12).contains(physicalTime)
      && before == .failed(sourceUnit: unit)
      && after == (try? before.serviced(sourceUnit: unit, operation: operation))
      && operation
        == (try? Self.identity(
          pickup: self.pickup, unit: unit, serial: serial,
          contact: contact, carrier: carrier, fit: inventoryRevision, time: physicalTime))
  }
}

struct NativeInductionWorkshopCancellation: Codable, Sendable, Equatable {
  let operation: UUID
  let pickup: UUID
  let contact: WayfarerColdChainContact
  let physicalTime: Double
  static func identity(pickup: UUID, contact: WayfarerColdChainContact, time: Double) throws -> UUID
  {
    ScriptIdentity.uuid(
      "induction-original-workshop-held-cancel-v1:\(pickup):\(try NativeFlightReception.hash(contact)):\(time.bitPattern)"
    )
  }
  func valid(pickup: NativeInductionWorkshopPickup, service: NativeInductionWorkshopService?)
    -> Bool
  {
    self.pickup == pickup.operation && contact.valid
      && contact.sequence > (service?.contact.sequence ?? pickup.contact.sequence)
      && contact.dock.commanderOwner == pickup.contact.dock.commanderOwner
      && contact.dock.sequence >= (service?.contact.dock.sequence ?? pickup.contact.dock.sequence)
      && contact.dock.actor.visit
        >= (service?.contact.dock.actor.visit ?? pickup.contact.dock.actor.visit)
      && contact.context.flightSeconds
        >= (service?.contact.context.flightSeconds ?? pickup.contact.context.flightSeconds)
      && contact.context.calendarSeconds
        >= (service?.contact.context.calendarSeconds ?? pickup.contact.context.calendarSeconds)
      && physicalTime.isFinite
      && ((service?.physicalTime ?? pickup.physicalTime)...1e12).contains(physicalTime)
      && operation
        == (try? Self.identity(pickup: self.pickup, contact: contact, time: physicalTime))
  }
}
