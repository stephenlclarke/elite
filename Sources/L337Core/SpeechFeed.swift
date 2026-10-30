import Foundation

/// Presentation-side event cursor: repeated snapshots cannot repeat a notification.
public struct SpeechFeed: Sendable {
  private struct Cursor: Sendable {
    let epoch: UUID
    var eventID = 0
    var previousScreen: Screen?
  }

  static let namespaceLimit = 16
  private var cursors: [Cursor] = []
  private var epoch: UUID?
  private var queue = AnnouncementQueue()
  var retainedNamespaceCount: Int { cursors.count }
  public init() {}
  public mutating func update(_ game: Game, busy: Bool) -> String? {
    if epoch != game.ecmControl.epoch {
      epoch = game.ecmControl.epoch
      queue.clear()
    }
    var cursor: Cursor
    if let index = cursors.firstIndex(where: { $0.epoch == game.ecmControl.epoch }) {
      cursor = cursors.remove(at: index)
    } else {
      cursor = Cursor(epoch: game.ecmControl.epoch)
    }
    let fresh = game.ecmControl.events.filter { $0.id > cursor.eventID }
    cursor.eventID = max(cursor.eventID, game.ecmControl.events.last?.id ?? cursor.eventID)
    let screen = game.screen
    defer {
      cursor.previousScreen = screen
      // Recently used live namespaces survive repeated temporary trials; history stays bounded.
      if cursors.count == Self.namespaceLimit { cursors.removeFirst() }
      cursors.append(cursor)
    }
    guard game.commander.speech else {
      queue.clear()
      return nil
    }
    queue.append(fresh.map(\.announcement))
    if screen == .title && cursor.previousScreen != .title {
      queue.append([.gameplay(NewCommanderDefaults.title)])
    }
    return busy ? nil : queue.next()
  }
}
