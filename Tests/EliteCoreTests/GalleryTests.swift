import Foundation
import Testing

@testable import EliteCore

@Test func galleryMapsEverySavedTPStageToChronologicalMilestones() throws {
  let packIDs = [
    "xyzzy.constrictor/constrictor", "xyzzy.plans/plans", "xyzzy.blackjack/blackjack",
  ]
  let names = [
    "Constrictor Hunt", "Thargoid Plans", "Blackjack's Bullion",
    "Native crew capture and escape-pod rescue",
  ]
  let milestones = [
    ["Receive naval assignment", "Remove the Constrictor", "Dock for debriefing and reward"],
    [
      "Receive orders to report to Nerith", "Dock at Nerith and collect plans",
      "Dock at Veyara for delivery and reward",
    ],
    [
      "Receive Blackjack's contact", "Destroy Bolts; earn 20 kg gold",
      "Report at a G2 main station", "Collect the marked firearm",
      "Confirm Darvan dockside handoff", "Destroy the unique witness",
      "Confirm Dradar report and final reward",
    ],
    [
      "Actually disable an admitted ordinary crewed craft",
      "Track and collect a real occupied capsule",
      "Capture original crew still aboard before recovery",
      "Confirm care or an original-person sale",
    ],
  ]
  let expected: [(NavalMissionStage, Int, Int)] = [
    (.notStarted, 0, 0), (.huntingConstrictor, 1, 0), (.constrictorDestroyed, 2, 0),
    (.constrictorComplete, 3, 0), (.reportToCeerdi, 3, 1), (.carryingPlans, 3, 2),
    (.plansDelivered, 3, 3),
  ]
  for (stage, hunt, plans) in expected {
    var game = Game(executive: false)
    game.commander.missionStage = stage
    let catalogue = game.missionCatalogue
    try #require(game.missionPacks.entries.map { $0.pack.stateID } == packIDs)
    try #require(catalogue.count == names.count && catalogue.map(\.name) == names)
    #expect(catalogue[0].completed == hunt && catalogue[1].completed == plans)
    let statuses: [GalleryStatus] = [
      hunt == 3 ? .complete : hunt > 0 ? .active : .locked,
      plans == 3 ? .complete : plans > 0 ? .active : .locked, .locked, .available,
    ]
    #expect(catalogue.map(\.status) == statuses)
    #expect(catalogue[2].completed == 0 && catalogue[3].completed == 0)
    for (index, mission) in catalogue.enumerated() {
      #expect(mission.milestones.map(\.title) == milestones[index])
      #expect(mission.milestones.filter { $0.state == "Complete" }.count == mission.completed)
      if mission.status == .complete {
        #expect(mission.completed == mission.milestones.count)
        if index < 2 { #expect(mission.completed == 3) }
      }
      if index < packIDs.count {
        #expect(mission.trialDigest == nil && mission.savedInstance == nil)
      } else {
        #expect(mission.trialDigest == NativePeopleGallery.digest && mission.savedInstance == nil)
        #expect(mission.milestones.map(\.state) == Array(repeating: "Trial", count: 4))
      }
    }
  }
  var game = Game(executive: false)
  try #require(game.missionPacks.entries.map { $0.pack.stateID } == packIDs)
  let initial = game.missionCatalogue
  #expect(initial.map(\.name) == names)
  #expect(initial.map(\.status) == [.locked, .locked, .locked, .available])
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
  game.key("tab")
  game.tick(delta: 0.1)
  let runtime = GameRuntime(game: game)
  let ready = await runtime.snapshot()
  let spin = ready.spin
  let targetID = ready.autoPilot.targetID
  let time = ready.time
  let bodies = ready.bodies
  let speed = ready.speed
  let commander = ready.commander
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
