import Foundation

struct ScriptWorldSave: Codable, Sendable {
  var libraryScreen: ScriptLibraryState?
  var simulation: ScriptSimulationSave?
  var referenceFrame: ScriptReferenceFrame?
  var contractScreen: ContractScreenSave?
  var bodies: [SpaceBody]
  var market: [MarketItem]
  var docked: Bool
  var mainStation: Bool
  var screen: Screen
  var speed: Double
  var time: Double
  var energy: Double
  var frontShield: Double
  var rearShield: Double
  var laserHeat: Double
  var jumpCountdown: Double?
  var selectedSystem: Int
  var nextBodyID: Int
  var valid: Bool {
    (simulation?.valid ?? true) && (referenceFrame?.valid ?? true)
      && (contractScreen?.valid ?? true) && (libraryScreen?.valid ?? true) && bodies.count <= 1024
      && bodies.reduce(0, { $0 + $1.scriptNativeUnits }) <= 1024
      && Set(bodies.map(\.id)).count == bodies.count
      && Set(bodies.compactMap(\.missionActorID)).count
        == bodies.filter { $0.missionActorID != nil }.count
      && bodies.allSatisfy { body in
        body.id >= 0 && (body.scriptNPC?.valid ?? true)
          && (body.physical?.npc?.resources?.legacyElectricalRecharge.map {
            $0
              == (body.physical?.catalogueShipID.flatMap { ShipCatalogue.ship($0)?.game?.recharge }
                ?? ShipCatalogue.nativeShip(body.hull)?.game?.recharge)
          } ?? true)
          && (body.scriptNPC == nil || body.missionActorID != nil)
          && (body.scriptShot?.valid ?? true)
          && (body.scriptShot == nil
            || body.hull == .missile && body.scriptNPC == nil
              && body.missionActorID == nil && body.missionInstanceID == nil)
          && [
            body.position.x, body.position.y, body.position.z, body.energy, body.rotation,
            body.rotationRate,
          ].allSatisfy { $0.isFinite && abs($0) <= 1e12 }
      }
      && market.count == 17
      && market.allSatisfy {
        (0...1_000_000).contains($0.price) && (0...1_000_000).contains($0.quantity)
      }
      && [speed, time, laserHeat].allSatisfy {
        $0.isFinite && (0...1e12).contains($0)
      }
      && [energy, frontShield, rearShield].allSatisfy { $0.isFinite && $0 >= 0 }
      && (jumpCountdown.map { $0.isFinite && (0...1e12).contains($0) } ?? true)
      && (0...256).contains(selectedSystem) && (0..<1_000_000_000).contains(nextBodyID)
      && nextBodyID >= (bodies.map(\.id).max() ?? 0)
  }
  func consistent(
    with commander: Commander, diagnostics: ScriptRefusalDiagnostic? = nil,
    diagnosticBoundary: ScriptRefusalBoundary = .publication
  ) -> Bool {
    guard commander.nativeSalvageSceneIsConsistent(bodies, docked: docked, atColdBoundary: true)
    else {
      diagnostics?.recordSceneFailure(
        .sceneSalvage, commander: commander, boundary: diagnosticBoundary)
      return false
    }
    return consistentAfterNativeSalvage(
      with: commander, diagnostics: diagnostics, diagnosticBoundary: diagnosticBoundary)
  }
  // Later EMP/station/actor proof buffers are materialized only after the native-first check returns.
  @inline(never)
  private func consistentAfterNativeSalvage(
    with commander: Commander, diagnostics: ScriptRefusalDiagnostic?,
    diagnosticBoundary: ScriptRefusalBoundary
  ) -> Bool {
    if let emp = commander.savedEMPState {
      guard
        emp.sceneIsConsistent(
          bodies, flight: commander.flightSimulation, people: commander.nativePeople)
      else {
        diagnostics?.recordSceneFailure(
          .sceneEMP, commander: commander, boundary: diagnosticBoundary)
        return false
      }
    } else if bodies.contains(where: {
      $0.physical?.empSource != nil || $0.physical?.empCrewPod != nil
        || $0.physical?.spawnIdentity?.producer == .emp
    }) {
      diagnostics?.recordSceneFailure(
        .sceneEMPUnowned, commander: commander, boundary: diagnosticBoundary)
      return false
    }
    if let stations = commander.nativeStations {
      guard
        stations.sceneIsConsistent(
          bodies: bodies, docked: docked, mainStation: mainStation,
          system: .init(galaxy: commander.galaxy, system: commander.system),
          flight: commander.flightSimulation)
      else {
        diagnostics?.recordSceneFailure(
          .sceneStations, commander: commander, boundary: diagnosticBoundary)
        return false
      }
    } else if bodies.contains(where: { $0.nativeStationIdentity != nil }) {
      diagnostics?.recordSceneFailure(
        .sceneStationUnowned, commander: commander, boundary: diagnosticBoundary)
      return false
    }
    guard
      [
        (energy, commander.performance.energy), (frontShield, commander.shieldCapacity),
        (rearShield, commander.rearShieldCapacity),
      ].allSatisfy({ level, capacity in
        capacity.isFinite && capacity > 0 && level <= max(1e12, capacity)
      })
    else {
      diagnostics?.recordSceneFailure(
        .sceneCapacity, commander: commander, boundary: diagnosticBoundary)
      return false
    }
    if screen == .library, let saved = libraryScreen, saved.mode != .books {
      guard let selected = saved.selected, commander.scriptState.books[selected] != nil else {
        diagnostics?.recordSceneFailure(
          .sceneLibrary, commander: commander, boundary: diagnosticBoundary)
        return false
      }
    }
    if screen == .gameOver,
      commander.scriptState.instances.values.contains(where: {
        $0.courier?.terminal == nil && $0.courier?.pendingLoss == nil
          && $0.contract?.offer.courier?.variant == .package
      })
    {
      diagnostics?.recordSceneFailure(
        .sceneCourierFatal, commander: commander, boundary: diagnosticBoundary)
      return false
    }
    if screen == .gameOver,
      commander.scriptState.instances.values.contains(where: {
        $0.contract?.offer.freightPlan != nil && $0.savedOwnedCargo?.terminal == nil
          && $0.savedOwnedCargo?.pendingLoss == nil
      })
    {
      diagnostics?.recordSceneFailure(
        .sceneFreightFatal, commander: commander, boundary: diagnosticBoundary)
      return false
    }
    let stationKey = "main-orbital:\(commander.galaxy):\(commander.system)"
    if let resource = commander.scriptState.stationResources[stationKey] {
      let actual = bodies.first { $0.id == 0 && $0.hull == .station }
      if resource.destroyed {
        guard actual == nil, !(docked && mainStation),
          referenceFrame.map({ $0.station.energy <= 0 }) ?? true
        else {
          diagnostics?.recordSceneFailure(
            .sceneMainDestroyed, commander: commander, boundary: diagnosticBoundary)
          return false
        }
      } else if let actual, actual.energy != resource.energy {
        diagnostics?.recordSceneFailure(
          .sceneMainEnergy, commander: commander, boundary: diagnosticBoundary)
        return false
      }
    }
    var records: [UUID: (UUID, Int, Int, ScriptOwnedActor)] = [:]
    for instance in commander.scriptState.instances.values {
      for encounter in instance.ownedEncounters.values {
        for actor in encounter.actors.values {
          guard records[actor.identity] == nil else {
            diagnostics?.recordSceneFailure(
              .sceneActorDuplicate, commander: commander, boundary: diagnosticBoundary)
            return false
          }
          records[actor.identity] = (instance.id, encounter.galaxy, encounter.system, actor)
        }
      }
    }
    let shotBodies = bodies.filter { $0.scriptShot != nil }
    let expectedShots = commander.scriptState.projectiles.values.filter { $0.presence == .present }
    guard shotBodies.count == expectedShots.count,
      expectedShots.allSatisfy({ $0.galaxy == commander.galaxy && $0.system == commander.system })
    else {
      diagnostics?.recordSceneFailure(
        .sceneShotPopulation, commander: commander, boundary: diagnosticBoundary)
      return false
    }
    for body in shotBodies {
      guard let shot = body.scriptShot,
        let record = commander.scriptState.projectiles[shot.identity],
        record.presence == .present, record.body.id == body.id, let anchor = referenceFrame?.station
      else {
        diagnostics?.recordSceneFailure(
          .sceneShotBinding, commander: commander, boundary: diagnosticBoundary)
        return false
      }
      var canonical = shot
      canonical.velocity = anchor.orientation.inverse(shot.velocity)
      guard canonical == record.body.scriptShot else {
        diagnostics?.recordSceneFailure(
          .sceneShotCanonical, commander: commander, boundary: diagnosticBoundary)
        return false
      }
    }
    if let ledger = commander.scriptState.calendarLedger {
      if let journey = ledger.pendingJourney {
        guard !docked, jumpCountdown != nil, journey.galaxy == commander.galaxy,
          journey.origin == commander.system
        else {
          diagnostics?.recordSceneFailure(
            .scenePendingJourney, commander: commander, boundary: diagnosticBoundary)
          return false
        }
      } else if jumpCountdown != nil && !ledger.legacyUntrackedJourney {
        diagnostics?.recordSceneFailure(
          .sceneUnadmittedJump, commander: commander, boundary: diagnosticBoundary)
        return false
      }
      if ledger.legacyUntrackedJourney && (docked || jumpCountdown == nil) {
        diagnostics?.recordSceneFailure(
          .sceneLegacyJourney, commander: commander, boundary: diagnosticBoundary)
        return false
      }
    }
    let physical = bodies.filter { $0.missionActorID != nil }
    let expected = records.values.filter { $0.3.presence == .present }
    guard physical.count == expected.count,
      expected.allSatisfy({ $0.1 == commander.galaxy && $0.2 == commander.system })
    else {
      diagnostics?.recordSceneFailure(
        .sceneActorPopulation, commander: commander, boundary: diagnosticBoundary)
      return false
    }
    for body in physical {
      var canonicalNPC = body.scriptNPC
      if let velocity = canonicalNPC?.velocity, let anchor = referenceFrame?.station {
        canonicalNPC?.velocity = anchor.orientation.inverse(velocity)
      }
      guard let identity = body.missionActorID, let record = records[identity],
        body.missionInstanceID == record.0, record.3.presence == .present,
        body.id == record.3.body.id, body.hull == record.3.body.hull,
        canonicalNPC == record.3.body.scriptNPC,
        body.energy == record.3.body.energy, body.missiles == record.3.body.missiles,
        body.ecmEnabled == record.3.body.ecmEnabled, body.hostile == record.3.body.hostile
      else {
        diagnostics?.recordSceneFailure(
          .sceneActorBinding, commander: commander, boundary: diagnosticBoundary)
        return false
      }
    }
    return true
  }
}
struct ScriptSavePointer: Codable {
  let format: String
  let schemaVersion: Int
  let generation: String
  let hashes: [String: String]
  var scope: String? = nil
  var valueCodec: String? = nil
}

