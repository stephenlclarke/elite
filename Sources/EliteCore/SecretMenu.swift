extension Game {
  var secretRows: [(String, String)] {
    let layout = CompactLayout(game: self, width: viewportWidth, height: viewportHeight)
    return secretChoices.flatMap { choice in
      MissionNotice.wrap(choice, width: layout.columns).map {
        (String(choice.prefix(1)).lowercased(), $0)
      }
    }
  }
  var secretWindow: ScrollWindow {
    let layout = CompactLayout(game: self, width: viewportWidth, height: viewportHeight)
    return .init(
      count: secretRows.count, visible: max(1, Int((layout.bottom - 76 - 70) / layout.row)),
      offset: secretScroll)
  }
  public mutating func secretClick(x: Double, y: Double) {
    guard screen == .secret else { return }
    let layout = CompactLayout(game: self, width: viewportWidth, height: viewportHeight)
    guard x >= layout.left, x < layout.left + layout.width, y >= 76 else { return }
    let row = Int((y - 76) / layout.row)
    let index = secretWindow.offset + row
    guard row < secretWindow.visible, secretRows.indices.contains(index) else { return }
    secretKey(secretRows[index].0)
  }
}
