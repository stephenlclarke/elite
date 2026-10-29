import Foundation
import Testing

@testable import EliteCore

struct NativePeopleGalleryTests {
  @Test func isolatedNativeTrialUsesRealProducerAndRestartReturnProtectLiveFiles() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var live = Game(executive: false)
    live.screen = .status
    let runtime = GameRuntime(game: live, saveURL: storage.url)
    try await runtime.save(to: storage.url)
    await runtime.key("gallery-open")
    let before = await runtime.snapshot().commander
    let files = try ScriptFinanceTestFixture.files(storage.directory)
    try await runtime.startScriptGalleryTrial(packDigest: NativePeopleGallery.digest, seed: 0)
    let namespace = try #require(await runtime.gallerySaveDirectory())
    defer { try? FileManager.default.removeItem(at: namespace) }
    let initial = await runtime.snapshot()
    #expect(initial.isMissionTrial && initial.trialDigest == NativePeopleGallery.digest)
    #expect(initial.commander.valid && initial.commander.shipID == "SH023")
    #expect(initial.commander.fuel == initial.commander.fuelCapacity)
    #expect(initial.commander.nativePerformance.workTools?.contains(.salvageCutter) == true)
    #expect(initial.commander.fittedEquipment(at: .utility(.salvageCutter)) != nil)
    #expect(initial.energy == initial.commander.performance.energy)
    #expect(initial.frontShield == initial.commander.shieldCapacity)
    #expect(initial.rearShield == initial.commander.rearShieldCapacity)
    #expect(initial.commander.nativePeople == nil && initial.commander.savedEMPState == nil)
    let source = try #require(initial.bodies.first { $0.id == initial.weaponsTargetID })
    #expect(source.physical?.spawnIdentity?.producer == .ambient)
    #expect(source.physical?.npc != nil && source.physical?.empCrewPod == nil)
    #expect(Universe.systemsIncludingPlugh()[initial.commander.system].government == 0)
    #expect(initial.commander.system != Plugh.systemID)
    #expect(source.physical?.npc?.legal.value == 64)
    #expect(
      initial.commander.fittedComponent(at: .energy)?.grade
        == EquipmentModuleTemplates.energy.grades[3].identity)
    let catalogue = try #require(source.physical?.catalogueShipID)
    let stock = try #require(ShipCatalogue.ship(catalogue)?.game)
    #expect(source.physical?.npc?.resources == NPCResources.stock(stock))
    #expect(source.energy == stock.energy)
    #expect(
      source.physical?.npc?.intention
        == .navigate(
          position: initial.commander.flightSimulation.pose.systemPoint(source.position),
          speedUnitsPerSecond: 0))
    #expect(initial.commander.equipmentOwnerID != before.equipmentOwnerID)
    try await runtime.nativePeopleTrialAimAndDisable()
    let collected = await NativePeopleTestFixture.capture(runtime)
    #expect(collected.commander.nativeCaptiveCount == 5)
    #expect(
      collected.commander.nativePeople?.admissions.allSatisfy { $0.origin == .capturedCrew } == true
    )
    #expect(collected.commander.valid)
    await #expect(throws: (any Error).self) { try await runtime.save(to: storage.url) }
    #expect(try ScriptFinanceTestFixture.files(storage.directory) == files)
    try await runtime.restartScriptGalleryTrial()
    #expect(await runtime.snapshot().commander.nativePeople == nil)
    #expect(await runtime.snapshot().commander.savedEMPState == nil)
    try await runtime.returnFromScriptGalleryTrial()
    #expect(await runtime.snapshot().commander == before)
    #expect(try ScriptFinanceTestFixture.files(storage.directory) == files)
  }
}

