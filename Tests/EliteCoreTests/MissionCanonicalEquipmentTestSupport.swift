import Foundation
import Testing

@testable import EliteCore

func missionGearFolder() throws -> URL {
  let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
    "mission-gear-" + UUID().uuidString)
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  return folder
}

func missionGearGame(missiles: Int? = nil) throws -> Game {
  var commander = Commander()
  if let missiles { commander.missiles = missiles }
  try commander.prepareEquipment(legacy: false)
  var game = Game(executive: false)
  // This is a freshly constructed current typed fixture, not a legacy file load.
  game.commander = commander
  game.commander.mirrorFittedEquipment()
  try game.migrateMiningPresence(legacyMissing: false, persistCurrentPolicy: true)
  game.energy = game.commander.performance.energy
  game.frontShield = game.commander.shieldCapacity
  game.rearShield = game.commander.rearShieldCapacity
  try #require(game.commander.valid)
  game.screen = .inventory
  return game
}

func missionStorePhysical(_ item: OwnedEquipmentItem, in game: inout Game) throws {
  game.screen = .inventory
  let command = try #require(game.inventoryActionPreview(for: .equipment(item)).command)
  let applied = game.performInventoryCommand(command)
  try #require(applied)
}

func missionHighestRound(_ commander: Commander) -> OwnedEquipmentItem? {
  func index(_ item: OwnedEquipmentItem) -> Int {
    if case .missilePylon(let value) = item.location?.slot { return value }
    return -1
  }
  return commander.equipmentInventory?.items.filter {
    $0.node == EquipmentRuntimeCatalog.standardMissile && index($0) >= 0
  }.max { index($0) < index($1) }
}

func missionPrepareSmallHullExchange(_ game: inout Game) throws -> Set<UUID> {
  var stored: Set<UUID> = []
  while game.commander.missiles > 1 {
    let item = try #require(missionHighestRound(game.commander))
    try missionStorePhysical(item, in: &game)
    stored.insert(item.id)
  }
  return stored
}
