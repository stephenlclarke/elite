import Foundation

/// Shared arithmetic only. Source ownership, actual docking and atomic stock transfer stay with callers.
enum NativeCustodianFuelMath {
  static func calculate(
    _ request: NativeArkFuelRequest, balance: Int, owner: UUID, mission: UUID,
    vessel: UUID, galaxy: Int, profile: ScriptNPCDefinition
  ) throws -> NativeArkFuelCalculation {
    guard request.offer.valid, profile.valid, let drive = profile.drive,
      request.before.isFinite, (0...profile.fuel).contains(request.before),
      request.nextHopLY.isFinite, request.nextHopLY > 0,
      request.nextHopLY <= drive.rangeLightYears
    else { throw NativeArkFuelRefusal.invalidInput }
    let contact = request.offer.contact
    guard contact.station.world == owner, contact.mission == mission, contact.ark == vessel,
      contact.station.system.galaxy == galaxy
    else { throw NativeArkFuelRefusal.foreignDock }
    let missing = request.nextHopLY - request.before
    guard missing > 0 else { throw NativeArkFuelRefusal.noFuelNeeded }
    let units = Int(ceil(missing * 10))
    guard units <= request.offer.availableTenthsLY else {
      throw NativeArkFuelRefusal.unavailableStock
    }
    let (cost, overflow) = units.multipliedReportingOverflow(by: request.offer.pricePerTenth)
    guard !overflow, cost <= balance else { throw NativeArkFuelRefusal.insufficientEscrow }
    let after = request.before + Double(units) / 10
    guard after.isFinite, after <= profile.fuel, after >= request.nextHopLY else {
      throw NativeArkFuelRefusal.invalidInput
    }
    return .init(billedTenths: units, cost: cost, after: after)
  }

  static func later(_ contact: NativeArkFuelContact, than previous: NativeArkFuelContact?) -> Bool {
    guard let previous else { return true }
    return contact.sequence > previous.sequence && contact.physicalTime >= previous.physicalTime
      && contact.arkActor.visit >= previous.arkActor.visit
  }
}
