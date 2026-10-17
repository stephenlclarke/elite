import Foundation
import Testing

@testable import EliteCore

private func acceptedGalleryRRS(_ storage: NativeStationTestStorage) async throws -> GameRuntime {
  var game = try NativeStationTestFixture.approach(kind: .headquarters)
  let station = try #require(
    game.bodies.first { $0.nativeStationIdentity?.definition == "rrs_headquarters" }?
      .nativeStationIdentity)
  let hour = try #require(
    (1...128).first {
      RRSCourierContent.draw(
        RRSCourierContent.seed(RRSCourierContent.boardKey(station, hour: Int64($0)))) < 0.5
    })
  game.commander.scriptState.calendarSeconds = Double(hour) * 3600
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  game = await runtime.advance(delta: 0.1)
  try #require(game.docked && game.nativeStationBoardContext != nil)
  await runtime.key("contracts-open")
  game = await runtime.snapshot()
  let row = try #require(game.contractBoard.selected?.rrs)
  try await runtime.confirmRRSCourier(game.rrsCourierQuote(for: row))
  return runtime
}

private func selectRRSForReading(_ game: inout Game) throws -> GalleryMission {
  let id = try #require(game.commander.contracts.rrs?.jobs.first?.id)
  game.openGallery()
  try #require(game.screen == .gallery)
  game.gallery.selection = try #require(
    game.missionCatalogue.firstIndex { $0.nativeRRSCourierID == id })
  game.gallery.detail = true
  game.pinGallerySelection()
  return try #require(game.selectedGalleryMission)
}

@Test func actualRRSCustodyIsReadableDockedAndInFlightWithoutScriptOrTrialAuthority() async throws {
  let storage = try NativeStationTestStorage()
  defer { storage.clean() }
  let runtime = try await acceptedGalleryRRS(storage)
  var game = await runtime.snapshot()
  let disk = try Data(contentsOf: storage.url)
  let commander = game.commander
  let row = try selectRRSForReading(&game)
  #expect(row.status == .active && row.savedInstance == nil && row.trialDigest == nil)
  #expect(row.nativeRRSCourierID == commander.contracts.rrs?.active?.id)
  let job = try #require(commander.contracts.rrs?.active)
  let origin = Universe.systemsIncludingPlugh(number: job.origin.station.system.galaxy)[
    job.origin.station.system.system
  ].name
  #expect(
    row.briefing.contains(origin + " / Galaxy " + String(job.origin.station.system.galaxy + 1)))
  #expect(
    row.briefing.contains("RRS Headquarters") && row.briefing.contains("Protected document packet"))
  #expect(
    !row.briefing.contains(job.packet.uuidString) && !row.briefing.contains(job.origin.station.key))
  #expect(row.milestones[0].state == "Complete" && row.milestones[2].state == "Upcoming")
  #expect(!game.canTrialSelectedMission && !game.canRetrySelectedGalleryEntry)
  #expect(game.campaignImmediateOwner == nil && game.selectedCampaignAssignments.isEmpty)
  #expect(
    game.galleryDetailLines(width: 480, font: GameTypography.scale).contains {
      $0.contains("protected")
    })
  game.galleryKey("pagedown")
  #expect(game.commander == commander)
  #expect(try Data(contentsOf: storage.url) == disk)
  await runtime.key("screen:8")
  await runtime.key("0")
  game = await runtime.snapshot()
  try #require(!game.docked)
  let flying = game.commander
  let flightBytes = try Data(contentsOf: storage.url)
  let inFlight = try selectRRSForReading(&game)
  #expect(inFlight.status == .active && inFlight.milestones[2].state == "Upcoming")
  #expect(inFlight.objective.contains("not proved"))
  #expect(game.commander == flying)
  #expect(try Data(contentsOf: storage.url) == flightBytes)
}

@Test func actualRRSAbandonmentAppearsAsFailedHistoryAndKeepsSelectionThroughCatalogueReplacement()
  async throws
{
  let storage = try NativeStationTestStorage()
  defer { storage.clean() }
  let runtime = try await acceptedGalleryRRS(storage)
  var game = await runtime.snapshot()
  let id = try #require(game.commander.contracts.rrs?.active?.id)
  try await runtime.confirmRRSCourier(game.rrsCourierQuote(for: .abandon(id)))
  game = await runtime.snapshot()
  let before = game.commander
  let bytes = try Data(contentsOf: storage.url)
  let row = try selectRRSForReading(&game)
  #expect(row.status == .failed && row.objective.contains("abandoned"))
  #expect(row.briefing.contains("0 CR / reputation -10"))
  #expect(row.milestones[2].state == "Locked")
  #expect(row.savedInstance == nil && row.trialDigest == nil)
  let pinnedIdentity = game.gallerySelectedEntryIdentity
  game.replaceMissionPacks(try .checked([]))
  #expect(game.gallerySelectedEntryIdentity == pinnedIdentity)
  #expect(game.selectedGalleryMission?.nativeRRSCourierID == id)
  game.galleryKey("return")
  game.galleryKey("escape")
  #expect(game.commander == before && game.commander.contracts.rrs?.failed == 1)
  #expect(try Data(contentsOf: storage.url) == bytes)
}

@Test func genuineRRSMainArrivalAndConfirmedDeliveryProjectSeparateMilestones() async throws {
  let storage = try NativeStationTestStorage()
  defer { storage.clean() }
  let runtime = try await acceptedGalleryRRS(storage)
  await runtime.key("screen:8")
  await runtime.key("0")
  var game = await runtime.snapshot()
  try #require(!game.docked)
  let active = try #require(game.commander.contracts.rrs?.active)
  let station = try #require(game.bodies.first { $0.id == 0 })
  let old = game.commander.flightSimulation.pose
  var pose = ShipPose()
  pose.position = old.systemPoint(station.entrancePosition + station.entranceNormal * 2)
  pose.orientation.y = old.orientation.apply(station.entranceUp)
  pose.orientation.z = old.orientation.apply(station.entranceNormal) * -1
  pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
  NativeStationTestFixture.reframe(&game, to: pose)
  game.speed = 3
  let arriving = GameRuntime(game: game, saveURL: storage.url)
  for _ in 0..<100 where !game.docked { game = await arriving.advance(delta: 0.1) }
  try #require(game.nativeMainStationArrivalContext(for: active.destination) != nil)
  let arrivalCommander = game.commander
  let arrived = try selectRRSForReading(&game)
  #expect(arrived.status == .active && arrived.milestones[2].state == "Complete")
  #expect(arrived.milestones[3].state == "Current" && game.commander == arrivalCommander)
  let arrivalPage = game.scriptGalleryPageIdentity
  let actual = await arriving.snapshot()
  try await arriving.confirmRRSCourier(actual.rrsCourierQuote(for: .debrief(active.id)))
  game = await arriving.snapshot()
  let delivered = game.commander
  let bytes = try Data(contentsOf: storage.url)
  let row = try selectRRSForReading(&game)
  #expect(game.scriptGalleryPageIdentity.entry != arrivalPage.entry)
  #expect(row.status == .complete && row.completed == 4)
  #expect(row.milestones.allSatisfy { $0.state == "Complete" })
  #expect(row.objective.contains("30.0 CR") && row.briefing.contains("custody ended"))
  #expect(game.commander == delivered && game.commander.contracts.rrs?.completed == 1)
  #expect(try Data(contentsOf: storage.url) == bytes)
}
