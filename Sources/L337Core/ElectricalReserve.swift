import Foundation

/// Electrical power is independent of fatal hull integrity. A disabled reserve
/// stays at zero until its actual simulation episode is explicitly recovered.
public struct ElectricalReserve: Equatable, Codable, Sendable {
  public private(set) var remaining: Double
  public private(set) var capacity: Double
  public private(set) var recharge: Double
  public private(set) var physicalTime: Double
  public private(set) var disabledAt: Double?
  public var recoveryAt: Double? { disabledAt.map { $0 + 30 } }
  public var valid: Bool {
    [remaining, capacity, recharge, physicalTime].allSatisfy { $0.isFinite && $0 >= 0 }
      && capacity > 0 && remaining <= capacity
      && (disabledAt.map {
        $0.isFinite && $0 >= 0 && $0 <= physicalTime && ($0 + 30).isFinite && remaining == 0
      } ?? true)
  }
  public init?(capacity: Double, recharge: Double, at time: Double) {
    self.capacity = capacity
    self.recharge = recharge
    remaining = capacity
    physicalTime = time
    disabledAt = nil
    guard valid else { return nil }
  }
  @discardableResult
  mutating func advance(to time: Double, capacity: Double, recharge: Double) -> Bool {
    guard valid, time.isFinite, time >= physicalTime,
      capacity.isFinite, capacity > 0, recharge.isFinite, recharge >= 0
    else { return false }
    // A capacity upgrade never grants charge; a reduction only clamps excess.
    remaining = min(capacity, remaining)
    if disabledAt == nil { remaining = min(capacity, remaining + (time - physicalTime) * recharge) }
    self.capacity = capacity
    self.recharge = recharge
    physicalTime = time
    return valid
  }
  @discardableResult
  mutating func drain(_ pulse: Double, at time: Double) -> Bool {
    guard valid, pulse.isFinite, pulse >= 0, time.isFinite, time >= physicalTime else {
      return false
    }
    physicalTime = time
    guard disabledAt == nil else { return true }
    remaining = max(0, remaining - pulse)
    if remaining == 0 { disabledAt = time }
    return valid
  }
  @discardableResult
  mutating func recover(at time: Double) -> Bool {
    guard valid, let deadline = recoveryAt, time.isFinite, time >= deadline else { return false }
    let earned = min(capacity, max(0, time - deadline) * recharge)
    guard earned > 0 else { return false }
    disabledAt = nil
    remaining = earned
    physicalTime = time
    return valid
  }
}

/// An actual activation, rather than a transient global ECM countdown, cancels
/// charging. The cancelled state remains saved after that field expires.
struct EMPChargeState: Equatable, Codable, Sendable {
  enum Phase: String, Codable, Sendable { case charging, released, cancelled }
  let player: ActorIdentity
  let target: ActorIdentity
  let owner: UUID
  let hull: UUID
  let weapon: UUID
  let startedAt: Double
  var phase: Phase = .charging
  var endedAt: Double?
  var cancellingECM: ECMActivationIdentity?
  var valid: Bool {
    player.entity == 0 && target.entity > 1 && target.system == player.system
      && target.visit == player.visit && player.visit > 0
      && startedAt.isFinite && startedAt >= 0 && (startedAt + 10).isFinite
      && (phase == .charging
        ? endedAt == nil && cancellingECM == nil
        : endedAt.map { $0.isFinite && $0 >= startedAt } == true)
      && (cancellingECM.map {
        phase == .cancelled && $0.emitter.system == player.system
          && $0.emitter.visit == player.visit && $0.sequence > 0
      } ?? true)
  }
}

extension Commander {
  var electricalStateValid: Bool {
    let now = flightSimulation.physicalTime
    guard savedPlayerElectrical.map({ $0.valid && $0.physicalTime <= now }) ?? true else {
      return false
    }
    guard let charge = savedEMPCharge else { return true }
    return charge.valid && charge.owner == equipmentOwnerID && charge.hull == hullInstanceID
      && charge.player == flightSimulation.player
      && charge.target.entity < flightSimulation.nextActor
      && charge.startedAt <= now && (charge.endedAt.map { $0 <= now } ?? true)
      && (charge.cancellingECM.map { $0.sequence < flightSimulation.nextSpawn } ?? true)
  }
  var usesElectricalSaveVersion: Bool {
    savedPlayerElectrical != nil || savedEMPCharge != nil
      || savedEMPState?.records.values.contains { record in
        record.hull.body.physical?.npc?.resources?.electrical != nil || record.isRecovered
          || record.savedCurrentTrafficTransfer != nil || record.savedCurrentCargo != nil
      } == true
      || npcPersistence.hasElectricalState
  }
}

/// Reject native physical fields before legacy decoding can discard them.
/// Authored mission payload keys are outside these native state paths.
enum ElectricalVersionedSave {
  static func rejectFields(_ bytes: Data) throws {
    guard let root = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else {
      throw SaveError.invalidCommander
    }
    func nativeState(_ value: Any) -> Bool {
      if let object = value as? [String: Any] {
        return [
          "electrical", "savedRecoveredAt", "savedOrdinaryTerminal", "savedCurrentTrafficTransfer",
          "savedCurrentCargo", "savedCurrentLegal", "legacyElectricalRecharge",
        ].contains { object.keys.contains($0) }
          || object.values.contains(where: nativeState)
      }
      return (value as? [Any])?.contains(where: nativeState) == true
    }
    let forbidden =
      root.keys.contains("savedPlayerElectrical") || root.keys.contains("savedEMPCharge")
      || ["savedNPCPersistence", "savedEMPState"].contains {
        root[$0].map(nativeState) == true
      }
    let worldReserve = (root["bodies"] as? [[String: Any]] ?? []).contains { body in
      guard let physical = body["physical"] as? [String: Any],
        let npc = physical["npc"] as? [String: Any],
        let resources = npc["resources"] as? [String: Any]
      else { return false }
      return resources.keys.contains("electrical")
        || resources.keys.contains("legacyElectricalRecharge")
    }
    guard !forbidden, !worldReserve else { throw SaveError.invalidCommander }
  }
}
