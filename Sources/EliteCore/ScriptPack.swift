import CryptoKit
import Foundation
import TOMLDecoder

public struct ScriptHandler: Codable, Sendable {
  public let event: String
  public let function: String
}
public struct ScriptMission: Codable, Sendable {
  public let id: String
  public let title: String
  public let briefing: String
  public let destination: String
  public let reward: String
  public let milestones: [String]
  public let requiredDestructionEncounters: [String]?
  public let requiredPassengerParties: [String]?
  public let requiredEquipmentReturns: [String]?
  public let requiredChoiceGroups: [String]?
  public let requiredBooks: [String]?
  public let requiredCollections: [String]?
  public let parentOnly: Bool?
}
public struct ScriptDialog: Codable, Sendable {
  public let id: String
  public let text: String
  public let choices: [ScriptDialogChoice]?
  public let collection: String?
}
public struct ScriptManifest: Codable, Sendable {
  public let schemaVersion: Int
  public let missionAPI: Int
  public let id: String
  public let version: String
  public let minimumEngine: String
  public let capabilities: [String]
  public let dependencies: [String]?
  public let priority: Int
  public let source: String
  public let license: String
  public let environments: [String]
  public let module: String
  public let mission: ScriptMission
  public let handlers: [ScriptHandler]
  public let dialogs: [ScriptDialog]?
  public let encounters: [ScriptEncounterDefinition]?
  public let passengerParties: [ScriptPassengerParty]?
  public let trial: ScriptTrialDefinition?
  public let equipment: [ScriptGearDefinition]?
  public let board: ScriptBoardDefinition?
  public let pledge: ScriptPledgeDefinition?
  public let courier: ScriptCourierDefinition?
  var procurement: ScriptProcurementDefinition? = nil
  var freight: ScriptFreightDefinition? = nil
  var coldChain: WayfarerColdChainDefinition? = nil
  public let npcs: [ScriptNPCDefinition]?
  public let models: [ScriptNPCModel]?
  public let modules: [ScriptModuleDefinition]?
  public let worldJobs: [ScriptWorldJobDefinition]?
  public let receiptRequirements: [ScriptReceiptRequirement]?
  public let answerRequirements: [ScriptAnswerRequirement]?
  public let books: [ScriptBookDefinition]?
  public let collections: [ScriptCollectionDefinition]?
  public let loans: [ScriptFinanceDefinition]?
  public let children: [ScriptChildDefinition]?
  var providerContract: ScriptProviderContractDefinition? = nil
  public var stateID: String { id + "/" + mission.id }
}
public struct ScriptPack: Sendable {
  public let manifest: ScriptManifest
  public let source: Data
  public let manifestBytes: Data
  public let digest: String
  public let models: [String: ShipDesign]
  public let resourceBytes: [String: Data]
  public let entryBytes: Data?
  init(
    manifest: ScriptManifest, source: Data, manifestBytes: Data, digest: String,
    models: [String: ShipDesign] = [:], resourceBytes: [String: Data] = [:], entryBytes: Data? = nil
  ) {
    self.manifest = manifest
    self.source = source
    self.manifestBytes = manifestBytes
    self.digest = digest
    self.models = models
    self.resourceBytes = resourceBytes
    self.entryBytes = entryBytes
  }
  public var missingCapabilities: [String] {
    Set(manifest.capabilities).subtracting(ScriptCapabilities.implemented).sorted()
  }
}

