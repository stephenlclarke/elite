import Foundation

enum NativePeopleGallery {
  static let digest = ScriptPackLibrary.hash(Data("PROJECT-NATIVE-PEOPLE-TRIAL-v1".utf8))
}

extension Game {
  var nativePeopleGalleryEntry: GalleryMission {
    .init(
      name: "Native crew capture and escape-pod rescue", status: .available,
      objective:
        "Use real EMP disablement, tracked capsule collection and orbital person transfers.",
      briefing:
        "Original isolated demonstration. Each original crew member has a saved random ejection time. Before the 30-second recovery deadline, actual cutter contact captures crew still aboard, limited by real free hold. Escaped pods remain people: Tab and the Salvage filter select single-unit auto-approach with the fitted module and Fuel Scoops. Return to an original main orbital station for explicit care or sale. No historical campaign is enabled.",
      destination: "A proved original main orbital station",
      reward: "No demonstration reward; actual sale prices remain native market transactions.",
      prerequisites: [
        "Trial fits actual owned tools once; live commander and files are unchanged."
      ],
      completed: 0,
      milestones: [
        .init(title: "Actually disable an admitted ordinary crewed craft", state: "Trial"),
        .init(title: "Track and collect a real occupied capsule", state: "Trial"),
        .init(title: "Capture original crew still aboard before recovery", state: "Trial"),
        .init(title: "Confirm care or an original-person sale", state: "Trial"),
      ], trialDigest: NativePeopleGallery.digest)
  }
  func constructNativePeopleTrial(seed: UInt64) throws -> Game {
    var trial = Game(executive: false)
    trial.screen = .status
    trial.isMissionTrial = true
    trial.trialDigest = NativePeopleGallery.digest
    trial.trialTitle = "Native crew capture and escape-pod rescue"
    trial.trialSeed = seed
    trial.scriptPacks = scriptPacks
    trial.missionPacks = missionPacks
    trial.scriptDurabilityAvailable = true
    trial.viewportWidth = viewportWidth
    trial.viewportHeight = viewportHeight
    trial.commander.credits = 100_000
    trial.commander.cargo[0] = 15
    try trial.commander.prepareEquipment(legacy: false)
    for (name, slot) in [
      (Equipment.empPirateBlaster, ComponentFittingSlot.utility(.empPirateBlaster)),
      ("Salvage Cutter", .utility(.salvageCutter)), ("Fuel Scoops", .utility(.fuelScoops)),
      ("Targeting: Salvage Module", .targetingSalvage),
      (TargetingTier.advanced.equipmentName, .targetingCore),
    ] {
      try trial.commander.grantEquipment(
        name, at: slot, provenance: .grant("Original native people Gallery trial"))
    }
    trial.commander.mirrorFittedEquipment()
    trial.ensureScriptCalendar(origin: .newCommander)
    trial.seedScriptTrial(seed)
    trial.launch()
    guard !trial.docked,
      let ship = ShipCatalogue.all.sorted(by: { $0.id < $1.id }).first(where: {
        $0.game != nil && EMPState.hasSupportedCrew($0)
          && ((try? ShipAccommodationProfile(ship: $0).operatingCrew) ?? 0) > 30
      }), let performance = ship.game,
      let sequence = trial.commander.flightSimulation.allocateSpawn()
    else { throw MissionPackError("The native crew trial cannot admit its original source craft.") }
    var npc = NPCState(
      role: .trader, origin: trial.systemIdentity, destination: trial.systemIdentity)
    npc.resources = .stock(performance)
    npc.legalProvenance = .generated
    npc.cargoProvenance = .generated
    npc.routeProvenance = .generated
    for point in [
      Vector3(-1800, 0, 0), .init(1800, 0, 0), .init(0, 1800, 0),
      .init(0, -1800, 0), .init(0, 0, 2200),
    ] {
      guard let context = trial.gameplayContext() else { break }
      let request = SpawnRequest(
        identity: .init(
          system: context.system, visit: context.visit,
          sequence: sequence, member: 0, producer: .ambient), population: .civilian,
        hull: .cobra, position: context.player.position + point, orientation: Basis3(),
        velocity: .init(0, 0, 0), npc: npc, rock: nil, payload: nil,
        priority: .ordinary, catalogueShipID: ship.id, energy: performance.energy)
      let receipts = trial.admitEncounterPlan(
        .init(
          system: context.system, visit: context.visit,
          revision: context.revision, batches: [.init(requests: [request], atomic: true)],
          intents: []))
      if let actor = receipts.first?.actor {
        trial.weaponsTargetID = trial.bodies.first { $0.physical?.identity == actor }?.id
        trial.selectedFlightTool = .empPirateBlaster
        guard trial.commander.valid else { throw SaveError.invalidCommander }
        return trial
      }
    }
    throw MissionPackError("The native trial's real source craft has no safe admission position.")
  }
}
