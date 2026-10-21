import Foundation

public struct DischargeAudioEvent: Sendable, Equatable {
  public let id: UInt64
  public let tool: FlightWorkTool
}

/// Transient simulation events, separate from the lifetime of a rendered laser flash.
public struct DischargeAudioState: Sendable {
  public private(set) var epoch = UUID()
  public private(set) var events: [DischargeAudioEvent] = []
  private var nextID: UInt64 = 0
  public init() {}
  mutating func record(_ tool: FlightWorkTool) {
    if nextID == UInt64.max {
      self = DischargeAudioState()
    }
    nextID += 1
    events.append(.init(id: nextID, tool: tool))
    if events.count > 32 { events.removeFirst(events.count - 32) }
  }
}

/// Repainting or older snapshots within the current epoch cannot replay a discharge.
/// The native frame loop delivers updates sequentially; an epoch change starts a new session.
public struct DischargeAudioFeed: Sendable {
  private var epoch: UUID?
  private var eventID: UInt64 = 0
  public init() {}
  public mutating func update(_ state: DischargeAudioState) -> [FlightWorkTool] {
    if epoch != state.epoch {
      epoch = state.epoch
      eventID = 0
    }
    let fresh = state.events.filter { $0.id > eventID }
    eventID = max(eventID, state.events.last?.id ?? 0)
    return fresh.map(\.tool)
  }
}