/// Only capabilities with executable native support are advertised.
public enum ScriptCapabilities {
  public static let implemented: Set<String> = [
    "script-lua-v1", "story-v2", "economy-v2", "cargo-v2", "local-flight-clocks-v2",
    "classic-encounters-v2", "charter-passengers-v2", "durable-commands-v2", "gallery-basic-v2",
    "owned-equipment-v2",
    "contracts-basic-v2", "profiled-encounters-v2",
    "pack-modules-v2", "calendar-clocks-v2", "pulse-counters-v2", "world-resource-jobs-v2",
    "event-history-v2", "deterministic-plans-v2", "typed-save-values-v2", "commander-queries-v2",
    "completion-receipts-v2", "exclusive-choices-v2", "dialogue-choices-v2", "compound-receipts-v2",
    "library-books-basic-v2", "partial-collections-v2", "scoped-campaigns-basic-v2",
    "station-pledges-basic-v2", "courier-contracts-basic-v2", "mission-calendar-v2",
    "finance-obligations-basic-v2", "procurement-contracts-basic-v2", "freight-contracts-basic-v2",
    ScriptFinanceInterest.capability,
    "npc-wormhole-transit-v2",
    ScriptNavigationTradeContent.capability,
  ]
  static func playerFeatureName(_ capability: String) -> String {
    let names = [
      "world-actors-v1": "persistent ships and stations",
      "encounter-admission-v1": "physical encounter deployment",
      "flight-ai-v1": "scripted ship navigation", "combat-events-v1": "mission combat tracking",
      "wormhole-transit-v1": "ship travel through wormholes",
      "world-clocks-v1": "mission clocks and station jobs",
      "custody-v1": "passenger and cargo custody",
      "fitting-storage-v1": "equipment transfer and storage",
      "contracts-v1": "station contract boards", "campaigns-v1": "linked campaigns",
      "gallery-world-v1": "mission trial scenarios",
    ]
    return names[capability] ?? "additional mission support"
  }
  static let events: Set<String> = [
    "mission.accepted", "station.docked", "station.undocked", "system.entered", "contact.requested",
    "dialogue.confirmed", "timer.fired", "mission.abandoned", "encounter.admitted",
    "encounter.pending", "actor.destroyed", "actor.removed",
    "ship.changed", "equipment.changed", "gear.consumed",
    "equipment.issued", "equipment.returned", "equipment.released",
    "actor.intent.accepted", "actor.arrived", "actor.target.lost", "actor.damaged",
    "actor.transit.requested", "actor.transit.opened", "actor.transit.departed",
    "actor.transit.arrived",
    "component.destroyed", "weapon.fired", "mission.receipted", "dialogue.chosen", "book.unlocked",
    "collection.delivered", "campaign.child.started", "courier.terminated",
    "provider.transition", "provider.closed", "procurement.terminated", "freight.terminated",
  ]
}

