import Foundation
import Testing

@testable import EliteCore

private func inventoryActionDisplayGame() throws -> Game {
  var game = Game(executive: false)
  game.screen = .inventory
  game.commander.cargo[0] = 1
  var serial = 100
  try game.commander.initializeEquipment(
    owner: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
    hull: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, legacy: false
  ) {
    serial += 1
    return UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", serial))!
  }
  let inventory = try #require(game.commander.equipmentInventory)
  let node = try #require(EquipmentRuntimeCatalog.node(for: "Fuel Scoops"))
  let held = OwnedEquipmentItem(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000999")!,
    node: node, provenance: .grant("inventory display fixture"))
  game.commander.savedEquipmentInventory = try OwnedEquipmentInventory(
    owner: inventory.owner, activeHull: inventory.activeHull, revision: inventory.revision,
    items: inventory.items + [held])
  return game
}

private func inventoryActionDisplayRecoveredLot() throws -> SalvageLedger {
  var ledger = SalvageLedger(seed: 123)
  let section = SalvageSectionProfile(
    index: 0, kind: .computer, localPosition: .init(0, 0, 0), normal: .init(0, 0, 1),
    radius: 10, workSeconds: 1, structural: false,
    technologyDefinitionIDs: ["shield-technology"], sourceFaceIndex: 0)
  _ = ledger.advance(
    wreck: .init(system: .init(galaxy: 0, system: 7), site: 0, lineage: 1),
    section: section, pose: .init(), velocity: .init(0, 0, 0),
    angularVelocity: .init(0, 0, 0), tool: .cutter, elapsed: 1, operation: 1,
    conditions: .init(
      toolInstalled: true, inRange: true, aligned: true, lineOfSight: true,
      resourcesAvailable: true, ownershipAuthorized: true))
  let lot = try #require(ledger.pendingLots.first)
  var cargo = Array(repeating: 0, count: 17)
  let result = ledger.collect(
    lot: lot.identity, cargo: &cargo, freeTonnes: 20, apertureHalfExtents: .init(100, 100, 100),
    hasScoops: true, approachAllowed: true, protection: .init())
  #expect(result == .collected(lot))
  return ledger
}

struct InventoryActionDisplayTests {
  @Test func visibleButtonsRetainBuilderCommandsAndWrappedRowsAtCompactAndWideSizes() throws {
    var game = try inventoryActionDisplayGame()
    game.commander.salvageLedger = try inventoryActionDisplayRecoveredLot()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let before = try encoder.encode(game.commander)
    for (width, height) in [(512.0, 518.0), (1512.0, 982.0)] {
      let rows = game.inventoryInformationRows(width: width)
      #expect(
        rows.contains {
          $0.text == Commodity.all[0].name + ": 1 " + Commodity.all[0].unit
        })
      let layout = StationLayout(game: game, width: width, height: height, footer: 28)
      for offset in 0..<rows.count {
        game.informationScroll = offset
        game.inventoryActionSelection = offset + 1
        let window = ScrollWindow(count: rows.count, visible: layout.count, offset: offset)
        let visible = Array(rows.dropFirst(window.offset).prefix(layout.count))
        let frame = Display.information(game, width: width, height: height)
        let interaction = try #require(frame.inventoryInteraction)
        let actionable = visible.enumerated().filter { $0.element.preview?.command != nil }
        #expect(interaction.controls.count == actionable.count)
        #expect(interaction.selected == game.inventoryActionSelection)
        #expect(
          interaction.primary == interaction.selectedIndex.map { interaction.controls[$0].command })
        for (control, row) in zip(interaction.controls, actionable) {
          #expect(control.command == row.element.preview?.command)
          #expect(control.bounds.width == InventoryInteraction.actionWidth)
          #expect(control.bounds.maxX == layout.left + layout.width)
          #expect(control.bounds.y == 52 + Double(row.offset) * layout.row)
          #expect(control.bounds.maxY <= layout.bottom)
          let y = control.bounds.y + 4
          let itemLabel = try #require(frame.labels.first { $0.x == layout.left && $0.y == y })
          #expect(itemLabel.bounds.maxX <= control.bounds.x - InventoryInteraction.actionGap)
          let buttonLabel = try #require(
            frame.labels.first {
              $0.text == row.element.preview?.label && $0.y == y && $0.x >= control.bounds.x
            })
          #expect(buttonLabel.bounds.maxX <= control.bounds.maxX)
          #expect(
            interaction.command(at: .init(control.bounds.x + 1, control.bounds.y + 1))
              == control.command)
        }
        if let selected = interaction.selectedIndex {
          let bounds = interaction.controls[selected].bounds
          #expect(
            frame.labels.contains {
              $0.text == ">" && $0.x == bounds.x + 4 && $0.y == bounds.y + 4 && $0.ink == .cyan
            })
        }
        #expect(frame.labels.allSatisfy { $0.scale == GameTypography.scale })
        for (index, row) in visible.enumerated() {
          let y = 56 + Double(index) * layout.row
          let label = try #require(frame.labels.first { $0.x == layout.left && $0.y == y })
          #expect(label.text == row.text)
          #expect(label.scale == GameTypography.scale)
          #expect(label.bounds.maxX <= layout.left + layout.width)
          if row.preview?.command == nil {
            #expect(!interaction.controls.contains { $0.bounds.y + 4 == y })
          }
        }
      }
    }
    #expect(try encoder.encode(game.commander) == before)
    #expect(game.commander.equipmentPurchaseHistory?.paid.isEmpty == true)
  }

  @Test func realFitStoreAndRecoveredPreviewsExposeCustodyAndNativeUpgradeDetails() throws {
    var game = try inventoryActionDisplayGame()
    game.commander.salvageLedger = try inventoryActionDisplayRecoveredLot()
    let inventory = try #require(game.commander.equipmentInventory)
    let held = try #require(inventory.items.first { $0.location == nil })
    let laser = try #require(inventory.items.first { $0.location?.slot == .laser(.front) })
    let shield = try #require(inventory.items.first { $0.location?.slot == .shield })
    #expect(game.inventoryActionPreview(for: .equipment(held)).label == "Fit")
    #expect(game.inventoryActionPreview(for: .equipment(laser)).label == "Store")
    #expect(game.inventoryActionPreview(for: .equipment(shield)).command == nil)
    let lot = try #require(game.commander.salvageLedger.inventory.first)
    let preview = game.inventoryActionPreview(for: .recovered(lot))
    let command = try #require(preview.command)
    guard
      case .upgrade(_, let source, let axis, let slot, let before, let after, let grade) =
        command.action
    else {
      Issue.record("Recovered physical technology must offer an upgrade command")
      return
    }
    #expect(source == lot && slot == .shield)
    let quote = try game.commander.previewRecoveredUpgrade(
      lot: lot.identity, axis: axis, slot: slot)
    #expect(before == quote.progression.before && after == quote.progression.after)
    #expect(grade == quote.progression.resultingGrade)
    #expect(preview.label == "Fit now")
    #expect(preview.detail.contains(" units") && preview.detail.contains(" -> "))
    #expect(preview.extraDetails.contains { $0.hasPrefix("Resulting grade: ") })
    #expect(preview.extraDetails.contains { $0.contains("(actual / required)") })
    #expect(preview.extraDetails.contains { $0.contains(" / ") && $0.contains("units") })
    let rows = game.inventoryInformationRows(width: 512)
    #expect(rows.contains { $0.text.contains("Held - Granted") })
    #expect(!rows.contains { $0.text.contains("Purchased") })
    #expect(rows.filter { $0.preview?.command == command }.count == 1)
  }
}
