import Testing

@testable import L337Core

private func threatenedGame(sources: [Int] = [1], salvo: Int = 1) throws -> Game {
  var game = Game(executive: false)
  try game.commander.prepareEquipment(legacy: false)
  try game.commander.grantEquipment(
    TargetingTier.military.equipmentName, at: .targetingCore,
    provenance: .grant("retaliation fixture"))
  try game.commander.grantEquipment(
    "E.C.M. System", at: .utility(.ecm), provenance: .grant("retaliation fixture"))
  game.launch()
  game.speed = 0
  #expect(game.commander.equipmentInventory != nil && game.commander.targetingTier == .military)
  try #require(game.commander.fittedEquipment(at: .utility(.ecm)) != nil)
  game.bodies = sources.map {
    .init(id: $0, hull: .constrictor, position: .init(Double($0) * 20, 0, 1400))
  }
  for source in sources {
    for index in 0..<salvo {
      var missile = SpaceBody(id: source * 100 + index, hull: .missile, position: .init(0, 0, 1000))
      missile.enemyMissile = true
      missile.missileSourceID = source
      game.bodies.append(missile)
    }
  }
  game.ecmControl = ECMControl()
  return game
}
private func stowThreatMissiles(_ game: inout Game) throws {
  let initialInventory = try #require(game.commander.equipmentInventory)
  let rounds = initialInventory.items.filter {
    $0.node == EquipmentRuntimeCatalog.standardMissile && $0.location != nil
  }
  try #require(rounds.count == 3)
  for round in rounds {
    let inventory = try #require(game.commander.equipmentInventory)
    try game.commander.storeEquipment(round, expectedRevision: inventory.revision)
  }
  let emptyInventory = try #require(game.commander.equipmentInventory)
  try #require(
    emptyInventory.items.filter {
      $0.node == EquipmentRuntimeCatalog.standardMissile && $0.location != nil
    }.isEmpty && game.commander.missiles == 0 && game.commander.valid)
  try game.commander.validateEquipmentState()
}

