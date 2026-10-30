import Foundation
import Testing

@testable import L337Core

private func recoveredArtefactAtPlugh(_ file: URL) async throws -> (GameRuntime, UUID) {
  let (initial, lot) = try nativeSalvageScoopFixture(
    definition: AlienMissileDefinition.recipe.requiredDefinitionID, system: Plugh.systemID)
  let recovery = GameRuntime(game: initial)
  try await recovery.save(to: file)
  var game = await recovery.advance(delta: 0.1)
  let held = try #require(game.commander.alienStorageState?.current.salvage.storedTechnology.first)
  #expect(held.value.item.identity == lot.identity)
  game.dock()
  game.launch()
  try #require(!game.docked && game.commander.valid)
  let runtime = try await dockAtActualPlughDoorway(game, file: file)
  await runtime.nativeCommand { $0.commander.credits = 100_000 }
  return (runtime, held.key)
}

func researchAlienSeeker(_ file: URL) async throws -> (GameRuntime, UUID) {
  let (runtime, source) = try await recoveredArtefactAtPlugh(file)
  let before = await runtime.snapshot()
  let command = try #require(before.inventoryActionPreview(for: .alienResearch(source)).command)
  let result = await runtime.equipmentTransaction(.inventory(command))
  try #require(result.applied)
  let game = await runtime.snapshot()
  let prototype = try #require(
    game.commander.alienStorageState?.current.salvage.missileResearch.first?.prototype)
  return (runtime, prototype)
}

func loadAlienRound(_ runtime: GameRuntime, id: UUID) async throws {
  let game = await runtime.snapshot()
  let item = try #require(game.commander.equipmentInventory?.items.first { $0.id == id })
  let command = try #require(game.inventoryActionPreview(for: .equipment(item)).command)
  let result = await runtime.equipmentTransaction(.inventory(command))
  try #require(result.applied)
}

