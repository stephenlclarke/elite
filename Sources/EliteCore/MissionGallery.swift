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
  var galleryListWindow: ScrollWindow {
    let layout = GalleryLayout(width: viewportWidth, height: viewportHeight)
    let visible = max(1, Int((viewportHeight - layout.listTop - 48) / layout.itemHeight))
    return .init(
      count: missionCatalogue.count, visible: visible,
      offset: max(0, gallery.selection - visible + 1))
  }
  public var missionCatalogue: [GalleryMission] {
    missionPacks.entries.map { packGallery($0) } + missingPackGallery
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
      if gallery.detail {
        gallery.detail = false
        gallery.scroll = 0
      } else {
        closeGallery()
      }
    case "tab":
      gallery.detail.toggle()
      gallery.scroll = 0
    case "return":
      gallery.detail = true
      gallery.scroll = 0
    case "up", "down":
      if gallery.detail {
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
          font: GameTypography.scale
        ).count - visibleRows))
  }
  public mutating func galleryClick(x: Double, y: Double) {
    guard screen == .gallery else { return }
    let layout = GalleryLayout(width: viewportWidth, height: viewportHeight)
    if y < 28 && x > viewportWidth - 160 {
      galleryKey("escape")
      return
    }
    if layout.wide || !gallery.detail {
      if x < (layout.wide ? layout.divider : viewportWidth), y >= layout.listTop {
        let index = Int((y - layout.listTop) / layout.itemHeight) + galleryListWindow.offset
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
  public init(width: Double, height: Double) {
    self.width = width
    self.height = height
    font = GameTypography.scale
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
    frame.label("Esc: Back", width - 16 - 9 * 6 * layout.font, 12, scale: layout.font, ink: .cyan)
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
      let visible = max(1, Int((height - layout.listTop - 48) / layout.itemHeight))
      let first = max(0, game.gallery.selection - visible + 1)
      for (index, mission) in missions.enumerated().dropFirst(first).prefix(visible) {
        let y = layout.listTop + Double(index - first) * layout.itemHeight
        let titleWidth = max(8, Int((listWidth - 48) / (6 * layout.font)))
        let name =
          mission.name.count > titleWidth
          ? String(mission.name.prefix(titleWidth - 3)) + "..." : mission.name
        frame.label(
          (index == game.gallery.selection ? "> " : "  ") + name, 16, y, scale: layout.font,
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
      game.gallery.detail
        ? "Up/Down: read  Tab: list  Esc: back  K: help"
        : "Up/Down: mission  Return: details  Esc: back  K: help", 16, height - 20,
      scale: layout.font,
      ink: .cyan)
    return frame
  }
}
