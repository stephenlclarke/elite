import Foundation

public struct PackOffer: Sendable {
  public let stateID: String
  public let transitionID: String
  public let galaxy: Int
  public let system: Int
  public let committed: Bool
  public var confirmSelected = true
}

extension Game {
  func missionEncounter(_ kind: String, location: Bool = true) -> PackEncounter? {
    for entry in missionPacks.entries where packMatchesSave(entry) {
      let state = progress(for: entry)
      if let encounter = entry.pack.encounters?.first(where: {
        $0.kind == kind && $0.stage == state.stage
          && (!location || $0.galaxy == nil || $0.galaxy == commander.galaxy)
          && (!location || $0.system == nil || $0.system == commander.system)
      }) {
        return encounter
      }
    }
    return nil
  }
  func progress(for entry: LoadedMissionPack) -> MissionProgress {
    let pack = entry.pack
    var result =
      commander.missionProgress[pack.stateID]
      ?? MissionProgress(
        version: pack.version, digest: entry.digest, stage: pack.mission.initialStage)
    // These mirrors also support older saves and callers that still use the public legacy APIs.
    if let binding = pack.mission.binding {
      let raw =
        binding == "naval" ? commander.missionStage.rawValue : commander.blackjack.stage.rawValue
      if let stage = pack.stages.first(where: { $0.legacyValues?.contains(raw) == true }) {
        result.stage = stage.id
      }
      if binding == "blackjack" {
        result.flags["pendingGold"] = commander.blackjack.pendingGold ? 1 : 0
        for receipt in BlackjackTransfer.allCases {
          if commander.blackjack.transfers.contains(receipt) {
            result.receipts.insert(receipt.rawValue)
          } else {
            result.receipts.remove(receipt.rawValue)
          }
        }
      }
    }
    return result
  }
  func packMatchesSave(_ entry: LoadedMissionPack) -> Bool {
    guard let saved = commander.missionProgress[entry.pack.stateID] else { return true }
    return saved.version == entry.pack.version && saved.digest == entry.digest
      && entry.pack.stage(saved.stage) != nil
  }
  mutating func migrateMissionProgress() {
    for entry in missionPacks.entries where entry.pack.mission.binding != nil {
      if commander.missionProgress[entry.pack.stateID] != nil && packMatchesSave(entry) {
        commander.missionProgress[entry.pack.stateID] = progress(for: entry)
      }
    }
  }
  func conditionValue(_ field: String, state: MissionProgress) -> Double? {
    switch field {
    case "galaxy": return Double(commander.galaxy)
    case "system": return Double(commander.system)
    case "x": return currentSystem.x
    case "y": return currentSystem.y
    case "kills": return Double(commander.kills)
    case "credits": return Double(commander.credits)
    case "legal": return Double(commander.legal)
    case "mainStation": return docked && dockedAtMainStation ? 1 : 0
    case "freeTonnes": return Double(commander.capacity - commander.cargoTonnes)
    case "stageSeconds": return state.seconds
    case "navalStage": return Double(commander.missionStage.rawValue)
    default:
      let parts = field.split(separator: ":", maxSplits: 1).map(String.init)
      guard parts.count == 2 else { return nil }
      switch parts[0] {
      case "flag": return Double(state.flags[parts[1]] ?? 0)
      case "receipt": return state.receipts.contains(parts[1]) ? 1 : 0
      case "payload": return Double(state.payloads[parts[1]] ?? 0)
      case "cargo":
        return Int(parts[1]).flatMap {
          commander.cargo.indices.contains($0) ? Double(commander.cargo[$0]) : nil
        }
      default: return nil
      }
    }
  }
  func matches(_ conditions: [PackCondition], state: MissionProgress, target: String?) -> Bool {
    conditions.allSatisfy { condition in
      if condition.field == "target" {
        return condition.op == "eq" ? target == condition.text : target != condition.text
      }
      guard let actual = conditionValue(condition.field, state: state),
        let expected = condition.value
      else { return false }
      switch condition.op {
      case "eq": return actual == expected
      case "ne": return actual != expected
      case "lt": return actual < expected
      case "le": return actual <= expected
      case "gt": return actual > expected
      case "ge": return actual >= expected
      default: return false
      }
    }
  }
  @discardableResult
  mutating func dispatchMission(_ event: PackEvent, naval: Bool = false, target: String? = nil)
    -> Bool
  {
    for entry in missionPacks.entries {
      let pack = entry.pack
      guard (pack.mission.binding == "naval") == naval, packMatchesSave(entry) else { continue }
      let state = progress(for: entry)
      guard pack.stage(state.stage)?.terminal != true else { continue }
      guard
        let transition = pack.transitions.first(where: {
          $0.event == event && $0.from == state.stage
            && matches($0.conditions ?? [], state: state, target: target)
            && !state.receipts.contains("transition." + $0.id)
        })
      else { continue }
      if transition.confirmation == true {
        showPackOffer(entry, transition: transition, committed: false)
        return true
      }
      guard commitMission(entry, transition: transition, target: target) else { continue }
      if transition.dialog != nil {
        if naval {
          showNavalDialog(transition: transition)
        } else {
          showPackOffer(entry, transition: transition, committed: true)
        }
        return true
      }
    }
    return false
  }
  mutating func commitMission(
    _ entry: LoadedMissionPack, transition: PackTransition, target: String? = nil
  ) -> Bool {
    let pack = entry.pack
    var state = progress(for: entry)
    guard packMatchesSave(entry), state.stage == transition.from,
      !state.receipts.contains("transition." + transition.id),
      matches(transition.conditions ?? [], state: state, target: target)
    else { return false }
    var candidate = commander
    candidate.missionProgress[pack.stateID] = state
    // Location, current stage and replay checks above authorize this exact bundled handoff.
    var reservedCargo = PackReservedCargoPermit.blackjackHandoff(
      commander: candidate, entry: entry, transition: transition, state: state)
    do {
      for action in transition.actions ?? [] {
        try candidate.apply(action, state: &state, reservedCargo: &reservedCargo)
        candidate.missionProgress[pack.stateID] = state
      }
      state.stage = transition.to
      if transition.from != transition.to { state.seconds = 0 }
      state.receipts.insert("transition." + transition.id)
      candidate.missionProgress[pack.stateID] = state
      candidate.mirror(pack, state: state)
      guard candidate.valid else {
        throw MissionPackError("Transfer cannot fit the current commander/hold.")
      }
    } catch {
      notify(error.localizedDescription.uppercased())
      return false
    }
    // Stage scalar resources after all fallible checks without another whole-Game copy.
    let oldEnergyCapacity = commander.performance.energy
    let newEnergyCapacity = candidate.performance.energy
    let nextEnergy =
      oldEnergyCapacity == newEnergyCapacity
      ? energy
      : Self.equipmentResourceLevel(
        energy, from: oldEnergyCapacity, to: newEnergyCapacity)
    let oldFrontCapacity = commander.shieldCapacity
    let newFrontCapacity = candidate.shieldCapacity
    let nextFront =
      oldFrontCapacity == newFrontCapacity
      ? frontShield
      : Self.equipmentResourceLevel(
        frontShield, from: oldFrontCapacity, to: newFrontCapacity)
    let oldRearCapacity = commander.rearShieldCapacity
    let newRearCapacity = candidate.rearShieldCapacity
    let nextRear =
      oldRearCapacity == newRearCapacity
      ? rearShield
      : Self.equipmentResourceLevel(
        rearShield, from: oldRearCapacity, to: newRearCapacity)
    commander = candidate
    energy = nextEnergy
    frontShield = nextFront
    rearShield = nextRear
    if let text = transition.notification { notify(text) }
    return true
  }
  mutating func advanceMissionClock(_ delta: Double) {
    for entry in missionPacks.entries
    where entry.pack.capabilities.contains("clock-v1") && packMatchesSave(entry) {
      var state = progress(for: entry)
      guard entry.pack.stage(state.stage)?.terminal != true else { continue }
      state.seconds = min(1_000_000_000, state.seconds + delta)
      commander.missionProgress[entry.pack.stateID] = state
    }
    _ = dispatchMission(.clock)
  }
  func packText(_ text: String) -> String {
    let replacements = [
      "commander": commander.name, "galaxy": String(commander.galaxy + 1),
      "kills": String(commander.kills),
      "captain": OriginalContactIdentity.huntCaptain(galaxy: commander.galaxy).name.uppercased(),
      "plans_captain": OriginalContactIdentity.plansCaptain.name.uppercased(),
      "plans_agent": OriginalContactIdentity.plansAgent.name.uppercased(),
      "sighting": commander.galaxy == 0
        ? "ITS LAST REPORTED SIGHTING WAS AT REESDICE."
        : "INTELLIGENCE BELIEVES IT JUMPED INTO THIS GALAXY.",
      "constrictor": [2, 6, 10, 14].contains(commander.missionStage.rawValue)
        ? "complete" : "required",
    ]
    return replacements.reduce(text) {
      $0.replacingOccurrences(of: "{" + $1.key + "}", with: $1.value)
    }
  }
  mutating func showPackOffer(
    _ entry: LoadedMissionPack, transition: PackTransition, committed: Bool
  ) {
    packOffer = PackOffer(
      stateID: entry.pack.stateID, transitionID: transition.id,
      galaxy: commander.galaxy, system: commander.system, committed: committed)
    packOfferElapsed = 0
    packDialogScroll = 0
    blackjackOffer = (entry.pack.mission.binding == "blackjack" ? BlackjackAction.allActions : [])
      .first { $0.rawValue.lowercased() == transition.dialog }.map {
        BlackjackOffer(action: $0, galaxy: commander.galaxy, system: commander.system)
      }
    blackjackReturn = screen
    screen = .handoff
    notify("MISSION CONTACT")
  }
  mutating func showNavalDialog(transition: PackTransition) {
    guard
      let message = MissionMessage.allMessages.first(where: {
        $0.rawValue.lowercased() == transition.dialog
      })
    else { return }
    missionNotice = MissionNotice(
      message: message, commander: commander.name, galaxy: commander.galaxy)
    missionPage = 0
    missionElapsed = 0
    screen = .mission
    ecmControl.emit(.gameplay("Incoming naval message"))
  }
  mutating func confirmPackOffer() {
    guard packOfferElapsed >= (offeredDialog?.delaySeconds ?? 0) else { return }
    if packOffer?.committed == true {
      closeBlackjackHandoff()
      return
    }
    guard let offer = packOffer, docked, dockedAtMainStation,
      commander.galaxy == offer.galaxy, commander.system == offer.system,
      let entry = missionPacks.entries.first(where: { $0.pack.stateID == offer.stateID }),
      let transition = entry.pack.transitions.first(where: { $0.id == offer.transitionID })
    else {
      notify("CONTACT NO LONGER AVAILABLE")
      return
    }
    if !offer.committed && !commitMission(entry, transition: transition) { return }
    closeBlackjackHandoff()
    if transition.notification == nil { notify("MISSION CONTACT COMPLETE") }
  }
  public var offeredPack: LoadedMissionPack? {
    missionPacks.entries.first { $0.pack.stateID == packOffer?.stateID }
  }
  public var offeredDialog: PackDialog? {
    guard let offer = packOffer, let pack = offeredPack?.pack,
      let transition = pack.transitions.first(where: { $0.id == offer.transitionID }),
      let dialog = transition.dialog
    else { return nil }
    return pack.dialog(dialog)
  }
}
