/// One viewport calculation shared by input, rendering and contextual help.
public struct ScrollWindow: Sendable {
  public let count: Int
  public let visible: Int
  public let last: Int
  public let offset: Int
  public init(count: Int, visible: Int, offset: Int) {
    self.count = max(0, count)
    self.visible = max(1, visible)
    last = max(0, count - max(1, visible))
    self.offset = max(0, min(offset, last))
  }
  public func moved(_ amount: Int) -> Int { max(0, min(last, offset + amount)) }
  public var hint: String? {
    guard last > 0 else { return nil }
    let middle = offset == last ? "Up" : "Up/Down"
    let direction = offset == 0 ? "Down" : middle
    return direction + ": scroll \(offset + 1)-\(min(count, offset + visible))/\(count)"
  }
}

extension Game {
  var informationWindow: ScrollWindow {
    let layout = StationLayout(game: self, width: viewportWidth, height: viewportHeight, footer: 28)
    return .init(count: informationRows.count, visible: layout.count, offset: informationScroll)
  }
}
