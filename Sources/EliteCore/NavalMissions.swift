import Foundation

/// The Executive build's saved TP low nibble, not a new campaign ordering.
public enum NavalMissionStage: Int, Codable, Sendable, CaseIterable {
  case notStarted = 0
  case huntingConstrictor = 1
  case constrictorDestroyed = 3
  case constrictorComplete = 2
  case reportToCeerdi = 6
  case carryingPlans = 10
  case plansDelivered = 14

  public var status: String {
    switch self {
    case .notStarted: "NO NAVAL ASSIGNMENT"
    case .huntingConstrictor: "HUNT THE CONSTRICTOR"
    case .constrictorDestroyed: "REPORT TO THE NAVY"
    case .constrictorComplete: "CONSTRICTOR MISSION COMPLETE"
    case .reportToCeerdi: "REPORT TO NERITH (GALAXY 3)"
    case .carryingPlans: "DELIVER PLANS TO VEYARA (GALAXY 3)"
    case .plansDelivered: "NAVAL MISSIONS COMPLETE"
    }
  }
}

public enum MissionMessage: String, Sendable {
  case constrictorBriefing, constrictorDebriefing, ceerdiOrders, plansCollection, plansDebriefing
  static let allMessages: [Self] = [
    .constrictorBriefing, .constrictorDebriefing, .ceerdiOrders, .plansCollection, .plansDebriefing,
  ]
}

public struct MissionNotice: Sendable, Equatable {
  public let message: MissionMessage
  public let commander: String
  public let galaxy: Int
  var dialog: PackDialog? {
    MissionPackLibrary.bundled.entries.first {
      $0.pack.dialog(message.rawValue.lowercased()) != nil
    }?.pack.dialog(message.rawValue.lowercased())
  }
  public var showsShip: Bool { dialog?.ship ?? false }
  public var pages: [[String]] {
    let lines = Self.wrap(text, width: 40)
    let count = showsShip ? 9 : 17
    return stride(from: 0, to: lines.count, by: count).map {
      Array(lines[$0..<min($0 + count, lines.count)])
    }
  }
  public var text: String {
    let template = dialog?.text ?? "MESSAGE UNAVAILABLE"
    return template.replacingOccurrences(of: "{commander}", with: commander)
      .replacingOccurrences(of: "{captain}", with: galaxy == 0 ? "CARRUTHERS" : "FOSDYKE SMYTHE")
      .replacingOccurrences(
        of: "{sighting}",
        with: galaxy == 0
          ? "ITS LAST REPORTED SIGHTING WAS AT REESDICE."
          : "INTELLIGENCE BELIEVES IT JUMPED INTO THIS GALAXY.")
  }

  static func wrap(_ text: String, width: Int) -> [String] {
    text.components(separatedBy: "\n").flatMap { paragraph -> [String] in
      var result: [String] = []
      var line = ""
      for word in paragraph.split(separator: " ") {
        if !line.isEmpty && line.count + word.count + 1 > width {
          result.append(line)
          line = ""
        }
        line += (line.isEmpty ? "" : " ") + word
      }
      result.append(line)
      return result
    }
  }
}

public enum MissionRules {
  public static func constrictorSystem(galaxy: Int, x: Int, y: Int) -> Bool {
    galaxy == 1 && x == 144 && y == 33
  }

  public static func plansAmbush(randomByte: Int) -> Bool { randomByte >= 200 }

  public static func bountyHunterCheck(government: Int, roll: Int, hunterRoll: Int) -> Bool {
    (government == 0 || (roll < 90 && roll & 7 >= government)) && hunterRoll < 100
  }

  public static func clue(
    stage: NavalMissionStage, galaxy: Int, system: Int, variation: Int
  ) -> String? {
    guard stage.rawValue & 1 != 0 else { return nil }
    let clues = MissionPackLibrary.bundled.entries.flatMap { $0.pack.clues ?? [] }
    guard let clue = clues.first(where: { $0.galaxy == galaxy && $0.systems.contains(system) }),
      !clue.texts.isEmpty
    else { return nil }
    return clue.texts[abs(variation % clue.texts.count)]
  }

}

