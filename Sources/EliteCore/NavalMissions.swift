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
    case .reportToCeerdi: "REPORT TO CEERDI (GALAXY 3)"
    case .carryingPlans: "DELIVER PLANS TO BIRERA (GALAXY 3)"
    case .plansDelivered: "NAVAL MISSIONS COMPLETE"
    }
  }
}

public enum MissionMessage: String, Sendable {
  case constrictorBriefing, constrictorDebriefing, ceerdiOrders, plansCollection, plansDebriefing
}

public struct MissionNotice: Sendable, Equatable {
  public let message: MissionMessage
  public let commander: String
  public let galaxy: Int
  public var showsShip: Bool { message == .constrictorBriefing }
  public var pages: [[String]] {
    let lines = Self.wrap(text, width: 40)
    let count = showsShip ? 9 : 17
    return stride(from: 0, to: lines.count, by: count).map {
      Array(lines[$0..<min($0 + count, lines.count)])
    }
  }
  public var text: String {
    switch message {
    case .constrictorBriefing:
      let captain = galaxy == 0 ? "CARRUTHERS" : "FOSDYKE SMYTHE"
      let location =
        galaxy == 0
        ? "ITS LAST REPORTED SIGHTING WAS AT REESDICE."
        : "INTELLIGENCE BELIEVES IT JUMPED INTO THIS GALAXY."
      return """
        COMMANDER \(commander),
        CAPTAIN \(captain), SPACE NAVY.

        THE CONSTRICTOR IS AN EXPERIMENTAL WARSHIP WITH SECRET SHIELD TECHNOLOGY. IT WAS STOLEN FROM OUR XEER SHIPYARD FIVE MONTHS AGO.

        \(location)

        FIND AND DESTROY IT. ONLY MILITARY LASERS CAN DAMAGE ITS SHIELDS, AND IT CARRIES ECM. A GENEROUS REWARD AWAITS YOU.

        MESSAGE ENDS
        """
    case .constrictorDebriefing:
      return """
        COMMANDER \(commander),

        THE STOLEN CONSTRICTOR IS NO LONGER A THREAT. THE NAVY THANKS YOU FOR YOUR SERVICE.

        YOUR ACCOUNT HAS BEEN CREDITED WITH 5,000 CR AND YOUR COMBAT TALLY INCREASED BY 256 POINTS.

        MESSAGE ENDS
        """
    case .ceerdiOrders:
      return """
        COMMANDER \(commander),
        CAPTAIN FORTESQUE, SPACE NAVY.

        WE HAVE ANOTHER ASSIGNMENT FOR YOU. REPORT TO CEERDI IN THIS GALAXY FOR YOUR BRIEFING.

        MESSAGE ENDS
        """
    case .plansCollection:
      return """
        COMMANDER \(commander),
        AGENT BLAKE, NAVAL INTELLIGENCE.

        WE HAVE OBTAINED DEFENCE PLANS FOR THE THARGOID HIVE WORLDS. THE NAVY IS PREPARING AN OFFENSIVE.

        RADIO TRANSMISSION WOULD EXPOSE THE PLANS TO INTERCEPTION. THEY HAVE BEEN ENCODED INTO THIS MESSAGE FOR YOU TO CARRY TO OUR BASE ON BIRERA.

        REACH BIRERA IN THIS GALAXY AND DOCK THERE. EXPECT THARGOID OPPOSITION.

        MESSAGE ENDS
        """
    case .plansDebriefing:
      return """
        COMMANDER \(commander),

        THE PLANS HAVE REACHED OUR BIRERA BASE. YOUR SERVICE WILL BE REMEMBERED.

        WE HAVE FITTED A NAVAL ENERGY UNIT IN RECOGNITION OF YOUR WORK. IT REPLACES A STANDARD ENERGY UNIT AND RECHARGES AT THREE TIMES THE UNUPGRADED RATE.

        YOUR COMBAT TALLY HAS INCREASED BY 256 POINTS.

        MESSAGE ENDS
        """
    }
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
  public static func dockingMessage(
    stage: NavalMissionStage, galaxy: Int, score: Int, x: Int, y: Int
  ) -> MissionMessage? {
    if stage == .notStarted && score >= 256 && galaxy < 2 { return .constrictorBriefing }
    if stage == .constrictorDestroyed { return .constrictorDebriefing }
    guard galaxy == 2 else { return nil }
    switch stage {
    case .constrictorComplete: return score >= 1280 ? .ceerdiOrders : nil
    case .reportToCeerdi: return x == 215 && y == 84 ? .plansCollection : nil
    case .carryingPlans: return x == 63 && y == 72 ? .plansDebriefing : nil
    default: return nil
    }
  }

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
    if galaxy == 0 {
      return [
        150: "NAVAL REPORT: THE CONSTRICTOR WAS SIGHTED AT REESDICE.",
        36: "A STRANGE SHIP LEFT HERE, APPARENTLY HEADING FOR AREXE.",
        28: "AN UNUSUAL SHIP BOUGHT A GALACTIC HYPERDRIVE HERE AND USED IT.",
      ][system]
    }
    if galaxy == 2 && system == 101 { return "YOU ARE LOOKING IN THE WRONG GALAXY!" }
    guard galaxy == 1 else { return nil }
    let trail = [
      253: "A STRANGE SHIP ARRIVED HERE, SKIMMED THE SUN AND LEFT FOR INBIBE.",
      79: "A ROGUE ATTACKED ME AT AUSAR. MY LASERS COULD NOT HURT ITS HULL.",
      53: "A DANGEROUS SHIP FOUGHT THE PIRATES HERE, THEN LEFT FOR USLERI.",
      118: "THE DANGEROUS SHIP YOU SEEK IS AT ORARRA.",
      193: "THERE IS A PARTICULARLY DANGEROUS PIRATE IN THIS SYSTEM.",
    ]
    if let clue = trail[system] { return clue }
    guard [32, 68, 164, 220, 106, 16, 162, 3, 107, 26, 192, 184, 5].contains(system) else {
      return nil
    }
    return [
      "A PECULIAR SHIP WAS REPORTED AT ERRIUS.", "THAT STRANGE SHIP LEFT ERRIUS RECENTLY.",
      "YOU SHOULD INVESTIGATE ERRIUS.", "A SUSPICIOUS NEW SHIP WAS SEEN AT ERRIUS.",
      "LOOK FOR MORE INFORMATION AT ERRIUS.",
    ][variation % 5]
  }
}