extension GameRuntime {
  func nativePeopleTrialAimAndDisable() throws {
    let body = try #require(game.bodies.first { $0.id == game.weaponsTargetID })
    let actor = try #require(body.physical?.identity)
    #expect(try EMPPulseProfile.resolve(for: game.commander).power == 80)
    try prepareNativePeopleTraffic(&game, source: actor)
    let remaining = try disableNativePeopleTrialActor(actor, game: &game)
    game.selectFlightTool(.salvageCutter)
    while game.workTargetFilter != .salvage { game.key("f") }
    for _ in 0...game.bodies.count {
      game.key("tab")
      if game.workGuidance?.parent == actor { break }
    }
    try #require(game.workGuidance?.parent == actor)
    for _ in 0..<remaining {
      if game.workGuidance?.holding == true { return }
      try deferNativePeopleTraffic(&game)
      game.tick(delta: 0.1)
      let actual = try #require(game.bodies.first { $0.physical?.identity == actor })
      let context = try #require(game.gameplayContext())
      try #require(game.nativeCrewCaptureAvailable(actual, context: context))
      try #require(game.screen != .gameOver && !game.docked)
    }
    try #require(
      game.workGuidance?.holding == true,
      "Native cutter approach did not reach the real work surface inside the derived flight budget")
  }
}

/// Only this people-producer fixture excludes unrelated traffic; native police and the source stay live.
private func prepareNativePeopleTraffic(_ game: inout Game, source: ActorIdentity) throws {
  try #require(
    game.isMissionTrial && game.trialDigest == NativePeopleGallery.digest
      && game.currentSystem.government == 0
      && game.commander.flightSimulation.physicalTime == 0)
  let context = try #require(game.gameplayContext())
  try #require(Set(context.actors.map(\.identity)).count == context.actors.count)
  try #require(
    !context.actors.contains { $0.identity == context.player.identity }
      && context.actors.filter({ $0.identity == source }).count == 1
      && game.bodies.filter({ $0.physical?.identity == source }).count == 1)
  for index in game.bodies.indices {
    let body = game.bodies[index]
    guard body.hull.isTargetShip else { continue }
    let physical = try #require(body.physical)
    var npc = try #require(physical.npc)
    if physical.identity == source || npc.role == .police { continue }
    try #require(
      [.trader, .miner, .pirate].contains(npc.role)
        && [.civilian, .pirate].contains(physical.population)
        && body.missionInstanceID == nil && body.scriptNPC == nil && body.scriptShot == nil
        && !body.navalTarget && body.blackjackRole == nil && body.blackjackIdentity == nil
        && physical.empSource == nil && physical.empCrewPod == nil && physical.salvage == nil
        && !game.isEMPDisabled(body)
        && !context.protection.protectedActors.contains(physical.identity))
    let actor = try #require(context.actors.first { $0.identity == physical.identity })
    try #require(
      physical.identity.system == context.system && physical.identity.visit == context.visit
        && physical.identity != context.player.identity
        && game.bodies.filter({ $0.physical?.identity == physical.identity }).count == 1
        && actor.npc == physical.npc && actor.hull == body.hull && actor.energy == body.energy
        && body.energy.isFinite && body.energy > 0 && body.position.finite
        && npc.firstAggressor == nil && (npc.resources?.valid ?? true))
    npc.role = .trader
    npc.intention = .dock(context.anchors.station.identity)
    game.bodies[index].hostile = false
    game.bodies[index].physical?.population = .civilian
    game.bodies[index].physical?.npc = npc
  }
  try deferNativePeopleTraffic(&game)
}

private func deferNativePeopleTraffic(_ game: inout Game) throws {
  let context = try #require(game.gameplayContext())
  let director = try #require(game.commander.encounterDirector)
  try #require(
    context.system == game.systemIdentity && context.visit == game.commander.flightSimulation.visit
      && context.player.identity == game.commander.flightSimulation.player
      && context.revision == game.gameplayRevision
      && context.physicalTime == game.commander.flightSimulation.physicalTime
      && director.system == context.system && director.visit == context.visit
      && director.decisionCount == 0 && director.admittedCount == 0
      && director.pendingRequests.isEmpty)
  // The maintained NPC resource fixture defers only unconsumed proposals from actual context.
  game.commander.encounterDirector = EncounterDirector(context: context)
}

private struct NativePeopleEMPBudget {
  let egressFrames: Int
  let brakingFrames: Int
  let totalFrames: Int