extension Commander {
  public var energyRechargeMultiplier: Double {
    if let multiplier = fittedComponent(at: .energy)?.statistics[.energyRecharge] {
      return multiplier * fittedAlienSummary(.energyRecharge).multiplier
    }
    let ordinary: Double
    if equipment.contains(Equipment.eliteEnergyUnit) {
      ordinary = 4
    } else if equipment.contains(Equipment.navalEnergyUnit) {
      ordinary = 3
    } else {
      ordinary = equipment.contains("Extra Energy Unit") ? 2 : 1
    }
    return ordinary * fittedAlienSummary(.energyRecharge).multiplier
  }
  public func laserDamage(against hull: Hull, mount: LaserMount = .front) -> Double {
    guard let laser = laser(on: mount) else { return 0 }
    if hull == .constrictor {
      return laser == .military || laser == .naval ? floor(laser.damage / 4) : 0
    }
    return laser.damage
  }
}

extension Game {
  mutating func progressNavalMissions() {
    _ = dispatchMission(.dock, naval: true)
  }

  mutating func missionKey(_ key: String) {
    guard missionElapsed >= (missionNotice?.dialog?.delaySeconds ?? 2) else { return }
    let last = max(0, (missionNotice?.pages.count ?? 1) - 1)
    if key == "left" || key == "up" {
      missionPage = max(0, missionPage - 1)
      return
    }
    if key == "right" || key == "down" {
      missionPage = min(last, missionPage + 1)
      return
    }
    if key == "escape" {
      closeMissionMessage()
      return
    }
    if key == " " || key == "return" {
      if missionPage < last {
        missionPage += 1
      } else {
        closeMissionMessage()
      }
    }
  }

  private mutating func closeMissionMessage() {
    missionNotice = nil
    screen = .status
    offerBlackjackHandoff()
  }

  mutating func missionTargetRemoved(_ body: SpaceBody) {
    if body.hull == .constrictor && body.navalTarget
      && commander.missionStage == .huntingConstrictor
    {
      // KILLSHP sets TP on removal, including FAROF culling, not just a credited kill.
      _ = dispatchMission(.targetRemoved, naval: true, target: "constrictor")
    }
  }

  mutating func spawnNavalEncounter() {
    let hunt = missionEncounter("constrictor-hunt") != nil
    let plans = missionEncounter("plans-ambush") != nil
    guard missionEncounter("constrictor-hunt", location: false) != nil || plans,
      !bodies.contains(where: {
        $0.hull == .viper || ($0.hull == .station && $0.position.length < 600)
      })
    else { return }
    if missionSpawnDelay > 0 {
      missionSpawnDelay -= 1
      return
    }
    let limit = commander.executive ? 18 : 10
    if plans && MissionRules.plansAmbush(randomByte: randomByte()) {
      let x = randomByte() & 128 == 0 ? 6400.0 : -6400.0
      let y = randomByte() & 128 == 0 ? 6400.0 : -6400.0
      for hull in [Hull.thargoid, .thargon] where bodies.count < limit {
        addNavalShip(hull, position: .init(x, y, 6400))
      }
    }
    guard hunt,
      !bodies.contains(where: { $0.hull == .constrictor }), bodies.count < limit,
      MissionRules.bountyHunterCheck(
        government: currentSystem.government, roll: randomByte(), hunterRoll: randomByte())
    else { return }
    let x = randomByte() & 128 == 0 ? 6400.0 : -6400.0
    let y = randomByte() & 128 == 0 ? 6400.0 : -6400.0
    addNavalShip(.constrictor, position: .init(x, y, 6400))
    missionSpawnDelay = 1
  }

  mutating func addNavalShip(_ hull: Hull, position: Vector3) {
    var body = SpaceBody(id: nextBodyID, hull: hull, position: position, hostile: true)
    body.navalTarget = hull == .constrictor
    bodies.append(body)
    nextBodyID += 1
  }
}