extension Commander {
  public var energyRechargeMultiplier: Double {
    if equipment.contains(Equipment.navalEnergyUnit) { return 3 }
    return equipment.contains("Extra Energy Unit") ? 2 : 1
  }
  public func laserDamage(against hull: Hull) -> Double {
    let military = equipment.contains("Military Laser")
    if hull == .constrictor { return military ? 5 : 0 }
    if military { return 23 }
    return equipment.contains("Mining Laser") ? 50 : 15
  }
}

extension Game {
  mutating func progressNavalMissions() {
    guard
      let message = MissionRules.dockingMessage(
        stage: commander.missionStage, galaxy: commander.galaxy, score: commander.kills,
        x: currentSystem.x, y: currentSystem.y)
    else { return }
    switch message {
    case .constrictorBriefing: commander.missionStage = .huntingConstrictor
    case .constrictorDebriefing:
      commander.missionStage = .constrictorComplete
      commander.credits = (commander.credits + 50000) & 0xffff_ffff
      commander.kills = (commander.kills + 256) & 0xffff
    case .ceerdiOrders: commander.missionStage = .reportToCeerdi
    case .plansCollection: commander.missionStage = .carryingPlans
    case .plansDebriefing:
      commander.missionStage = .plansDelivered
      commander.equipment.remove("Extra Energy Unit")
      commander.equipment.insert(Equipment.navalEnergyUnit)
      commander.kills = (commander.kills + 256) & 0xffff
    }
    missionNotice = MissionNotice(
      message: message, commander: commander.name, galaxy: commander.galaxy)
    missionPage = 0
    missionElapsed = 0
    screen = .mission
  }

  mutating func missionKey(_ key: String) {
    guard missionElapsed >= 2 else { return }
    let last = max(0, (missionNotice?.pages.count ?? 1) - 1)
    if key == "left" || key == "up" {
      missionPage = max(0, missionPage - 1)
      return
    }
    if key == "right" || key == "down" {
      missionPage = min(last, missionPage + 1)
      return
    }
    if key == " " || key == "return" || key == "escape" {
      if missionPage < last {
        missionPage += 1
      } else {
        missionNotice = nil
        screen = .status
      }
    }
  }

  mutating func missionTargetRemoved(_ body: SpaceBody) {
    if body.hull == .constrictor && body.navalTarget
      && commander.missionStage == .huntingConstrictor
    {
      // KILLSHP sets TP on removal, including FAROF culling, not just a credited kill.
      commander.missionStage = .constrictorDestroyed
    }
  }

  mutating func spawnNavalEncounter() {
    guard commander.missionStage == .carryingPlans || commander.missionStage == .huntingConstrictor,
      !bodies.contains(where: {
        $0.hull == .viper || ($0.hull == .station && $0.position.length < 600)
      })
    else { return }
    if missionSpawnDelay > 0 {
      missionSpawnDelay -= 1
      return
    }
    let limit = commander.executive ? 18 : 10
    if commander.missionStage == .carryingPlans
      && MissionRules.plansAmbush(randomByte: randomByte())
    {
      let x = randomByte() & 128 == 0 ? 6400.0 : -6400.0
      let y = randomByte() & 128 == 0 ? 6400.0 : -6400.0
      for hull in [Hull.thargoid, .thargon] where bodies.count < limit {
        addNavalShip(hull, position: .init(x, y, 6400))
      }
    }
    guard commander.missionStage == .huntingConstrictor,
      MissionRules.constrictorSystem(
        galaxy: commander.galaxy, x: currentSystem.x, y: currentSystem.y),
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
