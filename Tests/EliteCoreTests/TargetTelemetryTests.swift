import Testing

@testable import EliteCore

private typealias TT = TargetTelemetry

private func telemetryFacts(
  cargo: [CommodityAmount]? = [], origin: TT.RouteFact? = nil,
  destination: TT.RouteFact? = nil, legal: LegalRecord? = nil, hostile: Bool = false,
  resources: TT.Resources? = nil
) -> TT.Facts {
  .init(
    cargo: cargo, origin: origin, destination: destination, legal: legal,
    hostile: hostile, resources: resources)
}

private func telemetryFields(
  _ facts: TT.Facts, tier: TargetingTier = .military, ship: Bool = true,
  discloseLegal: Bool = false
) -> [TargetField] {
  TT.fields(
    facts: facts, tier: tier, targetIsShip: ship, observerGalaxy: 0,
    discloseLegal: discloseLegal)
}

@Test func targetTelemetryDistinguishesEmptyUnknownAndNativeCargoUnitsWithoutTruncating() {
  #expect(TT.cargoManifest(nil) == "Unknown")
  #expect(TT.cargoManifest([]) == "None")
  #expect(TT.cargoManifest([.init(commodity: .food, quantity: 0)]) == "Unknown")
  let cargo: [CommodityAmount] = [
    .init(commodity: .food, quantity: 3), .init(commodity: .gold, quantity: 20),
    .init(commodity: .gemstones, quantity: 4),
  ]
  #expect(TT.cargoManifest(cargo) == "Food 3 t; Gold 20 kg; Gem-Stones 4 g")
  let full = CommodityIdentity.allCases.map { CommodityAmount(commodity: $0, quantity: 12) }
  let text = TT.cargoManifest(full)
  #expect(text.split(separator: ";").count == CommodityIdentity.allCases.count)
  #expect(text.contains("Alien Items 12 t"))
}

@Test func targetTelemetryUsesRouteOwnGalaxyPlughAndExplicitInferredProvenance() {
  for galaxy in [0, 7] {
    let recorded = TT.RouteFact(identity: .init(galaxy: galaxy, system: 7), provenance: .recorded)
    let suffix = galaxy == 0 ? "" : " (Galaxy 8)"
    #expect(
      TT.systemName(recorded, observerGalaxy: 0) == Universe.galaxy(number: galaxy)[7].name + suffix
    )
    let plugh = TT.RouteFact(
      identity: .init(galaxy: galaxy, system: Plugh.systemID), provenance: .inferredLocal)
    #expect(TT.systemName(plugh, observerGalaxy: 0) == "PLUGH" + suffix + " (inferred local)")
  }
  #expect(TT.systemName(nil, observerGalaxy: 0) == "Unknown")
  for identity in [
    SystemIdentity(galaxy: -1, system: 0), .init(galaxy: 8, system: 0),
    .init(galaxy: 0, system: -1), .init(galaxy: 0, system: 257),
  ] {
    #expect(
      TT.systemName(.init(identity: identity, provenance: .recorded), observerGalaxy: 0)
        == "Unknown")
  }
}

@Test func targetTelemetryGatesFactsByModuleAndTargetType() {
  let facts = telemetryFacts(
    cargo: [.init(commodity: .gold, quantity: 20)],
    origin: .init(identity: .init(galaxy: 1, system: 2), provenance: .recorded),
    legal: .init(value: 64), hostile: false,
    resources: .init(
      frontShield: 12, frontCapacity: 100, rearShield: 34, rearCapacity: 200,
      laserHeat: 56, heatCapacity: 255, fuelTenthsLY: 23, fuelCapacityTenthsLY: 70))
  for tier in TargetingTier.allCases {
    let fields = telemetryFields(facts, tier: tier)
    #expect(fields.contains { $0.label == "Cargo" } == (tier >= .pirate))
    #expect(fields.contains { $0.label == "Front shield" } == (tier == .military))
    #expect(!fields.contains { $0.label == "Legal status" })
    #expect(telemetryFields(facts, tier: tier, ship: false, discloseLegal: true).isEmpty)
    let legal = telemetryFields(facts, tier: tier, discloseLegal: true)
    #expect(legal.contains { $0.label == "Legal status" } == (tier >= .identification))
  }
  #expect(facts.attitude == "Neutral")
  #expect(telemetryFields(facts).first { $0.label == "Fuel" }?.value == "2.3 / 7.0 LY")
  #expect(telemetryFields(facts).first { $0.label == "Front shield" }?.value == "12.0 / 100.0")
}

