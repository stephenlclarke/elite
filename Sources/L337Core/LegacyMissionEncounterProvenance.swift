import Foundation

/// Historical identity facts minted only after a complete versioned save has validated.
/// Exact prepared bodies freeze the imported condition, not a new source of scene addresses.
struct LegacyMissionEncounterProvenance: Codable, Sendable, Equatable {
  static let storageKey = CodingUserInfoKey(rawValue: "elite.legacy-encounter-provenance")!
  let sourceSchema: Int
  let instanceID: UUID
  let definition: String
  let version: String
  let digest: String
  let encounterID: String
  let galaxy: Int
  let system: Int
  private(set) var actors: [String: LegacyMissionActorProvenance]

  private init(schema: Int, owner: ScriptInstance, encounter: ScriptOwnedEncounter) {
    sourceSchema = schema
    instanceID = owner.id
    definition = owner.definition
    version = owner.version
    digest = owner.digest
    encounterID = encounter.id
    galaxy = encounter.galaxy
    system = encounter.system
    actors = encounter.actors.mapValues {
      .init(actor: $0, prepared: !encounter.admitted)
    }
  }

  /// The store calls this only after joining and validating every historical chunk.
  static func importValidated(
    schema: Int, owner: ScriptInstance, encounter: ScriptOwnedEncounter
  ) throws -> Self {
    guard (2...11).contains(schema), encounter.legacyProvenance == nil,
      encounter.valid, owner.ownedEncounters[encounter.id] == encounter
    else { throw SaveError.invalidCommander }
    let result = Self(schema: schema, owner: owner, encounter: encounter)
    guard result.matches(owner: owner, encounter: encounter) else {
      throw SaveError.invalidCommander
    }
    return result
  }

  func matches(owner: ScriptInstance, encounter: ScriptOwnedEncounter) -> Bool {
    guard (2...11).contains(sourceSchema), instanceID == owner.id,
      definition == owner.definition, version == owner.version, digest == owner.digest,
      encounterID == encounter.id, galaxy == encounter.galaxy, system == encounter.system,
      (1...128).contains(actors.count), Set(actors.keys) == Set(encounter.actors.keys)
    else { return false }
    return actors.allSatisfy { alias, lineage in
      guard let actor = encounter.actors[alias], actor.alias == alias,
        lineage.identity == actor.identity, lineage.components.count <= 32,
        lineage.components == (actor.body.scriptNPC?.components.mapValues(\.identity) ?? [:])
      else { return false }
      return encounter.admitted ? lineage.prepared == nil : lineage.prepared == actor
    }
  }

  /// Only the genuine prepared admission patch drops its now-unneeded frozen condition.
  func afterAdmission() -> Self {
    var result = self
    result.actors = actors.mapValues { $0.afterAdmission() }
    return result
  }

  private enum CodingKeys: String, CodingKey {
    case sourceSchema, instanceID, definition, version, digest, encounterID, galaxy, system, actors
  }

  init(from decoder: any Decoder) throws {
    // A raw Commander decoder cannot acquire a versioned-save migration receipt.
    guard decoder.userInfo[Self.storageKey] as? Bool == true else {
      throw SaveError.invalidCommander
    }
    let values = try decoder.container(keyedBy: CodingKeys.self)
    sourceSchema = try values.decode(Int.self, forKey: .sourceSchema)
    instanceID = try values.decode(UUID.self, forKey: .instanceID)
    definition = try values.decode(String.self, forKey: .definition)
    version = try values.decode(String.self, forKey: .version)
    digest = try values.decode(String.self, forKey: .digest)
    encounterID = try values.decode(String.self, forKey: .encounterID)
    galaxy = try values.decode(Int.self, forKey: .galaxy)
    system = try values.decode(Int.self, forKey: .system)
    guard (2...11).contains(sourceSchema), definition.split(separator: "/").count == 2,
      PackValidation.version(version), PackValidation.localID(encounterID),
      digest.utf8.count == 64,
      digest.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
      (0..<8).contains(galaxy), (0...256).contains(system)
    else { throw SaveError.invalidCommander }
    let records = try values.nestedContainer(keyedBy: LegacyMissionStorageKey.self, forKey: .actors)
    guard (1...128).contains(records.allKeys.count) else { throw SaveError.invalidCommander }
    actors = [:]
    for key in records.allKeys {
      guard PackValidation.localID(key.stringValue) else { throw SaveError.invalidCommander }
      actors[key.stringValue] = try records.decode(LegacyMissionActorProvenance.self, forKey: key)
    }
  }
}

struct LegacyMissionActorProvenance: Codable, Sendable, Equatable {
  let identity: UUID
  let components: [String: UUID]
  private(set) var prepared: ScriptOwnedActor?

  fileprivate init(actor: ScriptOwnedActor, prepared: Bool) {
    identity = actor.identity
    components = actor.body.scriptNPC?.components.mapValues(\.identity) ?? [:]
    self.prepared = prepared ? actor : nil
  }

  fileprivate func afterAdmission() -> Self {
    var result = self
    result.prepared = nil
    return result
  }

  private enum CodingKeys: String, CodingKey { case identity, components, prepared }
  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    identity = try values.decode(UUID.self, forKey: .identity)
    let records = try values.nestedContainer(
      keyedBy: LegacyMissionStorageKey.self, forKey: .components)
    guard records.allKeys.count <= 32 else { throw SaveError.invalidCommander }
    components = try records.allKeys.reduce(into: [:]) { result, key in
      guard PackValidation.localID(key.stringValue) else { throw SaveError.invalidCommander }
      result[key.stringValue] = try records.decode(UUID.self, forKey: key)
    }
    if values.contains(.prepared), try !values.decodeNil(forKey: .prepared) {
      let snapshot = try values.nestedContainer(
        keyedBy: LegacyMissionStorageKey.self, forKey: .prepared)
      let body = try snapshot.nestedContainer(
        keyedBy: LegacyMissionStorageKey.self, forKey: .init("body"))
      let npcKey = LegacyMissionStorageKey("scriptNPC")
      if body.contains(npcKey), try !body.decodeNil(forKey: npcKey) {
        let npc = try body.nestedContainer(keyedBy: LegacyMissionStorageKey.self, forKey: npcKey)
        let parts = try npc.nestedContainer(
          keyedBy: LegacyMissionStorageKey.self, forKey: .init("components"))
        guard parts.allKeys.count <= 32 else { throw SaveError.invalidCommander }
      }
      prepared = try values.decode(ScriptOwnedActor.self, forKey: .prepared)
    } else {
      prepared = nil
    }
  }
}

private struct LegacyMissionStorageKey: CodingKey {
  let stringValue: String
  var intValue: Int? { nil }
  init(_ value: String) { stringValue = value }
  init?(stringValue: String) { self.init(stringValue) }
  init?(intValue: Int) { return nil }
}
