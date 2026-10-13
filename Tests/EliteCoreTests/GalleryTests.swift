import Foundation
import Testing

@testable import EliteCore

@Test func galleryMapsEverySavedTPStageToChronologicalMilestones() {
  let expected: [(NavalMissionStage, Int, Int)] = [
    (.notStarted, 0, 0), (.huntingConstrictor, 1, 0), (.constrictorDestroyed, 2, 0),
    (.constrictorComplete, 3, 0), (.reportToCeerdi, 3, 1), (.carryingPlans, 3, 2),
    (.plansDelivered, 3, 3),
  ]
  for (stage, hunt, plans) in expected {
    var game = Game(executive: false)
    game.commander.missionStage = stage
    let catalogue = game.missionCatalogue
    #expect(catalogue.count == 2)
    #expect(catalogue[0].completed == hunt && catalogue[1].completed == plans)
    for mission in catalogue {
      #expect(mission.milestones.filter { $0.state == "Complete" }.count == mission.completed)
      if mission.status == .complete { #expect(mission.completed == 3) }
    }
  }
  var game = Game(executive: false)
  #expect(game.missionCatalogue.allSatisfy { $0.status == .locked })
  game.commander.kills = 256
  #expect(game.missionCatalogue[0].status == .available)
  game.commander.missionStage = .constrictorComplete
  game.commander.kills = 1280
  game.commander.galaxy = 2
  #expect(game.missionCatalogue[1].status == .available)
}
@Test func galleryFreezesFlightAndPreservesSettingsPausedStateAndMissionOffers() async {
  var game = Game(executive: false)
  game.launch()
  game.screen = .rear
  game.commander.xyzzyActive = true
  game.commander.autoTarget = true
  game.key("v")
  game.key("]")
  game.key("r")
  game.tick(delta: 0.1)
  let spin = game.spin
  let targetID = game.autoPilot.targetID
  let time = game.time
  let bodies = game.bodies
  let speed = game.speed
  let commander = game.commander
  let runtime = GameRuntime(game: game)
  var controls = Controls()
  controls.fire = true
  controls.throttle = 1
  await runtime.setControls(controls)
  await runtime.key("l")
  await runtime.key("spin-cancel")
  await runtime.key("pause")
  for _ in 0..<10 { _ = await runtime.advance(delta: 0.1) }
  let gallery = await runtime.snapshot()
  #expect(gallery.screen == .gallery && gallery.time == time && gallery.bodies == bodies)
  #expect(gallery.speed == speed && gallery.spin == spin && gallery.autoPilot.targetID == targetID)
  #expect(gallery.commander == commander)
  await runtime.key("k")
  await runtime.key("spin-cancel")
  await runtime.key("escape")
  await runtime.key("l")
  let returned = await runtime.advance(delta: 0.01)
  #expect(
    returned.screen == .rear && !returned.paused && returned.laserFlash == 0
      && returned.speed == speed)
  var docked = Game(executive: false)
  docked.screen = .inventory
  docked.paused = true
  docked.commander.kills = 256
  docked.viewportHeight = 320
  docked.key("l")
  docked.key("down")
  docked.key("return")
  docked.key("pagedown")
  docked.key("pageup")
  docked.key("gallery-scroll:2")
  #expect(docked.gallery.scroll > 0)
  docked.key("l")
  #expect(
    docked.screen == .inventory && docked.paused && docked.commander.missionStage == .notStarted)
  docked.dock()
  #expect(docked.screen == .mission)
  docked.key("l")
  #expect(docked.screen == .mission)
}
@Test func galleryResponsiveMasterDetailAndPointerSelectionKeepTextInsideBounds() {
  var game = Game(executive: false)
  game.screen = .status
  game.key("l")
  for width in [512.0, 768, 1024, 1512] {
    game.viewportWidth = width
    game.viewportHeight = 600
    for stage in NavalMissionStage.allCases {
      game.commander.missionStage = stage
      for selection in 0...1 {
        game.gallery.selection = selection
        for detail in [false, true] {
          game.gallery.detail = detail
          let frame = Display.gallery(game, width: width, height: 600)
          for label in frame.labels {
            #expect(label.bounds.x >= 0 && label.bounds.maxX <= width)
            #expect(label.bounds.y >= 0 && label.bounds.maxY <= 600)
          }
        }
      }
    }
  }
  game.viewportWidth = 512
  game.gallery.detail = false
  game.galleryClick(x: 100, y: 230)
  #expect(game.gallery.selection == 1 && game.gallery.detail)
  game.key("down")
  #expect(game.gallery.scroll == 1)
  game.key("up")
  #expect(game.gallery.scroll == 0)
  game.key("escape")
  #expect(game.screen == .gallery && !game.gallery.detail)
  game.galleryClick(x: 450, y: 12)
  #expect(game.screen == .status)
}
@Test func legacyCommanderHasNoXYZzyFlagsAndGalleryDoesNotRequireNewSaveFields() throws {
  var data = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(Commander())) as? [String: Any])
  for key in ["xyzzyEnabled", "automaticECM", "automaticTargeting", "navalMission"] {
    data.removeValue(forKey: key)
  }
  let commander = try JSONDecoder().decode(
    Commander.self, from: JSONSerialization.data(withJSONObject: data))
  #expect(
    !commander.xyzzyActive && !commander.autoECM && !commander.autoTarget
      && commander.missionStage == .notStarted)
  var game = Game()
  let loaded = game.load(commander)
  #expect(loaded)
  game.key("l")
  #expect(game.missionCatalogue[0].completed == 0)
}
@Test func speechQueueCoalescesWavesWithoutInventingDestructions() {
  var queue = AnnouncementQueue()
  for _ in 0..<10 { queue.append([.missileDetected, .ecmActivated, .missilesDestroyed(2)]) }
  #expect(queue.pending.count <= 24)
  var destroyed = 0
  for value in queue.pending {
    if case .missilesDestroyed(let count) = value { destroyed += count }
  }
  #expect(destroyed == 20)
  #expect(queue.next() == "Missile Detected")
  queue.clear()
  #expect(queue.next() == nil)
}
