import Foundation

struct RetaliationOrder: Sendable {
  let source: Int
  let actor: ActorIdentity?
  let expires: Double
}
private struct RetaliationSource: Hashable, Sendable {
  let bodyID: Int
  let actor: ActorIdentity?
}
private struct RetaliationConfirmation: Hashable, Sendable {
  let activation: Int
  let source: RetaliationSource
}
public struct RetaliationControl: Sendable {
  public private(set) var status = ""
  private var seen: Set<Int> = []
  private var identifiedSources: [Int: RetaliationSource] = [:]
  private var confirmed: Set<RetaliationConfirmation> = []
  private var pending: [RetaliationOrder] = []
  public init() {}
  mutating func clear() { self = Self() }
  mutating func detect(_ missiles: [SpaceBody], sources: [SpaceBody]) -> [SpaceBody] {
    let ids = Set(missiles.map(\.id))
    seen.formIntersection(ids)
    var identified: [SpaceBody] = []
    for missile in missiles where seen.insert(missile.id).inserted {
      let owner = missile.physical?.ordnance?.origin.owner
      guard let sourceID = missile.missileSourceID,
        let source = sources.first(where: {
          $0.id == sourceID && $0.energy > 0 && $0.hull.isTargetShip
            && (owner == nil || $0.physical?.identity == owner)
        })
      else { continue }
      if !identified.contains(where: { $0.id == source.id }) { identified.append(source) }
      identifiedSources[source.id] = .init(
        bodyID: source.id, actor: owner ?? source.physical?.identity)
    }
    if identifiedSources.count > 32 {
      identifiedSources = identifiedSources.filter { key, _ in identified.contains { $0.id == key }
      }
    }
    return identified
  }
  mutating func confirm(_ missile: SpaceBody, activation: Int, time: Double) {
    guard missile.enemyMissile, let source = missile.missileSourceID,
      let identified = identifiedSources[source],
      missile.physical?.ordnance.map({ $0.origin.owner == identified.actor }) ?? true
    else { return }
    let key = RetaliationConfirmation(activation: activation, source: identified)
    guard confirmed.insert(key).inserted else { return }
    if confirmed.count > 64 { confirmed = [key] }
    if pending.count < 8 {
      pending.append(.init(source: source, actor: identified.actor, expires: time + 3))
      status = "ECM CONFIRMED - RETURN FIRE PENDING"
    }
  }
  mutating func next(time: Double) -> RetaliationOrder? {
    let before = pending.count
    pending.removeAll { $0.expires < time }
    if pending.isEmpty && before > 0 { status = "RETURN FIRE EXPIRED" }
    return pending.isEmpty ? nil : pending.removeFirst()
  }
  mutating func report(_ text: String) { status = text }
  func pendingResponse(time: Double) -> RetaliationOrder? {
    pending.first { $0.expires >= time }
  }
  mutating func reconcileResponse(bodyID: Int, actor: ActorIdentity) {
    pending.removeAll { $0.source == bodyID && ($0.actor == nil || $0.actor == actor) }
  }
  mutating func expire(time: Double) {
    let before = pending.count
    pending.removeAll { $0.expires < time }
    if pending.isEmpty && before > 0 { status = "RETURN FIRE EXPIRED" }
  }
}

extension Game {
  var militaryRetaliationEnabled: Bool {
    commander.targetingTier == .military && commander.retaliationEnabled
  }
  mutating func detectRetaliationSources() {
    guard militaryRetaliationEnabled else {
      retaliation.clear()
      return
    }
    let threats = bodies.filter { $0.enemyMissile && $0.energy > 0 }
    let sources = retaliation.detect(threats, sources: bodies)
    guard !sources.isEmpty else { return }
    ecmControl.emit(.incomingIdentified)
    for source in sources {
      if !stationAutoDockingActive { weaponsTargetID = source.id }
      ecmControl.emit(.enemyTargeted(source.hull.modelName + " #\(source.id)"))
    }
    retaliation.report("INCOMING SOURCE IDENTIFIED")
  }
  mutating func confirmRetaliation(_ missile: SpaceBody) {
    if militaryRetaliationEnabled && ecmControl.ownFieldActive {
      retaliation.confirm(missile, activation: ecmControl.activation, time: time)
    }
  }
  mutating func advanceRetaliation() {
    if stationAutoDockingActive {
      retaliation.expire(time: time)
      return
    }
    guard militaryRetaliationEnabled, !docked, screen.isFlight, energy > 0 else {
      retaliation.clear()
      return
    }
    guard ecmFrames == 0, missileCooldown == 0, let order = retaliation.next(time: time) else {
      return
    }
    guard
      let target = bodies.first(where: {
        $0.id == order.source && $0.energy > 0 && $0.hull.isTargetShip
          && (order.actor == nil || $0.physical?.identity == order.actor)
      })
    else {
      failRetaliation("Enemy craft no longer available")
      return
    }
    weaponsTargetID = target.id
    guard commander.missiles > 0 || commander.unlimitedMissiles else {
      failRetaliation("No missiles")
      return
    }
    guard target.position.z > 0 else {
      failRetaliation("Enemy outside forward missile lock")
      return
    }
    let wasArmed = missileArmed
    missileArmed = true
    if fireMissile(retaliating: true) {
      retaliation.report("MISSILE LAUNCHED AT ENEMY CRAFT #\(target.id)")
      ecmControl.emit(.missileLaunched(target.hull.modelName + " #\(target.id)"))
    } else {
      missileArmed = wasArmed
      failRetaliation("Missile launch unavailable")
    }
  }
  private mutating func failRetaliation(_ reason: String) {
    retaliation.report("RETURN FIRE: " + reason.uppercased())
    notify("RETURN FIRE: " + reason, voiced: false)
    ecmControl.emit(.cannotRetaliate(reason))
  }
}