@Test func targetTelemetryLegalRecordIsIndependentOfHostility() {
  for (value, expected) in [
    (0, "Clean"), (49, "Offender"), (50, "Fugitive"), (255, "Fugitive"), (256, "Unknown"),
  ] {
    let facts = telemetryFacts(legal: .init(value: value), hostile: true)
    #expect(facts.attitude == "Hostile")
    #expect(
      telemetryFields(facts, discloseLegal: true).first { $0.label == "Legal status" }?.value
        == expected)
  }
  #expect(
    telemetryFields(telemetryFacts(), discloseLegal: true).first { $0.label == "Legal status" }?
      .value == "Unknown")
}

@Test func targetTelemetryInvalidActualResourcesStayUnknownIndependently() {
  let unknown = telemetryFields(telemetryFacts(cargo: nil))
  #expect(unknown.allSatisfy { $0.value == "Unknown" })
  let invalid = TT.Resources(
    frontShield: .nan, frontCapacity: 100, rearShield: 30, rearCapacity: 20,
    laserHeat: -.infinity, heatCapacity: 255, fuelTenthsLY: 71, fuelCapacityTenthsLY: 70)
  #expect(
    telemetryFields(telemetryFacts(resources: invalid)).suffix(4).allSatisfy {
      $0.value == "Unknown"
    })
  let mixed = TT.Resources(
    frontShield: 0, frontCapacity: 0, rearShield: -1, rearCapacity: 20,
    laserHeat: 25, heatCapacity: 255, fuelTenthsLY: 0, fuelCapacityTenthsLY: -1)
  let fields = telemetryFields(telemetryFacts(resources: mixed))
  #expect(fields.first { $0.label == "Front shield" }?.value == "0.0 / 0.0")
  #expect(fields.first { $0.label == "Laser heat" }?.value == "25.0 / 255.0")
  #expect(fields.first { $0.label == "Fuel" }?.value == "Unknown")
}

@Test func targetTelemetryModelUsesActualCatalogueAndMissionOverrides() throws {
  let ship = try #require(ShipCatalogue.all.first { $0.name != Hull.cobra.modelName })
  #expect(
    TT.modelName(catalogueShipID: ship.id, missionName: nil, fallbackHull: .cobra) == ship.name)
  #expect(
    TT.modelName(catalogueShipID: ship.id, missionName: "Protected target", fallbackHull: .cobra)
      == "Protected target")
  #expect(
    TT.modelName(catalogueShipID: "missing", missionName: "", fallbackHull: .cobra)
      == Hull.cobra.modelName)
}

@Test func targetTelemetrySnapshotsFollowNPCManifestAndRouteWithoutPlayerInput() {
  var npc = NPCState(
    role: .trader, origin: .init(galaxy: 0, system: 7), destination: .init(galaxy: 0, system: 8))
  npc.ordinaryCargo = [.init(commodity: .gold, quantity: 20)]
  func facts() -> TT.Facts {
    telemetryFacts(
      cargo: npc.ordinaryCargo,
      origin: .init(identity: npc.origin, provenance: .recorded),
      destination: .init(identity: npc.destination, provenance: .recorded), legal: npc.legal)
  }
  let before = telemetryFields(facts(), tier: .pirate)
  npc.ordinaryCargo = [.init(commodity: .platinum, quantity: 5)]
  npc.destination = .init(galaxy: 1, system: 9)
  let after = telemetryFields(facts(), tier: .pirate)
  #expect(before.first { $0.label == "Cargo" }?.value == "Gold 20 kg")
  #expect(after.first { $0.label == "Cargo" }?.value == "Platinum 5 kg")
  #expect(before.first { $0.label == "Origin" } == after.first { $0.label == "Origin" })
  #expect(after.first { $0.label == "Destination" }?.value.contains("Galaxy 2") == true)
}
