import Foundation

/// Presentation-side event cursor: repeated snapshots cannot repeat a notification.
public struct SpeechFeed: Sendable {
  private var epoch: UUID?
  private var eventID = 0
  private var cursors: [UUID: Int] = [:]
  private var recentEpochs: [UUID] = []
  private var queue = AnnouncementQueue()
  private var previousScreen: Screen?
  public init() {}
  public mutating func update(_ game: Game, busy: Bool) -> String? {
    if epoch != game.ecmControl.epoch {
      if let epoch { cursors[epoch] = eventID }
      let next = game.ecmControl.epoch
      epoch = next
      eventID = cursors[next] ?? 0
      recentEpochs.removeAll { $0 == next }
      recentEpochs.append(next)
      if recentEpochs.count > 64 { cursors.removeValue(forKey: recentEpochs.removeFirst()) }
      queue.clear()
    }
    let fresh = game.ecmControl.events.filter { $0.id > eventID }
    eventID = game.ecmControl.events.last?.id ?? eventID
    defer { previousScreen = game.screen }
    guard game.commander.speech else {
      queue.clear()
      return nil
    }
    queue.append(fresh.map(\.announcement))
    if game.screen == .title && previousScreen != .title { queue.append([.gameplay("Elite")]) }
    return busy ? nil : queue.next()
  }
}