struct AlienMissileServiceUnitTests {
  @Test func nativeArtefactResearchPaysOnceConsumesOriginalAndCreatesOneStoredPrototype()
    async throws
  {
    let folder = try nativeSalvageTestDirectory()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let (runtime, source) = try await recoveredArtefactAtPlugh(file)
    let before = await runtime.snapshot()
    let row = before.inventoryActionPreview(for: .alienResearch(source))
    let command = try #require(row.command)
    #expect(!before.commander.hasAlienMissileResearch)
    let lockedOffer = try #require(Equipment.all.first { $0.name == AlienMissileDefinition.name })
    #expect(!before.equipmentAvailable(lockedOffer))
    let result = await runtime.equipmentTransaction(.inventory(command))
    try #require(result.applied)
    let after = await runtime.snapshot()
    #expect(after.commander.credits == before.commander.credits - 15000)
    #expect(after.commander.hasAlienMissileResearch)
    #expect(after.commander.alienStorageState?.current.salvage.storedTechnology[source] == nil)
    #expect(
      after.commander.alienStorageState?.current.storedMassKg == before.commander.alienStorageState!
        .current.storedMassKg - 25)
    let proof = try #require(
      after.commander.alienStorageState?.current.salvage.missileResearch.first)
    let prototype = try #require(
      after.commander.equipmentInventory?.items.first { $0.id == proof.prototype })
    #expect(prototype.node == AlienMissileDefinition.node && prototype.location == nil)
    #expect(prototype.provenance == .paid(owner: proof.owner, transaction: proof.operation))
    #expect(
      after.commander.equipmentInventory!.items.count == before.commander.equipmentInventory!.items
        .count + 1)
    #expect(after.commander.missiles == before.commander.missiles && after.commander.valid)
    let replay = await runtime.equipmentTransaction(.inventory(command))
    #expect(!replay.applied)
    #expect(await runtime.snapshot().commander == after.commander)
  }

  @Test func researchedPlughSupplyChargesDiscountedPriceAndSharesFinitePylons() async throws {
    let folder = try nativeSalvageTestDirectory()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let (runtime, prototype) = try await researchAlienSeeker(file)
    let researched = await runtime.snapshot()
    let offer = try #require(Equipment.all.first { $0.name == AlienMissileDefinition.name })
    #expect(offer.price == 600 && researched.shopPrice(offer) == 450)
    var game = researched
    game.screen = .equipment
    game.selection = try #require(Equipment.all.firstIndex { $0.name == offer.name })
    let funds = game.commander.credits
    let paid = game.commander.equipmentPurchaseHistory?.paid.count ?? 0
    game.purchase()
    #expect(game.commander.credits == funds - 450)
    let receipt = try #require(game.commander.equipmentPurchaseHistory?.paid.last)
    #expect(receipt.node == AlienMissileDefinition.node && receipt.price == 450)
    #expect(game.commander.equipmentPurchaseHistory?.paid.count == paid + 1)
    #expect(
      game.commander.equipmentInventory?.items.filter { $0.node == AlienMissileDefinition.node }
        .count == 2)
    #expect(game.commander.equipmentInventory?.items.first { $0.id == prototype }?.location == nil)
    #expect(game.commander.missiles == researched.commander.missiles + 1 && game.commander.valid)
    let full = game.commander
    game.purchase()
    #expect(game.commander == full)
    game.launch()
    #expect(!game.equipmentAvailable(offer))
    #expect(throws: EquipmentRuntimeError.unavailable) { try game.quoteEquipmentPurchase(offer) }
  }

  @Test func loadedPrototypeLaunchConsumesExactItemAndUsesAlienProfileAndMesh() async throws {
    let folder = try nativeSalvageTestDirectory()
    defer { try? FileManager.default.removeItem(at: folder) }
    let (runtime, prototype) = try await researchAlienSeeker(
      folder.appendingPathComponent("commander.json"))
    try await loadAlienRound(runtime, id: prototype)
    var game = await runtime.snapshot()
    game.launch()
    game.weaponsTargetID = 2
    game.missileArmed = true
    let before = game.commander
    let fired = game.fireMissile()
    try #require(fired)
    let projectile = try #require(game.bodies.first { $0.physical?.ordnance != nil })
    let state = try #require(projectile.physical?.ordnance)
    #expect(state.profile == .alienSeeker)
    #expect(state.origin.playerAmmunition == .physical(item: prototype))
    #expect(abs(state.velocity.length - OrdnanceProfile.standardMissile.speed * 1.25) < 1e-9)
    #expect(state.profile.damage == OrdnanceProfile.standardMissile.damage * 1.25)
    #expect(game.commander.equipmentInventory?.items.contains { $0.id == prototype } == false)
    #expect(game.commander.missiles == before.missiles - 1 && game.commander.valid)
    #expect(game.commander.equipmentPurchaseHistory == before.equipmentPurchaseHistory)
    #expect(game.commander.hasAlienMissileResearch)
    #expect(projectile.hull == .missile)
    #expect(game.gameplayMesh(for: projectile).vertices == AlienMissileMesh.mesh.vertices)
    #expect(game.gameplayMesh(for: projectile).faces == AlienMissileMesh.mesh.faces)
  }

  @Test func failedResearchWriterAndStaleServiceRetainSourceCashAndPrototypeCount() async throws {
    let folder = try nativeSalvageTestDirectory()
    let preserved = folder.appendingPathExtension("preserved")
    defer {
      try? FileManager.default.removeItem(at: folder)
      try? FileManager.default.removeItem(at: preserved)
    }
    let file = folder.appendingPathComponent("commander.json")
    let (runtime, source) = try await recoveredArtefactAtPlugh(file)
    let before = await runtime.snapshot()
    let command = try #require(before.inventoryActionPreview(for: .alienResearch(source)).command)
    for owner in [command.owner, UUID()] {
      for hull in [command.hull, UUID()] where owner != command.owner || hull != command.hull {
        let forged = InventoryCommand(
          owner: owner, hull: hull, context: command.context, shipID: command.shipID,
          ownedRevision: command.ownedRevision, sourceRevision: command.sourceRevision,
          action: command.action)
        var wrong = before
        let rejected = wrong.performInventoryCommand(forged)
        #expect(!rejected && wrong.commander == before.commander)
      }
    }
    var stale = before
    stale.invalidateNativeStationAuthority()
    let refused = stale.performInventoryCommand(command)
    #expect(!refused && stale.commander == before.commander)
    try FileManager.default.moveItem(at: folder, to: preserved)
    try Data("blocked writer".utf8).write(to: folder)
    let failed = await runtime.equipmentTransaction(.inventory(command))
    #expect(!failed.applied)
    #expect(await runtime.snapshot().commander == before.commander)
    try FileManager.default.removeItem(at: folder)
    try FileManager.default.moveItem(at: preserved, to: folder)
    let retried = await runtime.equipmentTransaction(.inventory(command))
    #expect(retried.applied)
    #expect(await runtime.snapshot().commander.credits == before.commander.credits - 15000)
  }

  @Test func coldCurrentSaveRetainsResearchAfterPrototypeConsumptionAndRejectsForgedPayment()
    async throws
  {
    let folder = try nativeSalvageTestDirectory()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let (runtime, prototype) = try await researchAlienSeeker(file)
    try await loadAlienRound(runtime, id: prototype)
    await runtime.nativeCommand {
      $0.launch()
      $0.weaponsTargetID = 2
      $0.missileArmed = true
      _ = $0.fireMissile()
    }
    let fired = await runtime.snapshot()
    try #require(fired.commander.equipmentInventory?.items.contains { $0.id == prototype } == false)
    try await runtime.load(from: file, persistMigrations: false)
    let loaded = await runtime.snapshot()
    #expect(loaded.commander.hasAlienMissileResearch && loaded.commander.valid)
    #expect(
      loaded.commander.alienStorageState?.current.salvage.missileResearch
        == fired.commander.alienStorageState?.current.salvage.missileResearch)
    var forged = loaded.commander
    let history = try #require(forged.equipmentPurchaseHistory)
    forged.savedEquipmentPurchaseHistory = .init(owner: history.owner)
    #expect(throws: AlienStorageError.invalidJoin) { try forged.validateAlienMissileResearch() }
    let original = try #require(history.paid.first { $0.node == AlienMissileDefinition.node })
    let request = original.binding.request
    let badRequest = EquipmentPurchaseRequest(
      transaction: request.transaction, newItem: request.newItem,
      offer: .init(
        node: request.offer.node, price: 1, shop: request.offer.shop,
        revision: request.offer.revision),
      location: request.location)
    let badBinding = EquipmentPurchaseBinding(
      request: badRequest, snapshot: original.binding.snapshot,
      historyRevision: original.binding.historyRevision,
      graphRevision: original.binding.graphRevision,
      lineage: original.binding.lineage)
    let badPaid = EquipmentPaidPurchaseReceipt(
      owner: original.owner, node: original.node, binding: badBinding)
    forged.savedEquipmentPurchaseHistory = .init(
      owner: history.owner, revision: history.revision,
      paid: history.paid.map { $0.transaction == original.transaction ? badPaid : $0 },
      legacy: history.legacy)
    #expect(throws: AlienStorageError.invalidJoin) { try forged.validateAlienMissileResearch() }
    let native = try #require(loaded.commander.alienStorageState?.current.snapshot)
    var reversed = native.world
    for index in reversed.indices {
      switch reversed[index] {
      case .companion(let old):
        if case .researched(let collection, _) = old.state {
          reversed[index] = .companion(
            .init(
              id: old.id, owner: old.owner, plan: old.plan, origin: old.origin,
              issuedAt: old.issuedAt, state: .collected(collection)))
        }
      case .legacyCurrent(let old):
        if case .researched(let collection, _) = old.state {
          reversed[index] = .legacyCurrent(
            .init(
              id: old.id, owner: old.owner, claim: old.claim, state: .collected(collection)))
        }
      default: break
      }
    }
    let resurrected = AlienStorageSnapshot(
      owner: native.owner, revision: native.revision, worldRevision: native.worldRevision + 1,
      world: reversed, sources: native.sources, attachments: native.attachments,
      upgrades: native.upgrades, receipts: native.receipts, commands: native.commands)
    #expect(throws: AlienStorageError.historyChanged) {
      try resurrected.validateTransition(from: native)
    }
    var wrongOwner = loaded.commander
    wrongOwner.savedEquipmentPurchaseHistory = .init(
      owner: UUID(), revision: history.revision, paid: history.paid)
    #expect(throws: (any Error).self) { try wrongOwner.validateEquipmentState() }
  }

  @Test func standardUnlimitedLaunchNeverFabricatesAlienRoundsOrSpendsLoadedOriginal() async throws
  {
    let folder = try nativeSalvageTestDirectory()
    defer { try? FileManager.default.removeItem(at: folder) }
    let (runtime, prototype) = try await researchAlienSeeker(
      folder.appendingPathComponent("commander.json"))
    try await loadAlienRound(runtime, id: prototype)
    var game = await runtime.snapshot()
    game.launch()
    game.commander.unlimitedMissiles = true
    game.weaponsTargetID = 2
    game.missileArmed = true
    let before = game.commander
    let fired = game.fireMissile()
    try #require(fired)
    let state = try #require(game.bodies.first { $0.physical?.ordnance != nil }?.physical?.ordnance)
    #expect(state.profile == .standardMissile && state.origin.playerAmmunition == .virtualUnlimited)
    #expect(game.commander.equipmentInventory == before.equipmentInventory)
    #expect(game.commander.equipmentPurchaseHistory == before.equipmentPurchaseHistory)
    #expect(game.commander.valid)
  }
}