public enum ScriptPackLibrary {
  public static func read(_ directory: URL) throws -> ScriptPack {
    let properties = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
    guard properties.isDirectory == true, properties.isSymbolicLink != true else {
      throw MissionPackError("Choose a mission pack folder containing manifest.toml.")
    }
    let bytes = try readFile("manifest.toml", in: directory)
    let root = try TOMLTable(source: bytes)
    try keys(
      root,
      "schemaVersion missionAPI id version minimumEngine capabilities dependencies priority source license environments module mission handlers dialogs encounters passengerParties trial equipment board pledge courier procurement freight coldChain npcs models modules worldJobs receiptRequirements answerRequirements books collections loans children providerContract"
    )
    try keys(
      root.table(forKey: "mission"),
      "id title briefing destination reward milestones requiredDestructionEncounters requiredPassengerParties requiredEquipmentReturns requiredChoiceGroups requiredBooks requiredCollections parentOnly"
    )
    if root.contains(key: "board") {
      try keys(
        root.table(forKey: "board"), "id title generator clock refreshSeconds exclusiveGroup")
    }
    if root.contains(key: "providerContract") {
      let provider = try root.table(forKey: "providerContract")
      try keys(
        provider,
        "provider origin destination payload observation fullReward urgentReward recoveryReward crewReward"
      )
      try keys(provider.table(forKey: "origin"), "galaxy system")
      try keys(provider.table(forKey: "destination"), "galaxy system")
      try keys(
        provider.table(forKey: "observation"),
        "contactRange contactSpeed contactSeconds escortRange escortSeconds checkpoints")
    }
    if root.contains(key: "courier") {
      try keys(
        root.table(forKey: "courier"), "profile generatorRevision deliveryContact abandonContact")
    }
    if root.contains(key: "procurement") {
      let declaration = try root.table(forKey: "procurement")
      try keys(
        declaration,
        "profile generatorRevision variant deliveryContact abandonContact collectionTemplate")
      try keys(declaration.table(forKey: "collectionTemplate"), "id title")
    }
    if root.contains(key: "freight") {
      let declaration = try root.table(forKey: "freight")
      // validateFreight permits declared hazards only for the exact bonded profile.
      try keys(
        declaration,
        "profile generatorRevision variant deliveryContact abandonContact collectionTemplate bondedHazardTiers"
      )
      try keys(declaration.table(forKey: "collectionTemplate"), "id title")
    }
    if root.contains(key: "coldChain") {
      let declaration = try root.table(forKey: "coldChain")
      try keys(
        declaration,
        "source objective receiver batch stockUnits tonnes maximumActive route hazardTier flightAllowance rewardNative"
      )
      for name in ["source", "objective", "receiver"] {
        try keys(declaration.table(forKey: name), "galaxy system resourceKey")
      }
    }
    if root.contains(key: "pledge") {
      try keys(root.table(forKey: "pledge"), "profile provider title creditAmounts foodTonnes")
    }
    for (name, allowed) in [
      "answerRequirements": "dialogue choice minimumCount",
      "children": "id definition version digest terminalPolicy",
      "loans": "id profile creditor title principal galaxy system interest",
      "handlers": "event function", "dialogs": "id text choices collection",
      "receiptRequirements":
        "id stage definition version digest outcome outcomes minimumCount choiceGroup choice child",
      "equipment": "id name quantity loan mount returnPolicy",
      "worldJobs":
        "id title handler owner galaxy system encounter actor firstDue interval policy counters controlledEncounters",
    ]
    where root.contains(key: name) {
      let array = try root.array(forKey: name)
      for i in 0..<array.count { try keys(array.table(atIndex: i), allowed) }
    }
    if root.contains(key: "loans") {
      let loans = try root.array(forKey: "loans")
      for index in 0..<loans.count {
        let loan = try loans.table(atIndex: index)
        if loan.contains(key: "interest") {
          try keys(
            loan.table(forKey: "interest"),
            "rateBasisPoints periodSeconds rounding maximumInterest")
        }
      }
    }
    if root.contains(key: "dialogs") {
      let dialogs = try root.array(forKey: "dialogs")
      for index in 0..<dialogs.count {
        let dialog = try dialogs.table(atIndex: index)
        if dialog.contains(key: "choices") {
          let choices = try dialog.array(forKey: "choices")
          for choice in 0..<choices.count {
            try keys(choices.table(atIndex: choice), "id label group")
          }
        }
      }
    }
    if root.contains(key: "collections") {
      let collections = try root.array(forKey: "collections")
      for index in 0..<collections.count {
        let collection = try collections.table(atIndex: index)
        try keys(collection, "id title galaxy system items")
        let items = try collection.array(forKey: "items")
        for item in 0..<items.count {
          try keys(items.table(atIndex: item), "commodity unit quantity")
        }
      }
    }
    if root.contains(key: "books") {
      let books = try root.array(forKey: "books")
      for index in 0..<books.count {
        let book = try books.table(atIndex: index)
        try keys(book, "id title chapters")
        let chapters = try book.array(forKey: "chapters")
        for chapter in 0..<chapters.count {
          try keys(chapters.table(atIndex: chapter), "id title text level")
        }
      }
    }
    if root.contains(key: "encounters") {
      let encounters = try root.array(forKey: "encounters")
      for index in 0..<encounters.count {
        let table = try encounters.table(atIndex: index)
        try keys(table, "id galaxy system profile actors")
        let actors = try table.array(forKey: "actors")
        for actor in 0..<actors.count {
          try keys(actors.table(atIndex: actor), "id hull npc x y z hostile")
        }
      }
    }
    try validateNPCKeys(root)
    if root.contains(key: "modules") {
      let modules = try root.array(forKey: "modules")
      for i in 0..<modules.count { try keys(modules.table(atIndex: i), "id path") }
    }
    if root.contains(key: "passengerParties") {
      let parties = try root.array(forKey: "passengerParties")
      for index in 0..<parties.count {
        try keys(
          parties.table(atIndex: index),
          "id names pickupGalaxy pickupSystem destinationGalaxy destinationSystem")
      }
    }
    if root.contains(key: "trial") {
      try keys(root.table(forKey: "trial"), "ship galaxy system credits cabins flight offer")
    }
    let manifest = try TOMLDecoder().decode(ScriptManifest.self, from: bytes)
    try validate(manifest)
    let entry = try readFile(manifest.module, in: directory)
    guard String(data: entry, encoding: .utf8) != nil, !entry.contains(0) else {
      throw MissionPackError("Mission Lua must be UTF-8 text without NUL bytes.")
    }
    let modules = try compileModules(manifest.modules ?? [], entry: entry, directory: directory)
    let source = modules.source
    let assets = try readNPCModels(manifest, directory: directory)
    try ScriptEvaluator.validate(
      source: source,
      handlers: manifest.handlers.map(\.function) + (manifest.board.map { [$0.generator] } ?? [])
        + (manifest.worldJobs ?? []).map(\.handler))
    var digestInput = Data()
    for (name, data) in [("manifest.toml", bytes), (manifest.module, entry)] {
      digestInput.append(try ScriptWire.encode([.string(name), .integer(Int64(data.count))]))
      digestInput.append(data)
    }
    for name in modules.resources.keys.sorted() {
      let data = modules.resources[name]!
      digestInput.append(try ScriptWire.encode([.string(name), .integer(Int64(data.count))]))
      digestInput.append(data)
    }
    for reference in assets.designs.keys.sorted() {
      let model = try canonicalGeometry(assets.designs[reference]!)
      digestInput.append(try ScriptWire.encode([.string(reference), .integer(Int64(model.count))]))
      digestInput.append(model)
    }
    return ScriptPack(
      manifest: manifest, source: source, manifestBytes: bytes, digest: hash(digestInput),
      models: assets.designs,
      resourceBytes: assets.bytes.merging(modules.resources) { first, _ in first },
      entryBytes: entry)
  }
  static func hash(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
  static func keys(_ table: TOMLTable, _ allowed: String) throws {
    let unknown = Set(table.keys).subtracting(allowed.split(separator: " ").map(String.init))
    guard unknown.isEmpty else {
      throw MissionPackError(
        "Unknown script pack keys: " + unknown.sorted().joined(separator: ", "))
    }
  }
  static func validate(_ manifest: ScriptManifest) throws {
    try WayfarerColdChainSave.validateDeclaration(manifest)
    guard manifest.schemaVersion == 2, manifest.missionAPI == 2, manifest.minimumEngine == "2.0.0",
      PackValidation.identifier(manifest.id), PackValidation.identifier(manifest.mission.id),
      PackValidation.version(manifest.version), (0...1000).contains(manifest.priority),
      (1...4096).contains(manifest.source.utf8.count),
      (1...4096).contains(manifest.license.utf8.count),
      manifest.environments.count <= 2, manifest.capabilities.count <= 64,
      manifest.mission.destination.utf8.count <= 2048, manifest.mission.reward.utf8.count <= 2048,
      !manifest.environments.isEmpty,
      Set(manifest.environments).isSubset(of: ["space", "orbital-station"]),
      (1...64).contains(manifest.mission.title.count),
      (1...12000).contains(manifest.mission.briefing.count),
      (1...64).contains(manifest.mission.milestones.count),
      manifest.mission.milestones.allSatisfy({ !$0.isEmpty && $0.count <= 256 }),
      manifest.capabilities.contains("script-lua-v1"),
      Set(manifest.capabilities).count == manifest.capabilities.count,
      manifest.capabilities.allSatisfy(PackValidation.identifier),
      (1...64).contains(manifest.handlers.count),
      Set(manifest.handlers.map(\.event)).count == manifest.handlers.count,
      manifest.handlers.allSatisfy({
        ScriptCapabilities.events.contains($0.event)
          && $0.function.range(of: "^[A-Za-z_][A-Za-z0-9_]{0,79}$", options: .regularExpression)
            != nil
      }),
      (manifest.dialogs?.count ?? 0) <= 64,
      Set((manifest.dialogs ?? []).map(\.id)).count == (manifest.dialogs?.count ?? 0),
      (manifest.dialogs ?? []).allSatisfy({
        PackValidation.identifier($0.id) && (1...12000).contains($0.text.count)
      }),
      (manifest.dependencies?.count ?? 0) <= 32,
      (manifest.dependencies ?? []).allSatisfy({ dependency in
        let parts = dependency.split(separator: "@", omittingEmptySubsequences: false)
        return parts.count == 2 && PackValidation.identifier(String(parts[0]))
          && PackValidation.version(String(parts[1]))
      })
    else {
      throw MissionPackError(
        "Invalid script manifest, scope, identity, handler or resource declarations.")
    }
    let nativeEvents = Set([
      "encounter.admitted", "encounter.pending", "actor.destroyed", "actor.removed",
    ])
    guard
      !manifest.handlers.contains(where: { nativeEvents.contains($0.event) })
        || manifest.capabilities.contains("classic-encounters-v2")
        || manifest.capabilities.contains("profiled-encounters-v2")
    else {
      throw MissionPackError(
        "Native actor events require the declared classic encounter capability.")
    }
    let encounters = manifest.encounters ?? []
    guard encounters.count <= 64, Set(encounters.map(\.id)).count == encounters.count,
      encounters.allSatisfy(\.valid), encounters.reduce(0, { $0 + $1.actors.count }) <= 128,
      Set(manifest.mission.requiredDestructionEncounters ?? []).isSubset(
        of: Set(encounters.map(\.id))),
      encounters.allSatisfy({ encounter in
        if encounter.profile == "classic-local-freeze-v1" {
          return manifest.capabilities.contains("classic-encounters-v2")
        }
        return manifest.capabilities.contains("profiled-encounters-v2")
          && encounter.actors.allSatisfy { actor in
            (manifest.npcs ?? []).contains { $0.id == actor.npc }
          }
      })
    else {
      throw MissionPackError("Invalid encounter declarations or missing native classic capability.")
    }
    try validateNPCDeclarations(manifest)
    try validateWorldJobs(manifest)
    try validateChoices(manifest)
    try validateAnswers(manifest)
    try validateBooks(manifest)
    try validateProcurement(manifest)
    try validateFreight(manifest)
    try validateCollections(manifest)
    try validateFinance(manifest)
    try validatePledge(manifest)
    try validateCourier(manifest)
    try validateProviderContract(manifest)
    try validateCampaignChildren(manifest)
    let requirements = manifest.receiptRequirements ?? []
    guard requirements.count <= 32, Set(requirements.map(\.id)).count == requirements.count,
      requirements.allSatisfy(\.valid),
      requirements.allSatisfy({ $0.definition != manifest.stateID }),
      requirements.isEmpty || manifest.capabilities.contains("completion-receipts-v2"),
      !requirements.contains(where: { $0.outcomes != nil })
        || manifest.capabilities.contains("compound-receipts-v2"),
      !manifest.handlers.contains(where: { $0.event == "dialogue.chosen" })
        || manifest.capabilities.contains("exclusive-choices-v2")
        || manifest.capabilities.contains("dialogue-choices-v2"),
      !manifest.handlers.contains(where: { $0.event == "mission.receipted" })
        || manifest.capabilities.contains("completion-receipts-v2")
    else { throw MissionPackError("Invalid native completion receipt requirements.") }

    let modules = manifest.modules ?? []
    let resourcePaths =
      [manifest.module] + modules.map(\.path) + (manifest.models ?? []).map(\.path)
    guard modules.count <= 16, modules.allSatisfy(\.valid),
      Set(modules.map(\.id)).count == modules.count,
      Set(resourcePaths).count == resourcePaths.count,
      modules.isEmpty || manifest.capabilities.contains("pack-modules-v2"),
      manifest.handlers.count + (manifest.board == nil ? 0 : 1) <= 64
    else { throw MissionPackError("Invalid, duplicate or unsupported pack module declarations.") }
    let parties = manifest.passengerParties ?? []
    guard
      !manifest.handlers.contains(where: {
        [
          "ship.changed", "equipment.changed", "gear.consumed", "equipment.issued",
          "equipment.returned", "equipment.released",
        ].contains($0.event)
      })
        || manifest.capabilities.contains("owned-equipment-v2")
    else { throw MissionPackError("Equipment events require owned-equipment-v2.") }
    let gear = manifest.equipment ?? []
    if let board = manifest.board {
      guard board.valid, manifest.capabilities.contains("contracts-basic-v2"),
        manifest.capabilities.contains("local-flight-clocks-v2"),
        board.clock == .local || board.clock == .flight
          || board.clock == .calendar && manifest.capabilities.contains("calendar-clocks-v2")
          || board.clock == .missionCalendar
            && (manifest.courier != nil || manifest.procurement != nil || manifest.freight != nil)
          || manifest.capabilities.contains("world-clocks-v1")
      else {
        throw MissionPackError("Invalid contract board or missing clock/contract capability.")
      }
    }
    guard gear.count <= 64, Set(gear.map(\.id)).count == gear.count,
      gear.allSatisfy(\.valid), gear.reduce(0, { $0 + $1.quantity }) <= 128,
      Set(manifest.mission.requiredEquipmentReturns ?? []).isSubset(of: Set(gear.map(\.id))),
      gear.isEmpty || manifest.capabilities.contains("owned-equipment-v2")
    else { throw MissionPackError("Invalid equipment declaration or missing owned-equipment-v2.") }
    guard parties.count <= 64, Set(parties.map(\.id)).count == parties.count,
      parties.allSatisfy(\.valid), parties.reduce(0, { $0 + $1.names.count }) <= 128,
      Set(manifest.mission.requiredPassengerParties ?? []).isSubset(of: Set(parties.map(\.id))),
      parties.isEmpty || manifest.capabilities.contains("charter-passengers-v2")
    else { throw MissionPackError("Invalid passenger parties or missing charter capability.") }
    if let trial = manifest.trial {
      guard trial.valid, manifest.capabilities.contains("gallery-basic-v2"),
        trial.offer == nil || manifest.board != nil
      else {
        throw MissionPackError("Invalid trial loadout or missing basic Gallery capability.")
      }
    }
    try path(manifest.module)
    guard manifest.module.hasSuffix(".lua"), manifest.module != "manifest.toml" else {
      throw MissionPackError("Declare a pack-local .lua module.")
    }
  }
  static func path(_ path: String) throws {
    let parts = path.split(separator: "/", omittingEmptySubsequences: false)
    guard !path.hasPrefix("/"), !parts.isEmpty, parts.count <= 8,
      parts.allSatisfy({
        $0.range(of: "^[A-Za-z0-9_-][A-Za-z0-9_.-]{0,79}$", options: .regularExpression) != nil
      })
    else {
      throw MissionPackError("Pack resources must use canonical relative paths.")
    }
  }
  static func readFile(_ path: String, in directory: URL) throws -> Data {
    try Self.path(path)
    var location = directory
    for component in path.split(separator: "/") {
      location.appendPathComponent(String(component))
      let properties = try location.resourceValues(forKeys: [.isSymbolicLinkKey])
      guard properties.isSymbolicLink != true else {
        throw MissionPackError("Pack resource links are not allowed.")
      }
    }
    let properties = try location.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
    guard properties.isRegularFile == true, (properties.fileSize ?? Int.max) <= 262144 else {
      throw MissionPackError("Each mission resource must be a regular file no larger than 256 KiB.")
    }
    let data = try Data(contentsOf: location)
    guard data.count <= 262144 else {
      throw MissionPackError("Mission resource changed or exceeds 256 KiB.")
    }
    return data
  }
  public static func install(_ pack: ScriptPack, directory: URL) throws -> URL {
    let destination = directory.appendingPathComponent(
      pack.manifest.id + "@" + pack.manifest.version + "-" + pack.digest, isDirectory: true)
    if FileManager.default.fileExists(atPath: destination.path) {
      guard try read(destination).digest == pack.digest else {
        throw MissionPackError("Installed content has changed; restore its original bytes.")
      }
      return destination
    }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let installedNames = try FileManager.default.contentsOfDirectory(atPath: directory.path).filter
    { !$0.hasPrefix(".") }
    guard installedNames.count < 128 else {
      throw MissionPackError(
        "The mission library is full. Keep versions that saved commanders need before installing another."
      )
    }
    let staging = directory.appendingPathComponent(".install-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: staging) }
    try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: false)
    try pack.manifestBytes.write(to: staging.appendingPathComponent("manifest.toml"))
    let module = staging.appendingPathComponent(pack.manifest.module)
    try FileManager.default.createDirectory(
      at: module.deletingLastPathComponent(), withIntermediateDirectories: true)
    try (pack.entryBytes ?? pack.source).write(to: module)
    for (path, bytes) in pack.resourceBytes {
      try Self.path(path)
      let target = staging.appendingPathComponent(path)
      try FileManager.default.createDirectory(
        at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
      try bytes.write(to: target)
    }
    guard try read(staging).digest == pack.digest else {
      throw MissionPackError("Installed mission failed content verification.")
    }
    try FileManager.default.moveItem(at: staging, to: destination)
    return destination
  }
  static func installed(directory: URL) -> (packs: [ScriptPack], errors: [String]) {
    guard FileManager.default.fileExists(atPath: directory.path) else { return ([], []) }
    do {
      let urls = try FileManager.default.contentsOfDirectory(
        at: directory, includingPropertiesForKeys: nil
      )
      .filter { !$0.lastPathComponent.hasPrefix(".") }.sorted {
        $0.lastPathComponent < $1.lastPathComponent
      }
      guard urls.count <= 128 else {
        throw MissionPackError("At most 128 script pack versions may be installed.")
      }
      var packs: [ScriptPack] = []
      var errors: [String] = []
      for url in urls {
        do {
          let pack = try read(url)
          if !packs.contains(where: { $0.digest == pack.digest }) { packs.append(pack) }
        } catch {
          errors.append(url.lastPathComponent + ": " + error.localizedDescription)
        }
      }
      return (packs, errors)
    } catch { return ([], [error.localizedDescription]) }
  }
}
