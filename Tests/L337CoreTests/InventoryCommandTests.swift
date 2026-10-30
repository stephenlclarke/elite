import Foundation
import Testing

@testable import L337Core

private func inventoryCommandGame() throws -> Game {
  var game = Game(executive: false)
  game.screen = .inventory
  try game.commander.prepareEquipment(legacy: false)
  try game.commander.grantEquipment(
    TargetingTier.military.equipmentName, at: .targetingCore, provenance: .grant("fixture"))
  try game.commander.grantEquipment(
    TargetingTier.basic.equipmentName, at: .targetingCore, provenance: .grant("fixture"))
  return game
}

struct InventoryCommandTests {
  @Test func backendAlsoRefusesARequiredSystemRemovalFromAMalformedControl() throws {
    var game = try inventoryCommandGame()
    let pulse = try #require(game.commander.fittedEquipment(at: .laser(.front)))
    let allowed = try #require(game.inventoryActionPreview(for: .equipment(pulse)).command)
    let shield = try #require(game.commander.fittedEquipment(at: .shield))
    let malformed = InventoryCommand(
      owner: allowed.owner, hull: allowed.hull, context: allowed.context, shipID: allowed.shipID,
      ownedRevision: allowed.ownedRevision, sourceRevision: nil, action: .store(shield))
    let before = game.commander
    let removed = game.performInventoryCommand(malformed)
    #expect(!removed && game.commander == before && game.commander.valid)
  }

  @Test func actualTypedRowsRemainPureAndNeverOfferRemovingRequiredShipSystems() throws {
    let game = try inventoryCommandGame()
    let before = game.commander
    let rows = game.inventoryInformationRows(width: 512)
    #expect(rows == game.inventoryInformationRows(width: 512))
    for slot in [ComponentFittingSlot.shield, .energy, .navigation] {
      let item = try #require(game.commander.fittedEquipment(at: slot))
      let preview = game.inventoryActionPreview(for: .equipment(item))
      #expect(preview.command == nil && preview.detail.contains("Required ship system"))
    }
    #expect(!rows.contains { $0.text.contains(game.commander.equipmentOwnerID!.uuidString) })
    #expect(
      game.commander == before && game.commander.equipmentPurchaseHistory?.paid.isEmpty == true)
  }

  @Test func anActualHeldDeviceCanFitAndStoreOnceWithoutCreatingPaidHistoryOrNewIdentities() throws
  {
    var game = try inventoryCommandGame()
    let held = try #require(
      game.commander.equipmentInventory?.items.first {
        $0.node.key == TargetingTier.basic.equipmentName && $0.location == nil
      })
    let ids = Set(game.commander.equipmentInventory!.items.map(\.id))
    let fit = try #require(game.inventoryActionPreview(for: .equipment(held)).command)
    let fitted = game.performInventoryCommand(fit)
    #expect(fitted && game.commander.fittedEquipment(at: .targetingCore)?.id == held.id)
    let beforeReplay = game.commander
    let repeated = game.performInventoryCommand(fit)
    #expect(!repeated && game.commander == beforeReplay)
    let installed = try #require(game.commander.fittedEquipment(at: .targetingCore))
    let store = try #require(game.inventoryActionPreview(for: .equipment(installed)).command)
    let stored = game.performInventoryCommand(store)
    #expect(stored && game.commander.targetingTier == nil)
    #expect(Set(game.commander.equipmentInventory!.items.map(\.id)) == ids)
    #expect(game.commander.equipmentPurchaseHistory?.paid.isEmpty == true)
  }

  @Test func recoveredActionUsesItsDisplayedStatisticsAndConsumesTheExactSource() throws {
    var game = try recoveredEquipmentGame("shield-technology")
    let lot = try #require(game.commander.salvageLedger.inventory.first)
    let preview = game.inventoryActionPreview(for: .recovered(lot))
    let command = try #require(preview.command)
    #expect(preview.detail.contains("255") && preview.detail.contains("units"))
    #expect(preview.extraDetails.contains { $0.hasPrefix("Resulting grade:") })
    #expect(!preview.detail.contains("frontShieldCapacity"))
    game.frontShield = game.commander.shieldCapacity / 2
    let accepted = game.performInventoryCommand(command)
    #expect(accepted && game.commander.salvageLedger.inventory.isEmpty)
    #expect(abs(game.frontShield / game.commander.shieldCapacity - 0.5) < 1e-10)
    let after = game.commander
    let second = game.performInventoryCommand(command)
    #expect(!second && game.commander == after)
  }

  @Test func loadAndScreenReturnRejectOldCommandsEvenWhenPersistentIdentitiesAndRevisionsMatch()
    async throws
  {
    let runtime = GameRuntime(game: try inventoryCommandGame())
    let shown = await runtime.snapshot()
    let item = try #require(shown.commander.fittedEquipment(at: .targetingCore))
    let command = try #require(shown.inventoryActionPreview(for: .equipment(item)).command)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    try await runtime.save(to: url)
    try await runtime.load(from: url, persistMigrations: false)
    await runtime.key("9")
    let restored = await runtime.snapshot()
    #expect(restored.commander.equipmentOwnerID == command.owner)
    #expect(restored.commander.hullInstanceID == command.hull)
    #expect(restored.commander.equipmentInventory?.revision == command.ownedRevision)
    #expect(restored.inventoryContextEpoch != command.context)
    let accepted = await runtime.inventoryCommand(command)
    #expect(!accepted)
    #expect(await runtime.snapshot().commander == restored.commander)
    let current = try #require(restored.inventoryActionPreview(for: .equipment(item)).command)
    await runtime.key("8")
    await runtime.key("9")
    let returned = await runtime.snapshot()
    let staleReturn = await runtime.inventoryCommand(current)
    #expect(!staleReturn && returned.inventoryContextEpoch != current.context)
    #expect(await runtime.snapshot().commander == returned.commander)
  }

  @Test func aDifferentActorCannotUseTheSameCommandersOldInteractionContext() async throws {
    let game = try inventoryCommandGame()
    let first = GameRuntime(game: game)
    let second = GameRuntime(game: game)
    let shown = await first.snapshot()
    let item = try #require(shown.commander.fittedEquipment(at: .targetingCore))
    let command = try #require(shown.inventoryActionPreview(for: .equipment(item)).command)
    let before = await second.snapshot()
    #expect(before.commander.equipmentInventory == shown.commander.equipmentInventory)
    let accepted = await second.inventoryCommand(command)
    #expect(!accepted && before.inventoryContextEpoch != shown.inventoryContextEpoch)
    #expect(await second.snapshot().commander == before.commander)
  }
}