@Test func militaryRetaliatesOncePerSourceAfterConfirmedECMWithOrderedVoiceEvents() throws {
  var game = try threatenedGame(sources: [1, 2], salvo: 3)
  game.key("v")
  game.key("]")
  game.ecm()
  #expect(game.commander.missiles == 3 && game.autoPilot.targetID == nil && game.spin.mode)
  #expect(game.weaponsTargetID == 2)
  for _ in 0..<90 { game.tick(delta: 0.02) }
  #expect(game.commander.missiles == 1)
  let events = game.ecmControl.events.map(\.announcement)
  #expect(events.contains(.missilesDestroyed(6)))
  #expect(
    events.filter {
      if case .missileLaunched = $0 { return true }
      return false
    }.count == 2)
  let confirmed = events.firstIndex(of: .missilesDestroyed(6))!
  let launched = events.firstIndex {
    if case .missileLaunched = $0 { return true }
    return false
  }!
  #expect(confirmed < launched && game.spin.mode && game.autoPilot.targetID == nil)
  for _ in 0..<60 { game.tick(delta: 0.02) }
  #expect(game.commander.missiles == 1)
}
@Test func militaryRetaliationDoesNotFireOnDetectionFailureOrUnknownSource() throws {
  var game = try threatenedGame()
  game.tick(delta: 0.02)
  #expect(game.commander.missiles == 3 && game.weaponsTargetID == 1)
  let inventory = try #require(game.commander.equipmentInventory)
  let ecm = try #require(game.commander.fittedEquipment(at: .utility(.ecm)))
  try game.commander.storeEquipment(ecm, expectedRevision: inventory.revision)
  try #require(game.commander.fittedEquipment(at: .utility(.ecm)) == nil && game.commander.valid)
  game.ecm()
  for _ in 0..<10 { game.tick(delta: 0.02) }
  #expect(game.commander.missiles == 3)
  game = try threatenedGame()
  game.bodies[1].missileSourceID = nil
  game.ecm()
  for _ in 0..<40 { game.tick(delta: 0.02) }
  #expect(game.commander.missiles == 3)
  #expect(
    !game.ecmControl.events.contains {
      if case .missileLaunched = $0.announcement { return true }
      return false
    })
  game = try threatenedGame()
  game.ecmFrames = 32
  for _ in 0..<40 { game.tick(delta: 0.02) }
  #expect(game.commander.missiles == 3)
}
@Test func militaryRetaliationReportsNoAmmoAndInvalidForwardLockAndClearsEquipmentLoss() throws {
  for scenario in 0...3 {
    var game = try threatenedGame()
    game.ecm()
    if scenario == 0 { try stowThreatMissiles(&game) }
    if scenario == 1 { game.bodies[0].position.z = -1400 }
    if scenario == 2 { game.bodies[0].energy = 0 }
    if scenario == 3 {
      let inventory = try #require(game.commander.equipmentInventory)
      let core = try #require(game.commander.fittedEquipment(at: .targetingCore))
      try game.commander.storeEquipment(core, expectedRevision: inventory.revision)
      #expect(game.commander.targetingTier == nil)
    }
    for _ in 0..<40 { game.tick(delta: 0.02) }
    let events = game.ecmControl.events.map(\.announcement)
    #expect(
      !events.contains {
        if case .missileLaunched = $0 { return true }
        return false
      })
    if scenario < 3 {
      #expect(
        events.contains {
          if case .cannotRetaliate = $0 { return true }
          return false
        })
    }
  }
}
@Test func unlimitedRetaliationAndNewAttacksRespectAmmoAndManualDisarm() throws {
  var game = try threatenedGame()
  try stowThreatMissiles(&game)
  game.commander.unlimitedMissiles = true
  game.ecm()
  for _ in 0..<60 { game.tick(delta: 0.02) }
  #expect(game.commander.missiles == 0)
  #expect(
    game.ecmControl.events.contains {
      if case .missileLaunched = $0.announcement { return true }
      return false
    })
  for _ in 0..<100 where game.ecmFrames > 0 || game.missileCooldown > 0 { game.tick(delta: 0.02) }
  var missile = SpaceBody(id: 222, hull: .missile, position: .init(0, 0, 1000))
  missile.enemyMissile = true
  missile.missileSourceID = 1
  game.bodies.append(missile)
  game.ecm()
  for _ in 0..<60 { game.tick(delta: 0.02) }
  #expect(
    game.ecmControl.events.filter {
      if case .missileLaunched = $0.announcement { return true }
      return false
    }.count == 2)
  game = try threatenedGame()
  game.ecm()
  game.key("u")
  for _ in 0..<40 { game.tick(delta: 0.02) }
  #expect(game.commander.missiles == 3 && game.weaponsTargetID == nil)
}
@Test func notificationsRemainOnscreenAndEmitOneSpeechEventPerActualNotification() {
  var game = Game(executive: false)
  game.notify("Right on, Commander")
  #expect(game.message == "Right on, Commander" && game.messageTime == 4)
  #expect(game.ecmControl.events.last?.announcement.text == "Right on, Commander")
  let first = game.ecmControl.events.last!.id
  for _ in 0..<10 { game.tick(delta: 0.02) }
  #expect(game.ecmControl.events.last?.id == first)
  game.notify("Right on, Commander")
  #expect(game.ecmControl.events.last?.id == first + 1)
  for text in ["DOCKED", "EQUIPMENT FITTED", "HYPERSPACE", "ENERGY LOW,SIR"] { game.notify(text) }
  #expect(
    game.ecmControl.events.suffix(4).map(\.announcement.text) == [
      "DOCKED", "EQUIPMENT FITTED", "HYPERSPACE", "ENERGY LOW,SIR",
    ])
  var queue = AnnouncementQueue()
  queue.append([.gameplay("DOCKED"), .gameplay("DOCKED"), .gameplay("ENERGY LOW,SIR")])
  #expect(queue.pending.count == 2 && queue.next() == "ENERGY LOW,SIR" && queue.next() == "DOCKED")
}

@Test func sharedSpeechFeedHonoursPreferencesBusyQueuesReloadsAndActualRankCongratulations() {
  var game = Game(executive: false)
  game.screen = .status
  var feed = SpeechFeed()
  game.notify("DOCKED")
  #expect(feed.update(game, busy: false) == nil)
  game.commander.speech = true
  #expect(feed.update(game, busy: false) == nil)
  game.notify("FUEL TOO LOW")
  #expect(feed.update(game, busy: true) == nil)
  #expect(feed.update(game, busy: false) == "FUEL TOO LOW")
  #expect(feed.update(game, busy: false) == nil)
  game.notify("FUEL TOO LOW")
  #expect(feed.update(game, busy: false) == "FUEL TOO LOW")
  game.ecmControl = ECMControl()
  game.notify("DOCKED")
  #expect(feed.update(game, busy: false) == "DOCKED")
  game.launch()
  game.speed = 0
  game.commander.kills = 7
  var enemy = SpaceBody(id: 1, hull: .sidewinder, position: .init(0, 0, 1000), hostile: true)
  enemy.energy = 0
  enemy.destroyedByPlayer = true
  game.bodies = [enemy]
  game.tick(delta: 0.01)
  #expect(game.message == "RIGHT ON, COMMANDER")
  #expect(game.ecmControl.events.contains { $0.announcement == .gameplay("RIGHT ON, COMMANDER") })
}
