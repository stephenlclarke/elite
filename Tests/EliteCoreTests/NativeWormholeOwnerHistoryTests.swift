import Testing

@testable import EliteCore

struct NativeWormholeOwnerHistoryTests {
  @Test(arguments: [false, true])
  func missingOrEmptyLedgerStillRejectsOrphanTransitActors(hasLedger: Bool) throws {
    let fixture = try NativeWormholeTransitFixture()
    defer { fixture.storage.clean() }
    let (game, instance, context) = try fixture.game()
    var state = game.commander.scriptState
    state.wormholeTransit =
      hasLedger ? NativeWormholeTransitState(owner: game.commander.equipmentOwnerID) : nil
    let original = try #require(
      state.instances[instance]?.ownedEncounters["opponents"]?.actors["lead"])
    try #require(original.presence == .present && original.transitLocation == nil)
    try #require(state.nativeWormholeStateValid)
    // Current-format corruption boundaries only: never installed in Game or published.
    for presence in [ScriptActorPresence.inTransit, .arrivalPending] {
      var actor = original
      actor.presence = presence
      state.instances[instance]?.ownedEncounters["opponents"]?.actors["lead"] = actor
      #expect(!state.nativeWormholeStateValid)
    }
    var relocated = original
    relocated.transitLocation = context.route.destination.location
    state.instances[instance]?.ownedEncounters["opponents"]?.actors["lead"] = relocated
    #expect(!state.nativeWormholeStateValid)
    state.instances[instance]?.ownedEncounters["opponents"]?.actors["lead"] = original
    #expect(state.nativeWormholeStateValid)
  }
}