  init(source: ActorIdentity, game: inout Game) throws {
    let body = try #require(game.bodies.first { $0.physical?.identity == source })
    let resources = try #require(body.physical?.npc?.resources)
    let profile = try EMPPulseProfile.resolve(for: game.commander)
    let craft = game.commander.performance
    let context = try #require(game.gameplayContext())
    let delta = 0.1
    // Round each production phase up separately; four ticks cover start/release/clear/rearm alignment.
    let cycle =
      ceil(profile.warmup / delta) * delta + ceil(profile.cooldown / delta) * delta + 4 * delta
    let capacity = resources.frontCapacity + resources.rearCapacity + resources.energyCapacity
    let regeneration = 2 * resources.shieldRecharge + resources.electricalRecharge
    let depletion = profile.power - regeneration * cycle
    let turnRate = min(craft.pitch, craft.yaw)
    try #require(
      resources.valid && profile.warmup == 10
        && [cycle, capacity, depletion, turnRate, craft.acceleration, game.speed].allSatisfy {
          $0.isFinite && $0 > 0
        })
    let speed = game.speed * 18
    let clearance = 1200 + speed * delta
    var exitDistance = 0.0
    let stations =
      [context.anchors.station.position]
      + context.actors.filter { $0.hull == .station && $0.energy > 0 }.map(\.position)
    for station in stations {
      let offset = station - context.player.position
      try #require(offset.finite)
      guard offset.length <= clearance else { continue }
      let along = offset.dot(context.player.orientation.z)
      let perpendicularSquared = max(0, offset.dot(offset) - along * along)
      exitDistance = max(
        exitDistance, along + sqrt(max(0, clearance * clearance - perpendicularSquared)))
    }
    let egress = ceil(exitDistance / speed / delta)
    let braking = ceil(game.speed / craft.acceleration / delta) + 1
    let aiming = ceil(2 * Double.pi / turnRate / delta)
    let releases = ceil(capacity / depletion)
    let frames = egress + braking + aiming + ceil(releases * cycle / delta)
    try #require(
      frames.isFinite && frames > 0 && frames < Double(Int.max)
        && egress.isFinite && braking.isFinite)
    egressFrames = Int(egress)
    brakingFrames = Int(braking)
    totalFrames = Int(frames)
  }
}

/// The stock demonstration needs multiple genuine charges; other EMP fixtures retain exactly 800 frames.
private func disableNativePeopleTrialActor(_ actor: ActorIdentity, game: inout Game) throws -> Int {
  let budget = try NativePeopleEMPBudget(source: actor, game: &game)
  game.selectFlightTool(.empPirateBlaster)
  for frame in 0..<budget.totalFrames {
    let body = try #require(game.bodies.first { $0.physical?.identity == actor })
    if game.isEMPDisabled(body) { return budget.totalFrames - frame }
    var controls = Controls()
    if frame < budget.egressFrames {
      // Keep the real launch heading and speed until beyond the current station spheres.
    } else if frame < budget.egressFrames + budget.brakingFrames {
      controls.throttle = -1
    } else {
      try #require(game.speed == 0)
      let context = try #require(game.gameplayContext())
      let lawful = game.commander.crimeLedger.permitsAutonomousDefence(
        owner: context.player.identity, victim: actor, context: context)
      try #require(
        lawful, "Native people trial EMP requires current lawful admission outside all zones")
      controls.yaw = max(
        -1, min(1, atan2(body.position.x, body.position.z) / (game.commander.performance.yaw * 0.1))
      )
      controls.pitch = max(
        -1,
        min(
          1,
          atan2(body.position.y, hypot(body.position.x, body.position.z))
            / (game.commander.performance.pitch * 0.1)))
      let range = try EMPPulseProfile.resolve(for: game.commander).range
      let contact = try game.nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1), range: range,
        radius: 0, includePlayer: false)
      let ready = game.commander.savedEMPCharge == nil && game.fireCooldown <= 0
      controls.fire =
        game.commander.savedEMPCharge?.phase == .charging
        || (ready && contact?.hit.target == .body(body.id))
    }
    try deferNativePeopleTraffic(&game)
    game.tick(delta: 0.1, controls: controls)
    try #require(game.screen != .gameOver && !game.docked)
  }
  let body = try #require(game.bodies.first { $0.physical?.identity == actor })
  try #require(
    game.isEMPDisabled(body), "Real stock-source EMP depletion exceeded its derived physical budget"
  )
  return 0
}
