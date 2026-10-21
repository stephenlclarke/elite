import Foundation
import Testing

@testable import EliteCore

private func originalProtectedActors(_ game: Game) -> Set<ActorIdentity> {
  Set(
    game.bodies.filter {
      $0.physical?.empCrewPod != nil || $0.navalTarget || $0.blackjackRole != nil
        || $0.physical?.npc?.role == .mission || $0.missionInstanceID != nil
    }.compactMap { $0.physical?.identity })
}

struct NativePodProtectionTests {
  @Test(arguments: [false, true])
  func actualProtectedPodAllowsNativeRescueButCannotBecomeOrdinaryCargo(legacy: Bool) throws {
    var game = try NativePeopleTestFixture.podApproach(legacy: legacy)
    let index = try #require(game.bodies.firstIndex { $0.physical?.empCrewPod != nil })
    // Move the original emitted pod into the real scoop aperture, retaining its producer and binding.
    game.bodies[index].position = .init(0, -45, 55)
    let persisted = game.persistEMPState()
    try #require(persisted)
    let body = game.bodies[index]
    let person = try #require(body.physical?.empCrewPod)
    let actor = try #require(body.physical?.identity)
    let context = try #require(game.gameplayContext())
    #expect(context.protection.protectedActors == originalProtectedActors(game))
    #expect(context.protection.protectedActors.contains(actor))
    let facts = try #require(game.nativePodFacts(body, context: context))
    #expect(facts.person == person && facts.fits)
    let candidate = try #require(
      game.workTargetCandidate(for: body, context: context, frontVisible: true))
    let decision = WorkTargetSelection.evaluate(
      candidate, system: context.system, visit: context.visit,
      capabilities: game.workTargetCapabilities)
    #expect(decision.mode == .autoScoop(.salvage))
    #expect(game.targetColourCue(for: body, context: context) == .recoverable)
    let before = game.commander
    let bodies = game.bodies
    game.scoopCargo()
    #expect(game.commander == before && game.bodies == bodies)
    #expect(game.commander.nativePeople == nil && game.commander.rescuedPodTonnes == 0)
  }

  @Test(arguments: [
    "naval", "blackjack-role", "mission-instance", "mission-npc", "mission-actor",
    "blackjack-identity", "mission-payload", "combined", "foreign-ordinal", "foreign-claimant",
    "stale-binding", "duplicate-actor",
  ])
  func genuinePodCannotBorrowRescuePermissionAcrossIndependentClaimsOrBrokenCustody(reason: String)
    throws
  {
    var game = try NativePeopleTestFixture.podApproach()
    let index = try #require(game.bodies.firstIndex { $0.physical?.empCrewPod != nil })
    let original = game.bodies[index]
    let person = try #require(original.physical?.empCrewPod)
    let contextBefore = try #require(game.gameplayContext())
    let genuine = game.nativePodFacts(original, context: contextBefore)
    try #require(genuine != nil)
    let sourceIndex = try #require(
      game.bodies.firstIndex { $0.physical?.empSource == person.source })
    switch reason {
    case "naval":
      game.bodies[index].navalTarget = true
      game.bodies[sourceIndex].navalTarget = true
    case "blackjack-role":
      game.bodies[index].blackjackRole = .witness
      game.bodies[sourceIndex].blackjackRole = .witness
    case "mission-instance":
      game.bodies[index].missionInstanceID = UUID()
      game.bodies[sourceIndex].missionInstanceID = UUID()
    case "mission-npc":
      game.bodies[index].physical?.npc = .init(
        role: .mission, origin: contextBefore.system, destination: contextBefore.system)
      game.bodies[sourceIndex].physical?.npc = .init(
        role: .mission, origin: contextBefore.system, destination: contextBefore.system)
    case "mission-actor": game.bodies[index].missionActorID = UUID()
    case "blackjack-identity": game.bodies[index].blackjackIdentity = UUID()
    case "mission-payload":
      game.bodies[index].physical?.payload = .mission(instance: UUID(), payload: "foreign")
    case "combined":
      game.bodies[index].navalTarget = true
      game.bodies[index].blackjackRole = .witness
      game.bodies[index].missionInstanceID = UUID()
      game.bodies[sourceIndex].navalTarget = true
      game.bodies[sourceIndex].blackjackRole = .witness
      game.bodies[sourceIndex].missionInstanceID = UUID()
    case "foreign-ordinal":
      game.bodies[index].physical?.empCrewPod = .init(source: person.source, ordinal: 255)
    case "foreign-claimant":
      let old = try #require(original.physical?.salvage)
      game.bodies[index].physical?.salvage = .init(
        category: old.category, ownership: old.ownership, claimant: contextBefore.player.identity,
        wreck: old.wreck, section: old.section, lot: old.lot,
        bounds: old.bounds, workSurfaces: old.workSurfaces)
    case "stale-binding":
      let record = try #require(game.commander.savedEMPState?.records[person.source])
      let podIndex = try #require(record.podIndex(for: person.ordinal))
      let sourceActor = try #require(record.hull.binding)
      game.commander.savedEMPState?.records[person.source]?.pods[podIndex].binding = sourceActor
    case "duplicate-actor":
      var duplicate = original
      duplicate.id = game.nextBodyID
      game.nextBodyID += 1
      game.bodies.append(duplicate)
    default: Issue.record("Unknown rescue protection fixture")
    }
    let body = game.bodies[index]
    let context = try #require(game.gameplayContext())
    #expect(context.protection.protectedActors == originalProtectedActors(game))
    #expect(game.nativePodFacts(body, context: context) == nil)
    #expect(game.targetColourCue(for: body, context: context) == .ordinary)
    let candidate = try #require(
      game.workTargetCandidate(for: body, context: context, frontVisible: true))
    let decision = WorkTargetSelection.evaluate(
      candidate, system: context.system, visit: context.visit,
      capabilities: game.workTargetCapabilities)
    #expect(decision.mode == nil)
    #expect(game.commander.nativePeople == nil)
  }

  @Test func actualVerifiedLaserContactCannotDamageAnOtherwiseRescuableProtectedPod() throws {
    var game = try NativePeopleTestFixture.podApproach()
    let pod = try #require(game.bodies.first { $0.physical?.empCrewPod != nil })
    let person = try #require(pod.physical?.empCrewPod)
    let player = try #require(game.commander.flightSimulation.player)
    let emitted = game.makeAttackOrigin(owner: player)
    let origin = try #require(emitted)
    let traced = try game.nearestMissionCollision(
      from: .init(0, 0, 0), direction: pod.position.unit, range: 6000, radius: 0,
      excludingBodyIDs: [], includePlayer: false)
    let contact = try #require(traced)
    try #require(contact.hit.target == .body(pod.id))
    let context = try #require(game.gameplayContext())
    #expect(context.protection.protectedActors == originalProtectedActors(game))
    let facts = game.nativePodFacts(pod, context: context)
    try #require(facts?.person == person)
    let incident = game.applyCombatHit(
      contact.hit, origin: origin, kind: .laser, damage: pod.energy + 1000,
      laser: .pulse, mount: .front,
      emissionPosition: game.commander.flightSimulation.pose.position)
    try #require(incident != nil)
    let retained = try #require(game.bodies.first { $0.physical?.empCrewPod == person })
    #expect(retained == pod)
    #expect(game.commander.nativePeople == nil && game.commander.rescuedPodTonnes == 0)
  }
}
