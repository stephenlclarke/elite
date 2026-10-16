import Foundation
import Testing

@testable import EliteCore

private func ownershipDisplayGame(shipID: String = "SH023") throws -> Game {
  var game = Game(executive: false)
  game.screen = .equipment
  game.commander.shipID = shipID
  game.commander.credits = 1_000_000
  game.commander.system = try #require(game.systems.first { $0.technology >= 10 }?.id)
  var serial = 100
  try game.commander.initializeEquipment(
    owner: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
    hull: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, legacy: false
  ) {
    serial += 1
    return UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", serial))!
  }
  return game
}

private func ownershipDisplayBytes(_ commander: Commander) throws -> Data {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.sortedKeys]
  return try encoder.encode(commander)
}

struct EquipmentOwnershipDisplayTests {
  @Test func requirementsDescribeCashAndCanonicalPredecessorsWithoutCreatingOwnership() throws {
    var game = try ownershipDisplayGame()
    let basic = try #require(Equipment.all.first { $0.name == TargetingTier.basic.equipmentName })
    let military = try #require(
      Equipment.all.first { $0.name == TargetingTier.military.equipmentName })
    game.commander.credits = 0
    let before = try ownershipDisplayBytes(game.commander)
    for _ in 0..<3 {
      #expect(game.equipmentPurchaseRequirement(basic) == "Not enough cash")
      #expect(game.equipmentPurchaseRequirement(military) == "Buy " + basic.name + " first")
      game.selection = try #require(Equipment.all.firstIndex { $0.name == basic.name })
      let cash = Display.equipmentScreen(game, width: 768, height: 768)
      #expect(cash.labels.contains { $0.text.contains("Not enough cash") })
      game.selection = try #require(Equipment.all.firstIndex { $0.name == military.name })
      let prerequisite = Display.equipmentScreen(game, width: 768, height: 768)
      let node = try #require(EquipmentRuntimeCatalog.node(for: basic.name))
      let label = try #require(
        EquipmentRuntimeCatalog.graph.nodes.first { $0.id == node }?.displayName)
      #expect(prerequisite.labels.contains { $0.text.contains("Buy " + label + " first") })
    }
    #expect(try ownershipDisplayBytes(game.commander) == before)
  }

  @Test func heldGrantAndFittedStandardShowCustodyGradeAndOriginWithoutMutation() throws {
    var game = try ownershipDisplayGame()
    let inventory = try #require(game.commander.equipmentInventory)
    let node = try #require(EquipmentRuntimeCatalog.node(for: TargetingTier.basic.equipmentName))
    let held = OwnedEquipmentItem(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000999")!, node: node,
      provenance: .grant("display fixture"))
    game.commander.savedEquipmentInventory = try OwnedEquipmentInventory(
      owner: inventory.owner, activeHull: inventory.activeHull, revision: inventory.revision,
      items: inventory.items + [held])
    let before = try ownershipDisplayBytes(game.commander)
    game.selection = try #require(Equipment.all.firstIndex { $0.name == node.key })
    let heldFrame = Display.equipmentScreen(game, width: 768, height: 768)
    #expect(heldFrame.labels.contains { $0.text == "STORED" })
    #expect(heldFrame.labels.contains { $0.text.contains("Stored item owned.") })
    game.selection = try #require(
      Equipment.all.firstIndex { $0.name == NavigationTier.basic.equipmentName })
    let fittedFrame = Display.equipmentScreen(game, width: 768, height: 768)
    #expect(fittedFrame.labels.contains { $0.text == "FITTED" })
    #expect(fittedFrame.labels.contains { $0.text.contains("Fitted grade: Basic.") })
    game.screen = .inventory
    let rows = game.informationRows.map { $0.0 }
    #expect(rows.contains("Basic Shield"))
    #expect(rows.contains("  Held - Granted"))
    #expect(rows.contains("  Fitted shield - Standard"))
    #expect(!rows.contains("  Held - Purchased"))
    #expect(rows.contains("Recorded purchases: 0"))
    #expect(try ownershipDisplayBytes(game.commander) == before)
  }

  @Test func storedShieldDoesNotAppearFittedInCommanderStatus() throws {
    var game = try ownershipDisplayGame()
    let inventory = try #require(game.commander.equipmentInventory)
    let items = inventory.items.map { item in
      guard item.location?.slot == .shield else { return item }
      return OwnedEquipmentItem(
        id: item.id, node: item.node, provenance: item.provenance,
        component: item.component, location: nil, boundHull: item.boundHull)
    }
    game.commander.savedEquipmentInventory = try OwnedEquipmentInventory(
      owner: inventory.owner, activeHull: inventory.activeHull, revision: inventory.revision,
      items: items)
    game.screen = .status
    let before = try ownershipDisplayBytes(game.commander)
    let rows = game.informationRows.map { $0.0 }
    #expect(rows.contains { $0.hasPrefix("Shield: None -") })
    #expect(rows.contains("Mining: no module; core: none"))
    #expect(rows.contains("Salvage: no module; core: none"))
    #expect(try ownershipDisplayBytes(game.commander) == before)
  }

  @Test func combatCardsAndOptionalWorkToolKeepSelectionAndPricesReachableAtBothSizes() throws {
    let withTool = try #require(
      ShipCatalogue.all.first { $0.game?.workTools?.contains(.miningLaser) == true })
    let withoutTool = try #require(
      ShipCatalogue.all.first {
        $0.game != nil && $0.game?.workTools?.contains(.miningLaser) != true
      })
    for ship in [withTool, withoutTool] {
      var game = try ownershipDisplayGame(shipID: ship.id)
      let before = try ownershipDisplayBytes(game.commander)
      for (width, height) in [(512.0, 518.0), (768.0, 768.0)] {
        for index in EquipmentGroups.itemIndices {
          game.selection = index
          let layout = EquipmentLayout(game: game, width: width, height: height)
          let frame = Display.equipmentScreen(game, width: width, height: height)
          #expect(layout.mounts.count == 4)
          #expect(Set(layout.mounts.map(\.mount)) == Set(LaserMount.allCases))
          #expect((layout.workToolBounds != nil) == (ship.id == withTool.id))
          if let tool = layout.workToolBounds {
            #expect(tool.height == 44)
            #expect(layout.mounts.allSatisfy { $0.bounds.maxY + 8 <= tool.y })
            #expect(layout.buyingTop > tool.maxY)
            game.equipmentWorkTool = true
            let workFrame = Display.equipmentScreen(game, width: width, height: height)
            #expect(workFrame.labels.contains { $0.text == "Buying for: Mining work tool" })
            #expect(workFrame.labels.contains { $0.text == "Mining work tool" && $0.ink == .cyan })
            #expect(
              !workFrame.labels.contains { label in
                LaserMount.allCases.contains { $0.label == label.text } && label.ink == .cyan
              })
            game.equipmentWorkTool = false
          }
          let selected = try #require(frame.labels.first { $0.text == ">" })
          #expect(selected.x == layout.left + 14)
          #expect(selected.y >= layout.listTop)
          #expect(
            selected.bounds.maxY <= CockpitLayout(game: game, width: width, height: height)
              .dashboardTop - 82)
          #expect(selected.scale == layout.font)
          let prices = frame.labels.filter { $0.text.hasSuffix(" CR") }
          for price in prices {
            #expect(abs(price.bounds.maxX - (layout.left + layout.contentWidth)) < 0.0001)
            #expect(price.scale == layout.font)
          }
        }
      }
      #expect(try ownershipDisplayBytes(game.commander) == before)
    }
  }
}