/// Publication is synchronous inside GameRuntime: no actor reentrancy can overwrite newer simulation state.
enum ScriptSaveStore {
  @discardableResult
  static func write(
    commander: Commander, world: ScriptWorldSave, to url: URL, scope: String = "commander",
    exclusive: Bool = false, diagnostics: ScriptRefusalDiagnostic? = nil,
    diagnosticBoundary: ScriptRefusalBoundary = .publication,
    clueTrust: ScriptClueTrustCatalog = .production,
    navigationBinding: ScriptNavigationTradeBinding? = nil
  ) throws -> AlienStoragePublication? {
    try validateForPublication(
      commander: commander, world: world, scope: scope, diagnostics: diagnostics,
      diagnosticBoundary: diagnosticBoundary, clueTrust: clueTrust,
      navigationBinding: navigationBinding)
    return try publishValidated(
      commander: commander, world: world, to: url, scope: scope, exclusive: exclusive,
      diagnostics: diagnostics, diagnosticBoundary: diagnosticBoundary)
  }
  // Keep the original read-only parameter convention for the unchanged logical guard expressions.
  @inline(never)
  private static func validateForPublication(
    commander: Commander, world: ScriptWorldSave, scope: String,
    diagnostics: ScriptRefusalDiagnostic?, diagnosticBoundary: ScriptRefusalBoundary,
    clueTrust: ScriptClueTrustCatalog, navigationBinding: ScriptNavigationTradeBinding?
  ) throws {
    guard ["commander", "gallery"].contains(scope), commander.scriptState.calendarLedger != nil,
      commander.valid, world.valid, ScriptFreightVersionedSave.validateClaims(commander),
      commander.usesFreightNativeSaveVersion || !commander.usesProviderContractSaveVersion,
      world.consistent(
        with: commander, diagnostics: diagnostics, diagnosticBoundary: diagnosticBoundary)
    else {
      if let diagnostics, !diagnostics.contains(diagnosticBoundary) {
        // True guard prefix; bits 32/64/1/2/4/8/16: scope, calendar, commander, world, claims,
        // envelope, scene. Later bits are unobserved, not evidence their predicates failed.
        let checks = ScriptRefusalObservation.storeChecks(commander, world: world, scope: scope)
        diagnostics.record(
          diagnosticBoundary,
          .init(
            stage: .storeValidation, error: SaveError.invalidCommander, commander: commander,
            checks: checks))
      }
      throw SaveError.invalidCommander
    }
    guard ScriptClueVersionedSave.validateClaims(commander, trust: clueTrust),
      ScriptNavigationTradeSave.validateClaims(commander, binding: navigationBinding)
    else {
      throw SaveError.invalidCommander
    }
  }
  // The original deliberate header copy and all encoding/file work begin only after validation returns.
  @inline(never)
  private static func publishValidated(
    commander: Commander, world: ScriptWorldSave, to url: URL, scope: String, exclusive: Bool,
    diagnostics: ScriptRefusalDiagnostic?, diagnosticBoundary: ScriptRefusalBoundary
  ) throws -> AlienStoragePublication? {
    let semantic = JSONEncoder()
    guard try semantic.encode(commander.scriptState).count <= 33_554_432,
      try semantic.encode(commander.contracts).count <= 33_554_432
    else {
      diagnostics?.record(
        diagnosticBoundary,
        .init(stage: .storeSize, error: SaveError.invalidCommander, commander: commander))
      throw SaveError.invalidCommander
    }
    let generation = UUID().uuidString
    let root = url.appendingPathExtension("missions")
    let directory = root.appendingPathComponent(generation, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let alienPublication = try AlienStorageVersionedSave.stage(commander, in: directory)
    let encoder = ScriptValueStorage.encoder()
    var header = commander
    header.publishAlienStorage(alienPublication)
    header.scriptState = ScriptEngineState()
    header.contracts = ScriptContractState()
    var chunks = [
      "commander.json": try encoder.encode(header),
      "missions.json": try encoder.encode(commander.scriptState),
      "world.json": try encoder.encode(world),
      "contracts.json": try encoder.encode(commander.contracts),
    ]
    if let alienPublication {
      let store = try AlienStoragePageStore(directory: directory)
      let rootData = try store.readGenerationRoot()
      guard ScriptPackLibrary.hash(rootData) == alienPublication.after.reference?.rootHash else {
        throw AlienStorageError.hashMismatch
      }
      chunks[AlienStorageVersionedSave.rootName] = rootData
    }
    guard chunks["commander.json"]!.count <= 4_194_304,
      chunks["missions.json"]!.count <= 134_217_728,
      chunks["world.json"]!.count <= 8_388_608
        && chunks["contracts.json"]!.count <= 134_217_728
    else {
      diagnostics?.record(
        diagnosticBoundary,
        .init(stage: .storeSize, error: SaveError.invalidCommander, commander: commander))
      throw SaveError.invalidCommander
    }
    // Never replace an old generation; a failed publication leaves the previous pointer valid.
    if alienPublication != nil {
      let store = try AlienStoragePageStore(directory: directory)
      for key in chunks.keys.sorted() where key != AlienStorageVersionedSave.rootName {
        let limit =
          key == "commander.json" ? 4_194_304 : key == "world.json" ? 8_388_608 : 134_217_728
        try store.writeGenerationChunk(chunks[key]!, name: key, maximumBytes: limit)
      }
    } else {
      for key in chunks.keys.sorted() {
        try chunks[key]!.write(to: directory.appendingPathComponent(key), options: .atomic)
      }
    }
    let pointer = ScriptSavePointer(
      format: "elite-script-save",
      schemaVersion: ScriptNavigationTradeSave.hasClaims(commander)
        ? (alienPublication != nil
          ? ScriptNavigationTradeSave.alienVersion : ScriptNavigationTradeSave.version)
        : commander.scriptState.savedClueJournal != nil
          ? (alienPublication != nil
            ? ScriptClueVersionedSave.alienVersion : ScriptClueVersionedSave.version)
          : commander.usesFreightNativeSaveVersion
            ? (alienPublication != nil
              ? ScriptFreightVersionedSave.alienVersion : ScriptFreightVersionedSave.version)
            : alienPublication != nil
              ? 27
              : commander.usesEconomyMiningSaveVersion
                ? 26
                : commander.usesRingMiningSaveVersion || commander.usesElectricalSaveVersion
                  || commander.usesModularDriveSaveVersion
                  ? 25
                  : commander.usesNativePeopleSaveVersion
                    ? 24
                    : commander.scriptState.financeLedger != nil
                      ? 23 : (commander.usesEMPSaveVersion ? 22 : 21),
      generation: generation,
      hashes: chunks.mapValues(ScriptPackLibrary.hash), scope: scope,
      valueCodec: ScriptValueStorage.codec)
    let bytes = try encoder.encode(pointer)
    try CommanderSavePublication.write(bytes, to: url, exclusive: exclusive)
    return alienPublication
  }
  static func generationDirectory(_ generation: String, from url: URL) throws -> URL {
    guard UUID(uuidString: generation)?.uuidString == generation else {
      throw SaveError.invalidCommander
    }
    return url.appendingPathExtension("missions").appendingPathComponent(
      generation, isDirectory: true)
  }
  static func read(
    _ pointerBytes: Data, from url: URL, clueTrust: ScriptClueTrustCatalog = .production,
    navigationBinding: ScriptNavigationTradeBinding? = nil
  ) throws -> (Commander, ScriptWorldSave) {
    guard pointerBytes.count <= 262144 else { throw SaveError.invalidCommander }
    try ScriptSaveJSONPreflight.validate(pointerBytes)
    try ScriptClueVersionedSave.validateFields(pointerBytes, part: .contracts, schema: nil)
    try ScriptNavigationTradeSave.validateFields(pointerBytes, part: .contracts, schema: nil)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: pointerBytes)
    let clues = ScriptClueVersionedSave.contains(pointer.schemaVersion)
    let navigation = ScriptNavigationTradeSave.contains(pointer.schemaVersion)
    let freight =
      pointer.schemaVersion == ScriptFreightVersionedSave.version
      || pointer.schemaVersion == ScriptFreightVersionedSave.alienVersion
    let alien =
      pointer.schemaVersion == 27
      || pointer.schemaVersion == ScriptClueVersionedSave.alienVersion
      || pointer.schemaVersion == ScriptNavigationTradeSave.alienVersion
      || pointer.schemaVersion == ScriptFreightVersionedSave.alienVersion
    var names: Set<String> =
      pointer.schemaVersion >= 8
      ? ["commander.json", "missions.json", "world.json", "contracts.json"]
      : ["commander.json", "missions.json", "world.json"]
    if alien { names.insert(AlienStorageVersionedSave.rootName) }
    guard pointer.format == "elite-script-save",
      (2...27).contains(pointer.schemaVersion) || freight || clues || navigation,
      UUID(uuidString: pointer.generation)?.uuidString == pointer.generation,
      Set(pointer.hashes.keys) == names,
      pointer.schemaVersion < 6 || ["commander", "gallery"].contains(pointer.scope ?? "")
    else { throw SaveError.invalidCommander }
    guard
      pointer.schemaVersion >= 13
        ? pointer.valueCodec == ScriptValueStorage.codec : pointer.valueCodec == nil
    else {
      throw SaveError.invalidCommander
    }
    let typed = pointer.schemaVersion >= 13
    let storedLimit = typed ? 134_217_728 : 33_554_432
    let directory = try generationDirectory(pointer.generation, from: url)
    var chunks: [String: Data] = [:]
    var limits = [
      ("commander.json", 4_194_304), ("missions.json", storedLimit), ("world.json", 8_388_608),
    ]
    if pointer.schemaVersion >= 8 { limits.append(("contracts.json", storedLimit)) }
    if alien {
      limits.append((AlienStorageVersionedSave.rootName, AlienStoragePageCodec.maximumRootBytes))
    }
    for (name, limit) in limits {
      let location = directory.appendingPathComponent(name)
      let properties = try location.resourceValues(forKeys: [
        .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
      ])
      guard properties.isRegularFile == true, properties.isSymbolicLink != true,
        (properties.fileSize ?? Int.max) <= limit
      else { throw SaveError.invalidCommander }
      let data = try CommanderSaveInput.read(
        from: location, maximumBytes: limit, denySymbolicLinks: true)
      guard data.count <= limit, ScriptPackLibrary.hash(data) == pointer.hashes[name] else {
        throw SaveError.invalidCommander
      }
      try ScriptSaveJSONPreflight.validate(data)
      if name == "world.json" {
        try ScriptClueVersionedSave.validateFields(data, part: .contracts, schema: nil)
        try ScriptNavigationTradeSave.validateFields(data, part: .contracts, schema: nil)
      }
      if name == "commander.json" {
        // This helper's >=27 branch describes Alien storage, not every newer envelope.
        let alienHeaderSchema =
          freight || clues || navigation ? (alien ? 27 : 26) : pointer.schemaVersion
        try AlienStorageVersionedSave.validateHeader(data, schema: alienHeaderSchema)
        try ScriptSaveJSONPreflight.validateFreightFields(
          data, part: .commander, schema: pointer.schemaVersion)
      } else if name == "missions.json" {
        try ScriptSaveJSONPreflight.validateFreightFields(
          data, part: .missions, schema: pointer.schemaVersion)
      } else if name == "contracts.json" {
        try ScriptSaveJSONPreflight.validateFreightFields(
          data, part: .contracts, schema: pointer.schemaVersion)
      }
      if name == "commander.json", pointer.schemaVersion < 26 {
        try EconomyMiningVersionedSave.rejectFields(data)
      }
      if name == "commander.json", pointer.schemaVersion < 25 {
        try RingMiningVersionedSave.rejectFields(data)
        try HyperspaceDriveVersionedSave.rejectFields(data)
      }
      if pointer.schemaVersion < 25, ["commander.json", "world.json"].contains(name) {
        try ElectricalVersionedSave.rejectFields(data)
      }
      if name == "commander.json", pointer.schemaVersion < 24 {
        try NativePeopleVersionedSave.rejectFields(data)
      }
      if name == "commander.json" {
        try ScriptFinanceVersionedSave.rejectFields(data, part: .commander)
      } else if name == "missions.json", pointer.schemaVersion < 23 {
        try ScriptFinanceVersionedSave.rejectFields(data, part: .missions)
      }
      if pointer.schemaVersion < 22 {
        if name == "commander.json" { try EMPVersionedSave.rejectFields(data, part: .commander) }
        if name == "world.json" { try EMPVersionedSave.rejectFields(data, part: .world) }
      }
      if pointer.schemaVersion < 21 || name == "commander.json" {
        let location: ScriptSaveJSONPreflight.CourierLocation? =
          name == "missions.json"
          ? .missions
          : name == "contracts.json"
            ? .contracts
            : name == "commander.json"
              ? (pointer.schemaVersion >= 21 ? .currentCommanderHeader : .rawCommander) : nil
        if let location {
          try ScriptSaveJSONPreflight.rejectCourierFields(data, location: location)
        }
      }
      chunks[name] = data
    }
    var commander = try ScriptValueStorage.decoder(typed: typed).decode(
      Commander.self, from: chunks["commander.json"]!)
    guard alien == commander.usesAlienStorageSaveVersion else {
      throw SaveError.invalidCommander
    }
    if alien {
      try AlienStorageVersionedSave.hydrate(
        &commander, rootHash: pointer.hashes[AlienStorageVersionedSave.rootName]!,
        directory: directory)
    }
    if pointer.schemaVersion <= 4 { commander.migrateLegacyPassengerMarker() }
    let missionsDecoder = ScriptValueStorage.decoder(typed: typed)
    missionsDecoder.userInfo[LegacyMissionEncounterProvenance.storageKey] = true
    commander.scriptState = try missionsDecoder.decode(
      ScriptEngineState.self, from: chunks["missions.json"]!)
    guard
      pointer.schemaVersion < 23
        ? commander.scriptState.financeLedger == nil
        : pointer.schemaVersion == 23 ? commander.scriptState.financeLedger != nil : true,
      pointer.schemaVersion >= 27
        || (pointer.schemaVersion == 26) == commander.usesEconomyMiningSaveVersion,
      pointer.schemaVersion >= 26
        || (pointer.schemaVersion == 25)
          == (commander.usesRingMiningSaveVersion || commander.usesElectricalSaveVersion
            || commander.usesModularDriveSaveVersion),
      pointer.schemaVersion >= 25
        || (pointer.schemaVersion == 24) == commander.usesNativePeopleSaveVersion
    else {
      throw SaveError.invalidCommander
    }
    guard
      pointer.schemaVersion >= 21
        || commander.scriptState.instances.values.allSatisfy({
          $0.ownedEncounters.values.allSatisfy { $0.legacyProvenance == nil }
        })
    else { throw SaveError.invalidCommander }
    guard
      pointer.schemaVersion >= 20
        || (commander.scriptState.pledgeLedger == nil
          && commander.scriptState.instances.values.allSatisfy({ $0.pledgeReceiptID == nil }))
    else {
      throw SaveError.invalidCommander
    }
    guard
      pointer.schemaVersion >= 19
        || commander.scriptState.instances.values.allSatisfy({
          $0.campaignParent == nil && $0.savedCampaignChildren == nil
            && $0.savedCampaignReceiptScopes == nil
        })
    else { throw SaveError.invalidCommander }
    if let bytes = chunks["contracts.json"] {
      commander.contracts = try ScriptValueStorage.decoder(typed: typed).decode(
        ScriptContractState.self, from: bytes)
    } else if !commander.contracts.boards.isEmpty
      || commander.scriptState.instances.values.contains(where: { $0.contract != nil })
    {
      throw SaveError.invalidCommander
    }
    guard clues || navigation || freight == commander.usesFreightNativeSaveVersion,
      navigation || clues == (commander.scriptState.savedClueJournal != nil),
      navigation == ScriptNavigationTradeSave.hasClaims(commander),
      commander.usesFreightNativeSaveVersion || !commander.usesProviderContractSaveVersion,
      ScriptClueVersionedSave.validateClaims(commander, trust: clueTrust),
      ScriptNavigationTradeSave.validateClaims(commander, binding: navigationBinding)
    else {
      throw SaveError.invalidCommander
    }
    if freight || clues || navigation, !ScriptFreightVersionedSave.validateClaims(commander) {
      throw SaveError.invalidCommander
    }
    let world = try ScriptValueStorage.decoder(typed: typed).decode(
      ScriptWorldSave.self, from: chunks["world.json"]!)
    // Versioned mission provenance cannot be validated against the header alone.
    // Migrate only after all state/contract/physical/world chunks have been joined.
    let hadMissingCalendar = commander.scriptState.calendarLedger == nil
    guard pointer.schemaVersion < 10 || !hadMissingCalendar else {
      throw SaveError.invalidCommander
    }
    try commander.prepareEquipment()
    if hadMissingCalendar {
      if commander.scriptState.calendarLedger == nil {
        commander.scriptState.calendarLedger = .init(origin: .inactiveLegacyMigration)
      }
      if world.jumpCountdown != nil {
        commander.scriptState.calendarLedger?.legacyUntrackedJourney = true
      }
    }
    let semantic = JSONEncoder()
    guard try semantic.encode(commander.scriptState).count <= 33_554_432,
      try semantic.encode(commander.contracts).count <= 33_554_432,
      pointer.schemaVersion < 10 || commander.scriptState.calendarLedger != nil,
      commander.valid, world.valid, world.consistent(with: commander)
    else {
      throw SaveError.invalidCommander
    }
    if pointer.schemaVersion <= 11 {
      for id in commander.scriptState.instances.keys {
        guard var owner = commander.scriptState.instances[id] else {
          throw SaveError.invalidCommander
        }
        for encounterID in owner.ownedEncounters.keys {
          guard var encounter = owner.ownedEncounters[encounterID] else {
            throw SaveError.invalidCommander
          }
          encounter.legacyProvenance = try .importValidated(
            schema: pointer.schemaVersion, owner: owner, encounter: encounter)
          owner.ownedEncounters[encounterID] = encounter
        }
        commander.scriptState.instances[id] = owner
      }
      // Frozen pending condition counts against the existing semantic cap before any publication.
      guard commander.valid, world.consistent(with: commander),
        try semantic.encode(commander.scriptState).count <= 33_554_432
      else { throw SaveError.invalidCommander }
    }
    return (commander, world)
  }
}

