import Foundation

extension Display {
  public static func referenceLibrary(_ game: Game, width: Double, height: Double) -> Frame {
    var frame = Frame()
    frame.responsive = true
    frame.rasterizeGraphics = false
    frame.canvas = .init(x: 0, y: 0, width: width, height: height)
    let font = GameTypography.scale
    let contentWidth = min(700, width - 48)
    let left = (width - contentWidth) / 2
    let title =
      game.library.mode == .books
      ? "MISSION LIBRARY" : game.selectedReferenceBook?.book.title ?? "MISSION LIBRARY"
    for (index, line) in ScriptLibraryText.wrap(
      title, width: max(10, Int(contentWidth / (6 * font)))
    )
    .prefix(2).enumerated() {
      frame.label(line, left, 20 + Double(index) * 19, scale: font, ink: .yellow)
    }
    if game.referenceBooks.isEmpty {
      frame.label("No reference books unlocked yet.", left, 84, scale: font)
      frame.label("Mission briefings can add books to this library.", left, 110, scale: font)
    } else if game.library.mode == .books || game.library.mode == .contents {
      frame.label(
        game.library.mode == .books ? "Reference books" : "Contents", left, 58, scale: font,
        ink: .cyan)
      let window = game.libraryListWindow(height: height)
      for index in window.offset..<min(window.count, window.offset + window.visible) {
        let text: String
        let level: Int
        if game.library.mode == .books {
          text = game.referenceBooks[index].book.title
          level = 0
        } else {
          let chapter = game.selectedReferenceBook!.book.chapters[index]
          text = chapter.title
          level = chapter.level
        }
        let indent = Double(level * 10)
        let lines = ScriptLibraryText.wrap(
          text, width: max(10, Int((contentWidth - indent - 20) / (6 * font))))
        let selected = index == game.librarySelectedIndex
        for (offset, line) in lines.prefix(2).enumerated() {
          frame.label(
            (offset == 0 && selected ? "> " : "  ") + line,
            left + indent, 84 + Double(index - window.offset) * 44 + Double(offset) * 19,
            scale: font, ink: selected ? .cyan : .white)
        }
      }
      if let hint = window.hint { frame.label(hint, left, height - 100, scale: font, ink: .cyan) }
    } else {
      let heading =
        game.library.mode == .source ? "Book source and licence" : game.libraryChapter?.title ?? ""
      for (index, line) in ScriptLibraryText.wrap(
        heading, width: max(10, Int(contentWidth / (6 * font)))
      ).prefix(2).enumerated() {
        frame.label(line, left, 66 + Double(index) * 19, scale: font, ink: .cyan)
      }
      let lines = game.libraryTextLines(width: width)
      let window = game.libraryTextWindow(width: width, height: height)
      for (index, line) in lines.dropFirst(window.offset).prefix(window.visible).enumerated() {
        frame.label(line, left, 120 + Double(index) * 19, scale: font)
      }
      if let hint = window.hint { frame.label(hint, left, height - 100, scale: font, ink: .cyan) }
    }
    frame.label("Back", left, height - 64, scale: font, ink: .cyan)
    frame.label("Source / licence", left + contentWidth / 3, height - 64, scale: font, ink: .cyan)
    frame.label(
      game.library.mode == .books || game.library.mode == .contents ? "Open" : "Contents",
      left + contentWidth * 2 / 3, height - 64, scale: font, ink: .cyan)
    frame.label(
      game.library.mode == .reading || game.library.mode == .source
        ? "Arrows: read  Tab: contents  I: source  Esc: back"
        : "Arrows: choose  Return: open  I: source  Esc: back",
      left, height - 22, scale: font)
    return frame
  }
}
