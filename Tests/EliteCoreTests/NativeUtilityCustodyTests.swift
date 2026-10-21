import Foundation
import Testing

@testable import EliteCore

/// Structural policy inputs only; these constructed receipts are never native service authority.
enum NativeUtilityPolicyFixture {
  static func held(owner: UUID = UUID()) -> NativeUtilityState {
    var state = NativeUtilityState(owner: owner)
    let receipt = NativeMainStationDockReceipt(
      station: state.source,
      actor: .init(system: state.source.system, visit: 1, entity: 1), commanderOwner: owner,
      sequence: 1, calendarSeconds: 0)
    state.consignments = [
      .init(
        id: state.consignmentID(0), originalUnits: state.units(0),
        hull: UUID(), source: .init(receipt), route: [7, 237], firstLegReach: 1000,
        fullTankReach: 1000, rewardTenths: 7200)
    ]
    state.revision = 2
    return state
  }
  static func installed(_ input: NativeUtilityState) -> NativeUtilityState {
    var state = input
    state.revision += 1
    let contact = NativeStationDockReceipt(
      station: state.target, lifecycleRevision: 1,
      dockingBinding: .init(
        actor: .init(system: state.target.system, visit: 2, entity: 2), bodyID: 1),
      sequence: 1, commanderOwner: state.owner)
    let job = state.consignments[0]
    state.consignments[0].installation = .init(
      operation: state.operation(job.id, stage: "install", revision: state.revision),
      component: state.component(0), engineer: state.engineer, socket: 0,
      contact: .init(contact), revision: state.revision)
    state.consignments[0].phase = .installed
    return state
  }
}

