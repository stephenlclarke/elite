import Foundation

public enum GalleryStatus: String, Sendable {
  case active = "Active"
  case available = "Available"
  case locked = "Locked"
  case complete = "Complete"
  case failed = "Failed"
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
  public var trialDigest: String? = nil
  public var savedInstance: UUID? = nil
  public var progress: String { "\(completed) of \(milestones.count) milestones" }
}
public struct MissionGalleryState: Sendable {
  public var selection = 0 {
    didSet { campaignSelection = nil }
  }
  public var detail = false
  public var scroll = 0
  var campaignLinks = false
  var campaignLinkSelection = 0
  var campaignPreview: GalleryMission?
  var campaignPreviewOwner: UUID?
  var campaignPreviewIdentity: String?
  var campaignReview: CampaignGalleryTrialReview?
  var campaignStartSelected = false
  var campaignTrialRequested = false
  var campaignHistory: [CampaignGalleryLocation] = []
  var campaignSelection: CampaignGallerySelection?
  var presentationGeneration = UUID()
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
      offset: max(0, resolvedGallerySelection - visible + 1))
  }
  public var missionCatalogue: [GalleryMission] {
    missionPacks.entries.map { packGallery($0) } + missingPackGallery + scriptGallery
  }
  public mutating func openGallery() {
    guard
      ![Screen.demo, .title, .gameOver, .help, .secret, .mission, .handoff, .gallery, .showroom]
        .contains(
          screen)
    else { return }
    gallery.previousScreen = screen
    gallery.previouslyPaused = paused
    pinGallerySelection()
    gallery.presentationGeneration = UUID()
    screen = .gallery
  }
  public mutating func closeGallery() {
    gallery.presentationGeneration = UUID()
    gallery.campaignReview = nil
    gallery.campaignTrialRequested = false
    screen = gallery.previousScreen
    paused = gallery.previouslyPaused
  }
  mutating func galleryKey(_ key: String) {
    let previousPage = scriptGalleryPageIdentity
    defer { finishGalleryNavigation(from: previousPage) }
    if gallery.campaignReview != nil {
      switch key {
      case "l": closeGallery()
      case "escape": _ = backInCampaignGallery()
      case "up", "down", "left", "right": gallery.campaignStartSelected.toggle()
      case "return":
        if !gallery.campaignStartSelected { _ = backInCampaignGallery() }
      default: break
      }
      return
    }
    if gallery.detail, gallery.campaignLinks {
      switch key {
      case "l": closeGallery()
      case "up", "down":
        gallery.campaignLinkSelection = max(
          0,
          min(
            campaignGalleryLinks.count - 1, gallery.campaignLinkSelection + (key == "up" ? -1 : 1)))
      case "pageup", "pagedown":
        gallery.campaignLinkSelection = max(
          0,
          min(
            campaignGalleryLinks.count - 1,
            gallery.campaignLinkSelection + (key == "pageup" ? -8 : 8)))
      case "return": followCampaignGalleryLink(gallery.campaignLinkSelection)
      case "escape": _ = backInCampaignGallery()
      case "tab": gallery.campaignLinks = false
      default:
        if key.hasPrefix("gallery-scroll:"), let amount = Int(key.dropFirst(15)) {
          gallery.campaignLinkSelection = max(
            0,
            min(
              campaignGalleryLinks.count - 1, gallery.campaignLinkSelection + amount))
        }
      }
      return
    }
    switch key {
    case "l": closeGallery()
    case "escape":
      if gallery.detail, backInCampaignGallery() {
        return
      } else if gallery.detail {
        gallery.detail = false
        gallery.scroll = 0
      } else {
        closeGallery()
      }
    case "tab":
      gallery.campaignPreview = nil
      gallery.campaignPreviewOwner = nil
      gallery.campaignPreviewIdentity = nil
      gallery.campaignHistory = []
      gallery.detail.toggle()
      gallery.scroll = 0
    case "return":
      if gallery.detail, !campaignGalleryLinks.isEmpty {
        gallery.campaignLinks = true
        gallery.campaignLinkSelection = 0
        return
      }
      gallery.detail = true
      gallery.scroll = 0
    case "up", "down":
      if gallery.detail {
        gallery.scroll += key == "up" ? -1 : 1
      } else {
        gallery.selection = max(
          0, min(missionCatalogue.count - 1, resolvedGallerySelection + (key == "up" ? -1 : 1)))
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
    let visibleRows = max(1, Int((layout.contentBottom - layout.listTop) / layout.row))
    gallery.scroll = max(
      0,
      min(
        gallery.scroll,
        galleryDetailLines(
          width: layout.wide ? viewportWidth - layout.divider - 32 : viewportWidth - 32,
          font: GameTypography.scale
        ).count - visibleRows))
  }
  public mutating func galleryClick(x: Double, y: Double) {
    guard screen == .gallery, x.isFinite, y.isFinite,
      x >= 0, y >= 0, x <= viewportWidth, y <= viewportHeight
    else { return }
    let previousPage = scriptGalleryPageIdentity
    defer { finishGalleryNavigation(from: previousPage) }
    let layout = GalleryLayout(width: viewportWidth, height: viewportHeight)
    if y < 28 && x > viewportWidth - 160 {
      galleryKey("escape")
      return
    }
    if !layout.wide, gallery.detail, y >= 28, y < layout.listTop {
      galleryKey("escape")
      return
    }
    let detailX = layout.wide ? layout.divider + 16 : 16
    if gallery.campaignReview != nil {
      if y >= layout.actionTop, y < layout.actionTop + layout.row {
        if x < detailX + (viewportWidth - detailX - 16) / 2 {
          _ = backInCampaignGallery()
        } else {
          gallery.campaignStartSelected = true
          gallery.campaignTrialRequested = true
        }
      }
      return
    }
    if gallery.detail, gallery.campaignLinks, x >= detailX {
      let first = max(0, gallery.campaignLinkSelection - layout.visibleLinks + 1)
      let index = first + Int((y - layout.listTop) / layout.linkHeight)
      if y >= layout.listTop, y < layout.listTop + Double(layout.visibleLinks) * layout.linkHeight {
        followCampaignGalleryLink(index)
      }
      return
    }
    if layout.wide || gallery.detail, !campaignGalleryLinks.isEmpty,
      x >= detailX, y >= layout.actionTop, y < layout.actionTop + layout.row
    {
      gallery.detail = true
      gallery.campaignLinks = true
      gallery.campaignLinkSelection = 0
      return
    }
    if layout.wide || !gallery.detail {
      if x < (layout.wide ? layout.divider : viewportWidth), y >= layout.listTop {
        let index = Int((y - layout.listTop) / layout.itemHeight) + galleryListWindow.offset
        if missionCatalogue.indices.contains(index) {
          gallery.campaignPreview = nil
          gallery.campaignPreviewOwner = nil
          gallery.campaignPreviewIdentity = nil
          gallery.campaignHistory = []
          gallery.campaignLinks = false
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
    guard let mission = selectedGalleryMission else { return [] }
    let relationshipSummary = campaignGallerySummary(selectedCampaignState)
    let briefing =
      !relationshipSummary.isEmpty && mission.briefing.hasSuffix(relationshipSummary)
      ? String(mission.briefing.dropLast(relationshipSummary.count)) : mission.briefing
    let ending: String
    if mission.status == .failed {
      ending = mission.objective
    } else if mission.status == .complete {
      ending = "Assignment complete."
    } else {
      ending = "Meet the prerequisites, then dock for orders."
    }
    let next = mission.milestones.first { $0.state == "Current" }?.title ?? ending
    let progress =
      gallery.campaignPreview != nil
      ? "Read-only assignment preview"
      : campaignImmediateOwner != nil
        ? "Milestones: \(mission.progress)"
        : "Status: \(mission.status.rawValue) - \(mission.progress)"
    let sections =
      [mission.name] + campaignRelationshipLines + [
        progress, "", "Briefing",
        briefing, "", "Destination (spoilers)", mission.destination, "", "Reward",
        mission.reward, "", "Next step", next, "", "Prerequisites (not completion milestones)",
      ] + mission.prerequisites + ["", "Timeline"]
      + mission.milestones.map { "\($0.state): \($0.title)" }
    return sections.flatMap {
      MissionNotice.wrap($0, width: max(10, Int(min(700, width) / (6 * font))))
    }
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
  var actionTop: Double { height - 66 }
  var contentBottom: Double { height - 76 }
  var linkHeight: Double { row * 4 }
  var visibleLinks: Int { max(1, Int((contentBottom - listTop) / linkHeight)) }
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
      "Active: \(missions.filter { $0.status == .active }.count)  Available: \(missions.filter { $0.status == .available }.count)  Complete: \(missions.filter { $0.status == .complete }.count)  Failed: \(missions.filter { $0.status == .failed }.count)"
    frame.label(counts, 16, 38, scale: layout.font)
    let header: String
    let headerInk: Ink
    if game.isMissionTrial {
      header = "Trial - live commander unchanged"
      headerInk = .cyan
    } else if game.messageTime > 0 {
      header = game.message
      headerInk = .orange
    } else {
      header = game.docked ? "Docked - read-only catalogue" : "Flight paused - read-only catalogue"
      headerInk = .cyan
    }
    frame.label(
      String(header.prefix(max(1, Int((width - 32) / (6 * layout.font))))), 16, 62,
      scale: layout.font, ink: headerInk)
    frame.stroke(0, 88, width, 88, .yellow)
    if layout.wide || !game.gallery.detail {
      let listWidth = layout.wide ? layout.divider : width
      let selection = game.resolvedGallerySelection
      let visible = max(1, Int((height - layout.listTop - 48) / layout.itemHeight))
      let first = max(0, selection - visible + 1)
      for (index, mission) in missions.enumerated().dropFirst(first).prefix(visible) {
        let y = layout.listTop + Double(index - first) * layout.itemHeight
        let titleWidth = max(8, Int((listWidth - 48) / (6 * layout.font)))
        let name =
          mission.name.count > titleWidth
          ? String(mission.name.prefix(titleWidth - 3)) + "..." : mission.name
        frame.label(
          (index == selection ? "> " : "  ") + name, 16, y, scale: layout.font,
          ink: index == selection ? .cyan : .white)
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
      if !campaignGalleryDetail(&frame, game: game, layout: layout, x: x, width: detailWidth) {
        let lines = game.galleryDetailLines(width: detailWidth, font: layout.font)
        let count = max(1, Int((layout.contentBottom - layout.listTop) / layout.row))
        let offset = min(game.gallery.scroll, max(0, lines.count - count))
        for (index, line) in lines.dropFirst(offset).prefix(count).enumerated() {
          frame.label(line, x, layout.listTop + Double(index) * layout.row, scale: layout.font)
        }
        frame.label(
          "Lines \(offset + 1)-\(min(lines.count, offset + count)) of \(lines.count)", x,
          height - 40,
          scale: layout.font, ink: .yellow)
        if !game.campaignGalleryLinks.isEmpty {
          frame.label(
            "Return / click: Campaign links", x, layout.actionTop,
            scale: layout.font, ink: .cyan)
        }
      }
      if !layout.wide {
        frame.label(
          "Esc: Back to missions", 16, 84 - 7 * layout.font, scale: layout.font, ink: .cyan)
      }
    }
    var actions =
      game.gallery.detail
      ? "Arrows: read  Tab: list  Esc: back" : "Arrows: mission  Return: details  Esc: back"
    if game.canTrialSelectedMission { actions += "  T: trial" }
    if game.campaignImmediateOwner != nil { actions = "Return: links  T: Try campaign  Esc: back" }
    if game.gallery.campaignLinks { actions = "Arrows: link  Return / click: open  Esc: back" }
    if game.gallery.campaignReview != nil {
      actions = "Arrows: choice  Return / click: choose  Esc: back"
    }
    if game.canRetrySelectedMission, game.gallery.campaignReview == nil,
      !game.gallery.campaignLinks
    {
      actions += "  R: retry"
    }
    frame.label(actions, 16, height - 20, scale: layout.font, ink: .cyan)
    return frame
  }
}
