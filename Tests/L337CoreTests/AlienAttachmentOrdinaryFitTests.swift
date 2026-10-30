import Foundation
import Testing

@testable import L337Core

/// Unit work/collection boundary using actual retained producer plans. No owned alien
/// attachment, EMP custody, native actor admission or installation proof is manufactured.
func recoveredAlienBoundaryGame(
  definitionID: String, roles: Set<SalvageSourceRole>, requiredAxis: SalvageUpgradeAxis? = nil
) throws -> Game {
  var game = Game(executive: false)
  try game.commander.prepareEquipment(legacy: false)
  let wreck = WreckIdentity(system: game.systemIdentity, site: 1, lineage: 123)
  let section = SalvageSectionProfile(
    index: 1, kind: .computer, localPosition: .init(10, 0, 0), normal: .init(0, 0, 1),
    radius: 10, workSeconds: 1, structural: false, technologyDefinitionIDs: [], sourceFaceIndex: 0)
  let identity = WreckSectionIdentity(wreck: wreck, section: section.index)
  let source = SalvageLootSource(
    roles: roles, legalValue: 0, economy: 3, technology: 12, ownership: .abandoned)
  let seed = try #require(
    (UInt64(0)..<5000).first { seed in
      SalvageLootProfiles.plan(section: identity, seed: seed, source: source).items.contains {
        item in
        if case .technology(let id, _, _, let axis) = item.content {
          return id == definitionID && (requiredAxis == nil || axis == requiredAxis)
        }
        return false
      }
    })
  var ledger = SalvageLedger(seed: seed)
  let inspection = ledger.inspectLoot(wreck: wreck, section: section, source: source)
  let inspected = try #require(inspection)
  let planned = try #require(
    inspected.items.first { item in
      if case .technology(let id, _, _, _) = item.content { return id == definitionID }
      return false
    })
  let result = ledger.advance(
    wreck: wreck, section: section, pose: ShipPose(), velocity: .init(0, 0, 0),
    angularVelocity: .init(0, 0, 0), tool: .cutter, elapsed: 1, operation: 1,
    conditions: .init(
      toolInstalled: true, inRange: true, aligned: true,
      lineOfSight: true, resourcesAvailable: true, ownershipAuthorized: true), source: source)
  guard case .released(let lots) = result else { throw SaveError.invalidCommander }
  let lot = try #require(lots.first { $0.identity == planned.identity })
  #expect(lot.loot == planned && ledger.pendingLots.contains(lot))
  var cargo = game.commander.cargo
  let receipt = ledger.collect(
    lot: lot.identity, cargo: &cargo, freeTonnes: game.commander.standardCargoCapacity,
    apertureHalfExtents: .init(100, 100, 100), hasScoops: true, approachAllowed: true,
    protection: .init())
  try #require(receipt == .collected(lot))
  #expect(ledger.inventory.contains(lot) && !ledger.pendingLots.contains(lot))
  // Reload preserves the real collected source rather than constructing a stored lot.
  ledger = try JSONDecoder().decode(SalvageLedger.self, from: JSONEncoder().encode(ledger))
  #expect(ledger.inventory.contains(lot))
  game.commander.cargo = cargo
  game.commander.salvageLedger = ledger
  game.screen = .inventory
  try #require(game.commander.valid)
  return game
}

private func ordinaryAlienAxis(_ axis: SalvageUpgradeAxis) throws -> ComponentAxis {
  switch axis {
  case .energyCapacity: .energyCapacity
  case .energyRecharge: .energyRecharge
  case .frontShieldCapacity: .frontShieldCapacity
  case .frontShieldRecharge: .frontShieldRecharge
  default: throw SalvageComponentEffectError.unsupportedEffect
  }
}