struct NativeUtilityCustodyTests {
  @Test func explicitWorldActivationOwnsEightMaterialsWithoutTargetDockAuthority() throws {
    let owner = UUID()
    let world = try NativeStationWorld(owner: owner)
    let target = try #require(
      world.ledger.records.first { NativeUtilityState.isTarget($0.identity) })
    let utility = try #require(target.utility)
    #expect(utility.owner == owner && utility.valid && utility.materials.count == 8)
    #expect(
      Set(utility.materials).count == 8 && Set(utility.units(0)).isDisjoint(with: utility.units(1)))
    #expect(utility.consignments.isEmpty && utility.heldTonnes == 0 && utility.rechargeBonus == 0)
    #expect(target.binding == nil && target.tombstone == nil && world.ledger.currentDock == nil)
    #expect(world.mainStations.isEmpty && world.currentMainDock == nil)
    let bytes = try JSONEncoder().encode(world)
    #expect(try JSONDecoder().decode(NativeStationWorld.self, from: bytes) == world)
  }

  @Test func heldMassAndInstalledOriginalsHaveExclusiveCustodyWithoutCommoditySubstitution() throws
  {
    let held = NativeUtilityPolicyFixture.held()
    try #require(held.valid)
    #expect(held.heldTonnes == 4 && held.installedCount == 0)
    var world = try NativeStationWorld(owner: held.owner)
    try world.ledger.replaceUtility(held)
    var game = Game(executive: false)
    game.commander.nativeStations = world
    game.commander.cargo[0] = 3
    game.commander.unlimitedCargo = true
    #expect(game.commander.checkedCargoTonnes == 7)
    let installed = NativeUtilityPolicyFixture.installed(held)
    #expect(installed.valid && installed.heldTonnes == 0 && installed.rechargeBonus == 10)
    #expect(installed.consignments[0].originalUnits == held.consignments[0].originalUnits)
    var substitute = installed
    substitute.consignments[0] = NativeUtilityConsignment(
      id: held.consignmentID(0),
      originalUnits: [UUID(), UUID(), UUID(), UUID()], hull: held.consignments[0].hull,
      source: held.consignments[0].source, route: [7, 237], firstLegReach: 1000,
      fullTankReach: 1000, rewardTenths: 7200)
    #expect(!substitute.valid)
    #expect(throws: (any Error).self) { try world.ledger.replaceUtility(substitute) }
    #expect(
      world.ledger.records.first { NativeUtilityState.isTarget($0.identity) }?.utility == held)
  }

  @Test(arguments: [
    "missingMaterials", "extraField", "oversizedAttempts", "duplicateMaterial",
    "substituteUnit", "wrongReward", "missingInstallation", "foreignEngineer", "staleRevision",
    "foreignOwner", "invalidRoute", "invalidSource", "oversizedMaterials", "oversizedUnits",
    "unjoinedReception",
  ])
  func strictCurrentUtilitySchemaRejectsUnjoinedOrInventedClaims(fault: String) throws {
    let state = NativeUtilityPolicyFixture.installed(NativeUtilityPolicyFixture.held())
    try #require(state.valid)
    let bytes = try JSONEncoder().encode(state)
    var root = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    var jobs = try #require(root["consignments"] as? [[String: Any]])
    switch fault {
    case "missingMaterials": root.removeValue(forKey: "materials")
    case "extraField": root["rewardPaid"] = true
    case "oversizedAttempts": root["consignments"] = [jobs[0], jobs[0], jobs[0]]
    case "duplicateMaterial":
      var materials = try #require(root["materials"] as? [String])
      materials[1] = materials[0]
      root["materials"] = materials
    case "substituteUnit":
      jobs[0]["originalUnits"] = [
        UUID().uuidString, UUID().uuidString, UUID().uuidString, UUID().uuidString,
      ]
    case "wrongReward": jobs[0]["rewardTenths"] = 6100
    case "missingInstallation": jobs[0].removeValue(forKey: "installation")
    case "foreignEngineer":
      var installation = try #require(jobs[0]["installation"] as? [String: Any])
      installation["engineer"] = UUID().uuidString
      jobs[0]["installation"] = installation
    case "staleRevision": root["revision"] = 2
    case "foreignOwner": root["owner"] = UUID().uuidString
    case "invalidRoute":
      jobs[0]["route"] = [7, 7, 237]
      jobs[0]["rewardTenths"] = 8300
    case "invalidSource":
      var source = try #require(jobs[0]["source"] as? [String: Any])
      source["sequence"] = 0
      jobs[0]["source"] = source
    case "oversizedMaterials":
      root["materials"] = state.materials.map(\.uuidString) + [UUID().uuidString]
    case "oversizedUnits":
      jobs[0]["originalUnits"] =
        state.consignments[0].originalUnits.map(\.uuidString) + [UUID().uuidString]
    case "unjoinedReception":
      let installed = try #require(jobs[0]["installation"] as? [String: Any])
      root["revision"] = 4
      jobs[0]["phase"] = "received"
      jobs[0]["reception"] = [
        "operation": state.operation(state.consignments[0].id, stage: "receive", revision: 4)
          .uuidString,
        "installation": UUID().uuidString, "engineer": state.engineer.uuidString,
        "contact": installed["contact"]!, "revision": 4,
      ]
    default: Issue.record("Unknown malformed-input case")
    }
    if fault != "oversizedAttempts" { root["consignments"] = jobs }
    let corrupt = try JSONSerialization.data(withJSONObject: root)
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(NativeUtilityState.self, from: corrupt)
    }
    #expect(try JSONDecoder().decode(NativeUtilityState.self, from: bytes) == state)
  }

  @Test func targetRequiresUtilityStateAndOtherStationsCannotClaimIt() throws {
    let world = try NativeStationWorld(owner: UUID())
    let target = try #require(
      world.ledger.records.first { NativeUtilityState.isTarget($0.identity) })
    let other = try #require(
      world.ledger.records.first { !NativeUtilityState.isTarget($0.identity) })
    var missing = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(target)) as? [String: Any])
    let utility = try #require(missing.removeValue(forKey: "utility"))
    var foreign = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(other)) as? [String: Any])
    foreign["utility"] = utility
    for object in [missing, foreign] {
      let bytes = try JSONSerialization.data(withJSONObject: object)
      #expect(throws: (any Error).self) {
        try JSONDecoder().decode(NativeStationRecord.self, from: bytes)
      }
    }
  }
}