extension Game {
  var scriptWorldSave: ScriptWorldSave {
    ScriptWorldSave(
      libraryScreen: library, simulation: scriptSimulationSave,
      referenceFrame: scriptReferenceFrame,
      contractScreen: commander.contracts.boards.isEmpty ? nil : contractBoard.save, bodies: bodies,
      market: market, docked: docked,
      mainStation: dockedAtMainStation,
      screen: screen, speed: speed, time: scriptStartupTime ?? time, energy: energy,
      frontShield: frontShield,
      rearShield: rearShield, laserHeat: laserHeat, jumpCountdown: jumpCountdown,
      selectedSystem: selectedSystem, nextBodyID: nextBodyID)
  }
  mutating func restoreScriptWorld(_ world: ScriptWorldSave) {
    restoreScriptSimulation(world.simulation)
    scriptReferenceFrame = world.referenceFrame
    bodies = world.bodies
    market = world.market
    docked = world.docked
    dockedAtMainStation = world.mainStation
    // Pending contacts restore through Contacts, not a stale UI selection token.
    screen = world.screen.isFlight ? world.screen : .status
    speed = world.speed
    time = world.time
    energy = world.energy
    frontShield = world.frontShield
    rearShield = world.rearShield
    laserHeat = world.laserHeat
    jumpCountdown = world.jumpCountdown
    selectedSystem = world.selectedSystem
    nextBodyID = world.nextBodyID
    if let saved = world.contractScreen {
      contractBoard.restoredSelection = saved.selection
      contractBoard.previous = saved.previous
      contractBoard.action = saved.action
      contractBoard.scroll = saved.scroll
    }
    if world.screen == .library, let saved = world.libraryScreen {
      library = saved
      if [.handoff, .help, .library, .mission, .demo, .title, .gameOver].contains(library.previous)
      {
        library.previous = .status
      }
      screen = .library
    }
    if world.screen == .contracts, docked, dockedAtMainStation, let saved = world.contractScreen {
      screen = .contracts
      refreshContractRows(restoring: saved)
    }
  }
}
