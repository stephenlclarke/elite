import Foundation

public enum GalleryStatus: String, Sendable {
  case active = "Active"
  case available = "Available"
  case locked = "Locked"
  case complete = "Complete"
}
public struct MissionMilestone: Sendable {
  public let title: String
  public let state: String
}
public struct GalleryMission: Sendable {
  public let name: String
  public let status: GalleryStatus
  public let objective: String
  public let briefing: String
  public let destination: String
  public let reward: String
  public let prerequisites: [String]
  public let completed: Int
  public let milestones: [MissionMilestone]
  public var progress: String { "\(completed) of \(milestones.count) milestones" }
}
public struct MissionGalleryState: Sendable {
  public var selection = 0
  public var detail = false
  public var scroll = 0
  var previousScreen: Screen = .status
  var previouslyPaused = false
  public init() {}
}

extension Game {
  /// Source TP values are deliberately mapped by meaning, never by numeric order.
  public var missionCatalogue: [GalleryMission] {
    let stage = commander.missionStage
    let huntProgress: Int
    let plansProgress: Int
    switch stage {
    case .notStarted:
      huntProgress = 0
      plansProgress = 0
    case .huntingConstrictor:
      huntProgress = 1
      plansProgress = 0
    case .constrictorDestroyed:
      huntProgress = 2
      plansProgress = 0
    case .constrictorComplete:
      huntProgress = 3
      plansProgress = 0
    case .reportToCeerdi:
      huntProgress = 3
      plansProgress = 1
    case .carryingPlans:
      huntProgress = 3
      plansProgress = 2
    case .plansDelivered:
      huntProgress = 3
      plansProgress = 3
    }
    let huntAvailable = commander.kills >= 256 && commander.galaxy < 2
    let plansAvailable = huntProgress == 3 && commander.kills >= 1280 && commander.galaxy == 2
    func status(_ progress: Int, available: Bool) -> GalleryStatus {
      if progress == 3 { return .complete }
      if progress > 0 { return .active }
      return available ? .available : .locked
    }
    func steps(_ names: [String], progress: Int, available: Bool) -> [MissionMilestone] {
      names.enumerated().map { index, name in
        let state: String
        if index < progress {
          state = "Complete"
        } else if index == progress && (progress > 0 || available) {
          state = "Current"
        } else {
          state = progress > 0 || available ? "Upcoming" : "Locked"
        }
        return .init(title: name, state: state)
      }
    }
    return [
      .init(
        name: "Constrictor Hunt", status: status(huntProgress, available: huntAvailable),
        objective: stage == .constrictorDestroyed
          ? "Dock for your naval debriefing."
          : "Find and remove the stolen Constrictor, then report to the Navy.",
        briefing:
          "The Navy's experimental warship has been stolen. Follow system reports across the first two galaxies. Its shields require military lasers; it carries ECM. Optional clues do not count as required milestones.",
        destination: "Galaxies 1 and 2. Spoiler: Orarra, Galaxy 2 (144,33). Debrief at a station.",
        reward: "5,000 CR and 256 combat points, awarded on docking after target removal.",
        prerequisites: [
          "Combat points: \(commander.kills) of 256 required to receive orders.",
          "Receive orders while docked in Galaxy 1 or 2. Current: \(commander.galaxy + 1).",
        ],
        completed: huntProgress,
        milestones: steps(
          ["Receive naval assignment", "Remove the Constrictor", "Dock for debriefing and reward"],
          progress: huntProgress, available: huntAvailable)),
      .init(
        name: "Thargoid Plans", status: status(plansProgress, available: plansAvailable),
        objective: stage == .carryingPlans
          ? "Carry the plans to Birera and dock."
          : "Report to Ceerdi, collect the plans and deliver them to Birera.",
        briefing:
          "Naval Intelligence needs a courier for captured Thargoid defence plans. Reach Ceerdi for collection, then deliver to Birera. Expect Thargoid opposition while carrying the plans.",
        destination: "Galaxy 3: Ceerdi (215,84), then Birera (63,72). Dock at each destination.",
        reward:
          "Naval Energy Unit and 256 combat points on delivery. The unit replaces a standard energy unit.",
        prerequisites: [
          "Constrictor Hunt: \(huntProgress == 3 ? "complete" : "required").",
          "Combat points: \(commander.kills) of 1280 required to receive orders.",
          "Receive orders in Galaxy 3. Current: \(commander.galaxy + 1).",
        ],
        completed: plansProgress,
        milestones: steps(
          [
            "Receive orders to report to Ceerdi", "Dock at Ceerdi and collect plans",
            "Dock at Birera for delivery and reward",
          ], progress: plansProgress, available: plansAvailable)),
    ] + [blackjackGalleryMission]
  }
  public mutating func openGallery() {
    guard
      ![Screen.demo, .title, .gameOver, .help, .secret, .mission, .handoff, .gallery, .showroom]
        .contains(
          screen)
    else { return }
    gallery.previousScreen = screen
    gallery.previouslyPaused = paused
    screen = .gallery
  }
  public mutating func closeGallery() {
    screen = gallery.previousScreen
    paused = gallery.previouslyPaused
  }
  mutating func galleryKey(_ key: String) {
    switch key {
    case "l": closeGallery()
    case "escape":
      if gallery.detail && viewportWidth < 900 {
        gallery.detail = false
        gallery.scroll = 0
      } else {
        closeGallery()
      }
    case "return":
      gallery.detail = true
      gallery.scroll = 0
    case "up", "down":
      if gallery.detail && viewportWidth < 900 {
        gallery.scroll += key == "up" ? -1 : 1
      } else {
        gallery.selection = max(
          0, min(missionCatalogue.count - 1, gallery.selection + (key == "up" ? -1 : 1)))
        gallery.scroll = 0
      }
    case "pageup": gallery.scroll -= 8
    case "pagedown": gallery.scroll += 8
    default:
      if key.hasPrefix("gallery-scroll:"), let amount = Int(key.dropFirst(15)) {
        gallery.scroll += amount
      }
    }
    let layout = GalleryLayout(width: viewportWidth, height: viewportHeight)
    let visibleRows = max(1, Int((viewportHeight - layout.listTop - 48) / layout.row))
    gallery.scroll = max(
      0,
      min(
        gallery.scroll,
        galleryDetailLines(
          width: viewportWidth < 900 ? viewportWidth - 32 : viewportWidth * 0.64 - 32,
          font: GalleryLayout.font(viewportWidth)
        ).count - visibleRows))
  }
  public mutating func galleryClick(x: Double, y: Double) {
    guard screen == .gallery else { return }
    let layout = GalleryLayout(width: viewportWidth, height: viewportHeight)
    if y < 28 && x > viewportWidth - 160 {
      closeGallery()
      return
    }
    if layout.wide || !gallery.detail {
      if x < (layout.wide ? layout.divider : viewportWidth), y >= layout.listTop {
        let index = Int((y - layout.listTop) / layout.itemHeight)
        if missionCatalogue.indices.contains(index) {
          gallery.selection = index
          gallery.detail = true
          gallery.scroll = 0
        }
      }
    } else if y < layout.listTop {
      gallery.detail = false
      gallery.scroll = 0
    }
  }
  func galleryDetailLines(width: Double, font: Double) -> [String] {
    let mission = missionCatalogue[gallery.selection]
    let next =
      mission.milestones.first { $0.state == "Current" }?.title
      ?? (mission.status == .complete
        ? "Assignment complete." : "Meet the prerequisites, then dock for orders.")
    let sections =
      [
        mission.name, "Status: \(mission.status.rawValue) - \(mission.progress)", "", "Briefing",
        mission.briefing, "", "Destination (spoilers)", mission.destination, "", "Reward",
        mission.reward, "", "Next step", next, "", "Prerequisites (not completion milestones)",
      ] + mission.prerequisites + ["", "Timeline"]
      + mission.milestones.map { "\($0.state): \($0.title)" }
    return sections.flatMap { MissionNotice.wrap($0, width: max(10, Int(width / (6 * font)))) }
  }
}

