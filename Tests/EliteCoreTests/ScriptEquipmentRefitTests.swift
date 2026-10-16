import Foundation
import Testing

@testable import EliteCore

struct ScriptEquipmentRefitTests {
  @Test(arguments: ["Missile", FuelStorage.equipmentName])
  func heldRoundAndTankRefitUseActualFreeSlotsWithoutStoringPersonalOriginals(name: String) throws {
    let fixture = try GearScriptFixture(
      name: name, accepted: "{op='gear.issue',id='issue',gear='kit',fit=false}",
      contact: "{op='gear.refit',id='refit',gear='kit',index=0}")
    defer { fixture.clean() }
    var game = Game(executive: false)
    game.scriptPacks = [fixture.pack]
    if name == FuelStorage.equipmentName {
      try game.commander.grantEquipment(
        name, at: .fuelStorage(0), provenance: .grant("refit-personal-tank"))
    }
    let before = try #require(game.commander.equipmentInventory)
    let fuel = game.commander.fuel
    let id = try game.acceptScriptMission(fixture.pack)
    let issuedID = try #require(
      game.commander.scriptState.instances[id]?.gearIssues["kit"]?.items.first)
    #expect(game.commander.equipmentInventory?.items.first { $0.id == issuedID }?.location == nil)
    game.emitScriptEvent("contact.requested")
    let issued = try #require(game.commander.equipmentInventory?.items.first { $0.id == issuedID })
    #expect(game.commander.scriptState.instances[id]?.suspension == nil && game.commander.valid)
    for personal in before.items {
      #expect(game.commander.equipmentInventory?.items.first { $0.id == personal.id } == personal)
    }
    #expect(
      game.commander.scriptState.instances[id]?.gearIssues["kit"]?.displacements?.isEmpty == true)
    if name == "Missile" {
      let slot = try #require(issued.location?.slot)
      #expect(before.items.allSatisfy { $0.location?.slot != slot })
      if case .missilePylon = slot {} else { Issue.record("The round needs a real free pylon") }
    } else {
      #expect(issued.location?.slot == .fuelStorage(1))
      #expect(game.commander.fuelStorageUnits == 2 && game.commander.fuel == fuel)
    }
  }

  @Test func ordinaryOccupiedModuleRefitRefusesWithoutStoringThePersonalDevice() throws {
    let fixture = try GearScriptFixture(
      accepted: "{op='gear.issue',id='issue',gear='kit',fit=false}",
      contact: "{op='gear.refit',id='refit',gear='kit',index=0}")
    defer { fixture.clean() }
    var game = Game(executive: false)
    try game.commander.grantEquipment(
      "E.C.M. System", at: .utility(.ecm), provenance: .grant("personal-ecm"))
    game.scriptPacks = [fixture.pack]
    let id = try game.acceptScriptMission(fixture.pack)
    let before = try #require(game.commander.equipmentInventory)
    let personal = try #require(game.commander.fittedEquipment(at: .utility(.ecm)))
    let issued = try #require(
      game.commander.scriptState.instances[id]?.gearIssues["kit"]?.items.first)
    game.emitScriptEvent("contact.requested")
    #expect(game.commander.equipmentInventory == before && game.commander.valid)
    #expect(game.commander.fittedEquipment(at: .utility(.ecm)) == personal)
    #expect(game.commander.equipmentInventory?.items.first { $0.id == issued }?.location == nil)
    #expect(game.commander.scriptState.instances[id]?.suspension != nil)
  }

  @Test func alreadyFittedLaserCannotBeMovedByRefitEvenToAFreeMount() throws {
    let fixture = try GearScriptFixture(
      name: "Beam Laser", contact: "{op='gear.refit',id='refit',gear='kit',index=0,mount='rear'}")
    defer { fixture.clean() }
    var game = try fixture.game()
    let id = try #require(game.commander.scriptState.instances.keys.first)
    let before = try #require(game.commander.equipmentInventory)
    let beam = try #require(game.commander.fittedEquipment(at: .laser(.front)))
    #expect(game.commander.fittedEquipment(at: .laser(.rear)) == nil)
    game.emitScriptEvent("contact.requested")
    #expect(game.commander.equipmentInventory == before && game.commander.valid)
    #expect(game.commander.fittedEquipment(at: .laser(.front)) == beam)
    #expect(game.commander.fittedEquipment(at: .laser(.rear)) == nil)
    #expect(game.commander.scriptState.instances[id]?.suspension != nil)
  }

  @Test func heldEnergyIssueCanReplaceOnlyTheActualIntrinsicFoundationAndRetainsItsIdentity() throws
  {
    let fixture = try GearScriptFixture(
      name: "Extra Energy Unit", accepted: "{op='gear.issue',id='issue',gear='kit',fit=false}",
      contact: "{op='gear.refit',id='refit',gear='kit',index=0}")
    defer { fixture.clean() }
    var game = try fixture.game()
    let id = try #require(game.commander.scriptState.instances.keys.first)
    let foundation = try #require(game.commander.fittedEquipment(at: .energy))
    try #require(EquipmentIssueTransactions.isIntrinsicFoundation(foundation))
    game.emitScriptEvent("contact.requested")
    #expect(game.commander.scriptState.instances[id]?.suspension == nil && game.commander.valid)
    #expect(
      game.commander.equipmentInventory?.items.first { $0.id == foundation.id }?.location == nil)
    let record = try #require(game.commander.scriptState.instances[id]?.gearIssues["kit"])
    #expect(game.commander.fittedEquipment(at: .energy)?.id == record.items.first)
    #expect(
      record.displacements == [
        .init(item: foundation.id, location: try #require(foundation.location))
      ])
  }
}