struct AlienAttachmentOrdinaryFitTests {
  @Test(arguments: AlienModuleKind.allCases.filter(\.supportsUpgrade))
  func authenticCollectedModulesAndUpgradesRefuseEveryOrdinaryFittingEntry(kind: AlienModuleKind)
    throws
  {
    for upgrade in [false, true] {
      for inFlight in [false, true] {
        let definition = upgrade ? kind.upgradeDefinitionID : kind.definitionID
        var game = try recoveredAlienBoundaryGame(definitionID: definition, roles: [.thargoid])
        if inFlight {
          game.launch()
          game.screen = .inventory
        }
        let lot = try #require(game.commander.salvageLedger.inventory.first)
        #expect(lot.loot?.provenance == .alien)
        if upgrade {
          _ = try AlienModuleDefinition.upgradeBonus(for: lot, kind: kind)
        } else {
          #expect(try AlienModuleDefinition.kind(for: lot) == kind)
        }
        let slot: ComponentFittingSlot = kind.isEnergyModule ? .energy : .shield
        let axis = try #require(kind.axes.first)
        if upgrade && kind.isEnergyModule {
          // This is the formerly accepted one-axis shape, not an incidental multi-axis refusal.
          #expect(SalvageComponentEffects.hasCoherentFixedEffect(lot, axis: axis))
        }
        let item = try #require(game.commander.fittedEquipment(at: slot))
        let component = try #require(item.component)
        let inventory = try #require(game.commander.equipmentInventory)
        let before = game.commander
        let resources = [game.energy, game.frontShield, game.rearShield, game.laserHeat]
        for candidate in kind.axes {
          #expect(throws: SalvageComponentEffectError.unsupportedEffect) {
            _ = try game.commander.previewRecoveredUpgrade(
              lot: lot.identity, axis: candidate, slot: slot)
          }
          #expect(throws: SalvageComponentEffectError.unsupportedEffect) {
            _ = try game.commander.quoteRecoveredUpgrade(
              lot: lot.identity, axis: candidate, slot: slot)
          }
        }
        // A reserved source is rejected before missing-component/binding/progression paths,
        // including physical nil-axis modules and paired shield effects.
        #expect(throws: SalvageComponentEffectError.unsupportedEffect) {
          _ = try SalvageComponentEffects.quote(
            lotID: lot.identity, ledger: game.commander.salvageLedger,
            component: nil, liveLocation: nil,
            binding: .equipment(
              target: .commanderResearch, expectedComponentInstanceID: nil, templateVersion: 0,
              axis: nil, feature: nil, location: nil))
        }
        #expect(throws: SalvageComponentEffectError.unsupportedEffect) {
          let quote = try game.commander.quoteRecoveredUpgrade(
            lot: lot.identity, axis: axis, slot: slot)
          try game.applyRecoveredUpgrade(quote)
        }
        let preview = game.inventoryActionPreview(for: .recovered(lot))
        #expect(preview.command == nil && preview.label != "Fit now")
        // Recreate the ordinary engine projection used by the vulnerable old UI command.
        // All source, owner, revision and component facts are genuine; the public mutation
        // path must re-quote and refuse before it can consume this reserved alien source.
        guard case .technology(_, let quality, _) = lot.content else {
          throw SaveError.invalidCommander
        }
        let family =
          kind.isEnergyModule ? EquipmentModuleTemplates.energy : EquipmentModuleTemplates.shield
        let scalar = ComponentUpgrade(
          identity: .salvage(lot.identity), boundComponent: component.id,
          origin: component.origin.identity,
          basisPoints: [try ordinaryAlienAxis(axis): quality.bonusBasisPoints])
        let projection = try ComponentProgression.quote(
          component: component, item: scalar,
          definition: family, inventoryRevision: game.commander.salvageLedger.revision)
        let command = InventoryCommand(
          owner: inventory.owner, hull: inventory.activeHull,
          context: game.inventoryContextEpoch, shipID: game.commander.shipID,
          ownedRevision: inventory.revision,
          sourceRevision: game.commander.salvageLedger.revision,
          action: .upgrade(
            item, lot, axis, slot, before: projection.before, after: projection.after,
            grade: projection.resultingGrade))
        let performed = game.performInventoryCommand(command)
        #expect(!performed)
        #expect(game.commander == before)
        #expect([game.energy, game.frontShield, game.rearShield, game.laserHeat] == resources)
        #expect(game.commander.salvageLedger.inventory.contains(lot) && game.commander.valid)
      }
    }
  }

  @Test(arguments: [
    SalvageUpgradeAxis.energyCapacity, .energyRecharge, .frontShieldCapacity, .frontShieldRecharge,
  ])
  func authenticOrdinaryHumanUpgradesStillQuoteFitAndConsumeExactlyOnce(axis: SalvageUpgradeAxis)
    throws
  {
    let energy = axis == .energyCapacity || axis == .energyRecharge
    let slot: ComponentFittingSlot = energy ? .energy : .shield
    var game = try recoveredAlienBoundaryGame(
      definitionID: energy ? "energy-technology" : "shield-technology",
      roles: [.militaryCapital], requiredAxis: axis)
    let lot = try #require(game.commander.salvageLedger.inventory.first)
    #expect(lot.loot?.provenance == .human)
    #expect(SalvageComponentEffects.hasCoherentFixedEffect(lot, axis: axis))
    let before = try #require(game.commander.fittedEquipment(at: slot))
    let preview = game.inventoryActionPreview(for: .recovered(lot))
    #expect(preview.label == "Fit now" && preview.command != nil)
    _ = try game.commander.previewRecoveredUpgrade(lot: lot.identity, axis: axis, slot: slot)
    let quote = try game.commander.quoteRecoveredUpgrade(lot: lot.identity, axis: axis, slot: slot)
    try game.applyRecoveredUpgrade(quote)
    let after = try #require(game.commander.fittedEquipment(at: slot))
    #expect(after.id == before.id && after.component != before.component)
    #expect(after.component?.receipts.count == (before.component?.receipts.count ?? 0) + 1)
    #expect(!game.commander.salvageLedger.inventory.contains(lot) && game.commander.valid)
    let committed = game.commander
    #expect(throws: RecoveredEquipmentError.staleQuote) { try game.applyRecoveredUpgrade(quote) }
    #expect(game.commander == committed)
  }
}
