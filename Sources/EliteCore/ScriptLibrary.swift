import Foundation

public enum ScriptLibraryMode: String, Codable, Sendable { case books, contents, reading, source }
public struct ScriptLibraryState: Codable, Sendable, Equatable {
  public var mode: ScriptLibraryMode = .books
  public var selected: String?
  public var chapter = 0
  public var scroll = 0
  public var previous: Screen = .status
  public var sourceReturn: ScriptLibraryMode = .contents
  public init() {}
  var valid: Bool {
    previous != .library && (0..<64).contains(chapter) && (0...100000).contains(scroll)
      && [.books, .contents, .reading].contains(sourceReturn)
      && (selected.map { $0.utf8.count <= 161 } ?? true)
  }
}

enum ScriptLibraryText {
  /// URLs and hashes can exceed a paragraph word width; retain every character inside the pane.
  static func wrap(_ text: String, width: Int) -> [String] {
    let columns = max(1, width)
    return MissionNotice.wrap(text.uppercased(), width: columns).flatMap { line -> [String] in
      guard line.count > columns else { return [line] }
      var result: [String] = []
      var start = line.startIndex
      while start < line.endIndex {
        let end = line.index(start, offsetBy: columns, limitedBy: line.endIndex) ?? line.endIndex
        result.append(String(line[start..<end]))
        start = end
      }
      return result
    }
  }
}

extension Game {
  public var selectedReferenceBook: ScriptBookRecord? {
    referenceBooks.first { $0.key == library.selected } ?? referenceBooks.first
  }
  var libraryChapter: ScriptBookChapter? {
    guard let chapters = selectedReferenceBook?.book.chapters else { return nil }
    return chapters[max(0, min(library.chapter, chapters.count - 1))]
  }
  var librarySelectedIndex: Int {
    if library.mode == .books {
      return referenceBooks.firstIndex { $0.key == library.selected } ?? 0
    }
    return library.chapter
  }
  func libraryListWindow(height: Double) -> ScrollWindow {
    let count =
      library.mode == .books
      ? referenceBooks.count : selectedReferenceBook?.book.chapters.count ?? 0
    let visible = max(1, Int((height - 190) / 44))
    return .init(count: count, visible: visible, offset: max(0, librarySelectedIndex - visible + 1))
  }
  func libraryTextLines(width: Double) -> [String] {
    let text: String
    if library.mode == .source, let book = selectedReferenceBook {
      text =
        "Source: " + book.source + "\n\nLicence: " + book.license
        + "\n\nVersion: " + book.version + "\nProvider: " + book.provider
        + "\n\nContent: " + book.digest
    } else {
      text = libraryChapter?.text ?? ""
    }
    return ScriptLibraryText.wrap(
      text, width: max(10, Int(min(700, width - 48) / (6 * GameTypography.scale))))
  }
  func libraryTextWindow(width: Double, height: Double) -> ScrollWindow {
    .init(
      count: libraryTextLines(width: width).count, visible: max(1, Int((height - 220) / 19)),
      offset: library.scroll)
  }
  mutating func openReferenceLibrary() {
    if screen == .library {
      screen = library.previous
      return
    }
    library.previous = screen
    library.mode = .books
    library.scroll = 0
    library.selected = selectedReferenceBook?.key
    screen = .library
  }
  mutating func libraryKey(_ key: String) {
    guard screen == .library else { return }
    if key == "escape" {
      switch library.mode {
      case .books: screen = library.previous
      case .contents: library.mode = .books
      case .reading: library.mode = .contents
      case .source: library.mode = library.sourceReturn
      }
      library.scroll = 0
      return
    }
    if key == "i", selectedReferenceBook != nil {
      if library.mode == .source {
        library.mode = library.sourceReturn
      } else {
        library.sourceReturn = library.mode
        library.mode = .source
      }
      library.scroll = 0
      return
    }
    switch library.mode {
    case .books:
      let books = referenceBooks
      guard !books.isEmpty else { return }
      let index = books.firstIndex { $0.key == library.selected } ?? 0
      if key == "up" || key == "down" {
        library.selected = books[max(0, min(books.count - 1, index + (key == "up" ? -1 : 1)))].key
        library.chapter = 0
      }
      if key == "return" || key == "tab" { library.mode = .contents }
    case .contents:
      guard let book = selectedReferenceBook else { return }
      if key == "up" || key == "down" {
        library.chapter = max(
          0, min(book.book.chapters.count - 1, library.chapter + (key == "up" ? -1 : 1)))
      }
      if key == "return" || key == "tab" {
        library.mode = .reading
        library.scroll = 0
      }
    case .reading, .source:
      if key == "up" || key == "down" || key == "pageup" || key == "pagedown" {
        let amount = (key == "up" || key == "pageup" ? -1 : 1) * (key.hasPrefix("page") ? 8 : 1)
        library.scroll = libraryTextWindow(width: viewportWidth, height: viewportHeight).moved(
          amount)
      }
      if key == "tab" {
        library.mode = .contents
        library.scroll = 0
      }
      if library.mode == .reading, key == "left" || key == "right", let book = selectedReferenceBook
      {
        library.chapter = max(
          0, min(book.book.chapters.count - 1, library.chapter + (key == "left" ? -1 : 1)))
        library.scroll = 0
      }
    }
  }
  public mutating func libraryClick(x: Double, y: Double) {
    let width = min(700, viewportWidth - 48)
    let left = (viewportWidth - width) / 2
    guard screen == .library, x.isFinite, y.isFinite, x >= left, x < left + width else { return }
    if y >= viewportHeight - 68, y < viewportHeight - 40 {
      if x < left + width / 3 {
        libraryKey("escape")
      } else if x < left + width * 2 / 3 {
        libraryKey("i")
      } else {
        libraryKey(library.mode == .books || library.mode == .contents ? "return" : "tab")
      }
      return
    }
    guard library.mode == .books || library.mode == .contents, y >= 84, y < viewportHeight - 106
    else { return }
    let window = libraryListWindow(height: viewportHeight)
    let index = window.offset + Int((y - 84) / 44)
    guard index < window.count else { return }
    if library.mode == .books {
      library.selected = referenceBooks[index].key
      library.chapter = 0
      library.mode = .contents
    } else {
      library.chapter = index
      library.mode = .reading
    }
    library.scroll = 0
  }
}

extension GameRuntime {
  public func libraryClick(x: Double, y: Double) { game.libraryClick(x: x, y: y) }
}