public struct GalleryLayout: Sendable {
  public let width: Double
  public let height: Double
  public let font: Double
  public let row: Double
  public let wide: Bool
  public let divider: Double
  public let listTop = 104.0
  public let itemHeight = 116.0
  static func font(_ width: Double) -> Double { GameTypography.scale }
  public init(width: Double, height: Double) {
    self.width = width
    self.height = height
    font = Self.font(width)
    row = ceil(font * 7) + 8
    wide = width >= 900
    divider = floor(width * 0.34)
  }
}

extension Display {
  public static func gallery(_ game: Game, width: Double, height: Double) -> Frame {
    let layout = GalleryLayout(width: width, height: height)
    var frame = Frame()
    frame.responsive = true
    frame.rasterizeGraphics = false
    frame.canvas = .init(x: 0, y: 0, width: width, height: height)
    frame.label("MISSION GALLERY", 16, 12, scale: layout.font, ink: .yellow)
    frame.label("L: Close", width - 16 - 8 * 6 * layout.font, 12, scale: layout.font, ink: .cyan)
    let missions = game.missionCatalogue
    let counts =
      "Active: \(missions.filter { $0.status == .active }.count)  Available: \(missions.filter { $0.status == .available }.count)  Complete: \(missions.filter { $0.status == .complete }.count)"
    frame.label(counts, 16, 38, scale: layout.font)
    frame.label(
      game.docked ? "Docked - read-only catalogue" : "Flight paused - read-only catalogue", 16, 62,
      scale: layout.font, ink: .cyan)
    frame.stroke(0, 88, width, 88, .yellow)
    if layout.wide || !game.gallery.detail {
      let listWidth = layout.wide ? layout.divider : width
      for (index, mission) in missions.enumerated() {
        let y = layout.listTop + Double(index) * layout.itemHeight
        frame.label(
          (index == game.gallery.selection ? "> " : "  ") + mission.name, 16, y, scale: layout.font,
          ink: index == game.gallery.selection ? .cyan : .white)
        frame.label(
          mission.status.rawValue + " - " + mission.progress, 28, y + layout.row,
          scale: layout.font, ink: .yellow)
        let lines = MissionNotice.wrap(
          mission.objective, width: Int((listWidth - 48) / (6 * layout.font)))
        for (row, line) in lines.prefix(3).enumerated() {
          frame.label(line, 28, y + layout.row * Double(row + 2), scale: layout.font)
        }
      }
    }
    if layout.wide { frame.stroke(layout.divider, 88, layout.divider, height - 42, .blue) }
    if layout.wide || game.gallery.detail {
      let x = layout.wide ? layout.divider + 16 : 16
      let detailWidth = width - x - 16
      let lines = game.galleryDetailLines(width: detailWidth, font: layout.font)
      let count = max(1, Int((height - layout.listTop - 48) / layout.row))
      let offset = min(game.gallery.scroll, max(0, lines.count - count))
      for (index, line) in lines.dropFirst(offset).prefix(count).enumerated() {
        frame.label(line, x, layout.listTop + Double(index) * layout.row, scale: layout.font)
      }
      if !layout.wide {
        frame.label(
          "Esc: Back to missions", 16, 84 - 7 * layout.font, scale: layout.font, ink: .cyan)
      }
      frame.label(
        "Lines \(offset + 1)-\(min(lines.count, offset + count)) of \(lines.count)", x, height - 40,
        scale: layout.font, ink: .yellow)
    }
    frame.label(
      "Arrows: Select  Enter: Detail  PgUp/PgDn: Scroll", 16, height - 20, scale: layout.font,
      ink: .cyan)
    return frame
  }
}
