import Foundation

/// Glyph size is in logical macOS points, independent of window and backing size.
public enum GameTypography {
  public static let scale = 1.25
  public static let row = 18.0
}

struct CompactLayout {
  let left: Double
  let width: Double
  let bottom: Double
  let font = GameTypography.scale
  let row = GameTypography.row
  var columns: Int { Int(width / (6 * font)) }
  init(game: Game, width: Double, height: Double, plain: Bool = false) {
    self.width = min(680, width - 48)
    left = (width - self.width) / 2
    bottom = plain ? height : CockpitLayout(game: game, width: width, height: height).dashboardTop
  }
}

extension Frame {
  mutating func compactTitle(_ text: String, layout: CompactLayout) {
    label(text, layout.left, 12, scale: layout.font, ink: .yellow)
    stroke(layout.left, 34, layout.left + layout.width, 34, .yellow)
  }
  mutating func compactRows(_ rows: [(String, Ink)], layout: CompactLayout, top: Double) {
    var y = top
    for (text, ink) in rows {
      for line in MissionNotice.wrap(text, width: layout.columns) {
        label(line, layout.left, y, scale: layout.font, ink: ink)
        y += layout.row
      }
    }
  }
}
