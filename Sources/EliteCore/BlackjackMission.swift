import Foundation

public enum BlackjackStage: Int, Sendable, Codable, CaseIterable {
  case notStarted = 0
  case huntBolts, reportBolts, collectFirearm, deliverFirearm, huntWitness, reportWitness
  case complete = 99
  public var progress: Int { self == .complete ? 7 : rawValue }
  public var wanted: Bool { self == .huntWitness || self == .reportWitness }
}
public enum BlackjackTransfer: String, Sendable, Codable, CaseIterable {
  case contact, goldAward, goldDelivery, report, firearmPickup, robberyHandoff, finalReward
}
public struct BlackjackMission: Sendable, Codable, Equatable {
  public static let revision = "P05-1.2.9-station-v1"
  public var profileRevision = Self.revision
  public var stage: BlackjackStage = .notStarted
  public var transfers: Set<BlackjackTransfer> = []
  public var pendingGold = false
  public var bolts: BlackjackEncounter?
  public var witness: BlackjackEncounter?
  public init() {}
  public var carriesFirearm: Bool { stage == .deliverFirearm }
  public var valid: Bool {
    guard profileRevision == Self.revision, bolts?.valid ?? true, witness?.valid ?? true,
      bolts?.role != .witness, witness?.role != .bolts
    else { return false }
    if let bolts, let witness, bolts.identity == witness.identity { return false }
    if stage == .huntBolts && bolts?.body.energy == 0 { return false }
    if stage == .huntWitness && witness?.body.energy == 0 { return false }
    let milestones: [(BlackjackTransfer, Int)] = [
      (.contact, 1), (.goldAward, 2), (.report, 3), (.firearmPickup, 4), (.robberyHandoff, 5),
      (.finalReward, 7),
    ]
    guard milestones.allSatisfy({ transfers.contains($0.0) == (stage.progress >= $0.1) }) else {
      return false
    }
    if pendingGold { return stage == .reportBolts && !transfers.contains(.goldDelivery) }
    return transfers.contains(.goldDelivery) == (stage.progress >= 2)
  }
}
extension Commander {
  public var markedFirearms: Int { blackjack.carriesFirearm ? 1 : 0 }
  public func sellableCargo(_ index: Int) -> Int {
    max(0, cargo[index] - (index == 10 ? markedFirearms : 0))
  }
  public func canCarryMissionCargo(capacity: Int) -> Bool {
    capacity >= markedFirearms && cargoTonnes <= capacity
  }
}
public enum BlackjackTarget: String, Sendable, Codable {
  case bolts, witness
  public var system: Int { self == .bolts ? 88 : 99 }
  public var requiredStage: BlackjackStage { self == .bolts ? .huntBolts : .huntWitness }
  public var name: String { self == .bolts ? "Commander Bolts (S.T.E)" : "Witness (S.T.E)" }
  public var ink: Ink { self == .bolts ? .orange : .green }
  public var cargoCapacity: Int { self == .bolts ? 55 : 5 }
  public var bountyCredits: Int { self == .bolts ? 64 : 0 }
  public static let energy = 300.0
  public static let recharge = 4.0
  public static let speed = 390.0
  public static let weaponEnergy = 25.0
}
