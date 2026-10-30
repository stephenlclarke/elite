import Foundation
import Testing

@testable import L337Core

/// These are policy/codec inputs; only native observers supply live actor evidence.
struct NativeFleetDiscoveryUnitTests {
  private func ship(
    _ predicate: (ShipCatalogueMetadata) -> Bool
  ) throws -> CatalogueShip {
    try #require(
      ShipCatalogue.all.first {
        $0.originalDefinition != nil && $0.catalogue.discoveryEligible && predicate($0.catalogue)
      })
  }
  private func proof(
    ship: String, kind: FleetDiscoveryKind, owner: UUID,
    time: Double = 12, killerIsPlayer: Bool = true
  ) -> FleetDiscoveryEvidence {
    let system = SystemIdentity(galaxy: 0, system: 7)
    let player = ActorIdentity(system: system, visit: 2, entity: 0)
    let actor = ActorIdentity(system: system, visit: 2, entity: 2)
    return .init(
      owner: owner, ship: ship, kind: kind, actor: actor, player: player,
      physicalTime: time,
      death: kind == .playerDestruction
        ? .init(
          victim: actor,
          owner: killerIsPlayer ? player : .init(system: system, visit: 2, entity: 3),
          lawful: true, bountyTenths: 0) : nil,
      mainDock: nil, secondaryDock: nil)
  }

  @Test func encounterAndIdentificationNeverGrantBlueprintWithoutPlayerDestruction() throws {
    let target = try ship {
      $0.collectionMilestone == .blueprintAndFabrication
        && $0.purchasePolicy == .blueprintFabrication && $0.playerFlyable && $0.access == .normal
    }
    let owner = UUID()
    var state = NativeFleetDiscovery(owner: owner)
    try state.record(proof(ship: target.id, kind: .encounter, owner: owner))
    #expect(state.entries[target.id]?.status == "Encountered")
    #expect(state.entries[target.id]?.blueprintEarned == false && state.identifiedTypes == 0)
    try state.record(proof(ship: target.id, kind: .identification, owner: owner, time: 13))
    #expect(state.entries[target.id]?.status == "Identified" && state.identifiedTypes == 1)
    try state.record(proof(ship: target.id, kind: .playerDestruction, owner: owner, time: 14))
    #expect(state.valid && state.entries[target.id]?.blueprintEarned == true)
    let first = state
    try state.record(proof(ship: target.id, kind: .playerDestruction, owner: owner, time: 15))
    #expect(state == first)
    #expect(state.readout(for: target.id).contains("First encounter: galaxy 1, system 7"))
  }

  @Test func npcKillsForeignOwnersUnknownTypesAndBackdatedEvidenceRefuseAtomically() throws {
    let target = try ship { $0.objectKind == .ship && !$0.isCapital }
    let owner = UUID()
    var state = NativeFleetDiscovery(owner: owner)
    try state.record(proof(ship: target.id, kind: .encounter, owner: owner))
    let before = state
    for evidence in [
      proof(ship: target.id, kind: .playerDestruction, owner: owner, killerIsPlayer: false),
      proof(ship: target.id, kind: .identification, owner: UUID()),
      proof(ship: "SH999", kind: .encounter, owner: owner),
      proof(ship: target.id, kind: .identification, owner: owner, time: 11),
    ] {
      #expect(throws: (any Error).self) { try state.record(evidence) }
      #expect(state == before)
    }
    #expect(state.entries[target.id]?.milestone == nil)
    #expect(state.readout(for: "SH999") == ["Collection: unknown; no native encounter recorded"])
  }

  @Test func stationCollectionNeedsActualDockingEvidenceAndCannotCreateABlueprint() throws {
    let target = try ship {
      $0.collectionMilestone == .docking
        && ($0.objectKind == .station || $0.capitalSubtype == .station)
    }
    let owner = UUID()
    var state = NativeFleetDiscovery(owner: owner)
    let encounter = proof(ship: target.id, kind: .encounter, owner: owner)
    try state.record(encounter)
    #expect(throws: (any Error).self) {
      try state.record(proof(ship: target.id, kind: .playerDestruction, owner: owner))
    }
    let station = NativeMainStationIdentity(
      world: owner, system: encounter.actor.system,
      resource: Game.worldResourceIdentity("main-station-v1:main-orbital:0:7"))
    let actor = ActorIdentity(system: station.system, visit: 2, entity: 1)
    let dock = NativeMainStationDockReceipt(
      station: station, actor: actor,
      commanderOwner: owner, sequence: 1, calendarSeconds: 0)
    try state.record(
      .init(
        owner: owner, ship: target.id, kind: .stationDocking, actor: actor,
        player: encounter.player, physicalTime: 13, death: nil, mainDock: dock, secondaryDock: nil))
    #expect(state.valid && state.entries[target.id]?.milestone?.kind == .stationDocking)
    #expect(state.entries[target.id]?.blueprintEarned == false)
  }

  @Test func nonstationCapitalDestructionCompletesItsOwnMilestoneWithoutPurchaseRights() throws {
    let target = try ship {
      $0.isCapital && $0.capitalSubtype == .vessel
        && $0.collectionMilestone == .destruction && $0.purchasePolicy == .never
    }
    let owner = UUID()
    var state = NativeFleetDiscovery(owner: owner)
    try state.record(proof(ship: target.id, kind: .playerDestruction, owner: owner))
    #expect(state.entries[target.id]?.status == "Collection milestone recorded")
    #expect(state.entries[target.id]?.blueprintEarned == false)
  }

  @Test(arguments: [false, true])
  func strictDiscoverySchemaPreservesLowerFeaturesAndRejectsNestedUnknownFields(alien: Bool) throws
  {
    let target = try ship { $0.objectKind == .ship && !$0.isCapital }
    let owner = UUID()
    var state = NativeFleetDiscovery(owner: owner)
    try state.record(proof(ship: target.id, kind: .identification, owner: owner))
    let leaf = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
    func bytes(_ leaf: [String: Any]) throws -> Data {
      try JSONSerialization.data(withJSONObject: ["savedFleetDiscovery": leaf])
    }
    let schema = alien ? 62 : 61
    try ScriptSaveJSONPreflight.validateRepairLoopFields(
      try bytes(leaf), part: .missions, schema: schema)
    #expect(throws: (any Error).self) {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(
        try bytes(leaf), part: .missions, schema: schema - 2)
    }
    #expect(throws: (any Error).self) {
      try NativeFleetDiscoverySave.validateFields(try bytes(leaf), part: .contracts, schema: schema)
    }
    var unknown = leaf
    unknown["grantAllBlueprints"] = true
    #expect(throws: (any Error).self) {
      try NativeFleetDiscoverySave.validateFields(
        try bytes(unknown), part: .missions, schema: schema)
    }
    var nested = leaf
    var entries = try #require(nested["entries"] as? [String: Any])
    var entry = try #require(entries[target.id] as? [String: Any])
    entry["invented"] = true
    entries[target.id] = entry
    nested["entries"] = entries
    #expect(throws: (any Error).self) {
      try NativeFleetDiscoverySave.validateFields(
        try bytes(nested), part: .missions, schema: schema)
    }
    #expect(
      try JSONDecoder().decode(NativeFleetDiscovery.self, from: JSONEncoder().encode(state))
        == state)
    let tutorialSchema = NativeFleetDiscoverySave.lowerSchema(schema)
    #expect(tutorialSchema == (alien ? 60 : 59))
    #expect(NativeFlightReceptionSave.lowerSchema(tutorialSchema) == (alien ? 58 : 57))
    #expect(NativeFleetDiscoverySave.lowerSchema(nil) == nil)
    #expect(NativeFleetDiscoverySave.lowerSchema(53) == 53)
  }
}
