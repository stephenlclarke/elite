import Foundation
import TOMLDecoder

extension ScriptPackLibrary {
  static func validateNPCKeys(_ root: TOMLTable) throws {
    if root.contains(key: "models") {
      let models = try root.array(forKey: "models")
      for i in 0..<models.count {
        try keys(models.table(atIndex: i), "id path sha256 source license")
      }
    }
    guard root.contains(key: "npcs") else { return }
    let npcs = try root.array(forKey: "npcs")
    for index in 0..<npcs.count {
      let npc = try npcs.table(atIndex: index)
      try keys(
        npc,
        "id name source basis model scale energy recharge speed acceleration pitch yaw roll missiles fuel drive ecm bounty lasers components"
      )
      if npc.contains(key: "drive") {
        try keys(
          npc.table(forKey: "drive"),
          "component rangeLightYears activationSeconds massLockScale fuelUnit")
      }
      try validateNPCWeapons(npc, key: "lasers")
      guard npc.contains(key: "components") else { continue }
      let components = try npc.array(forKey: "components")
      for index in 0..<components.count {
        let component = try components.table(atIndex: index)
        try keys(component, "id model scale position orientation energy solid weapons")
        try keys(component.table(forKey: "position"), "x y z")
        let basis = try component.table(forKey: "orientation")
        try keys(basis, "x y z")
        for axis in ["x", "y", "z"] { try keys(basis.table(forKey: axis), "x y z") }
        try validateNPCWeapons(component, key: "weapons")
      }
    }
  }
  private static func validateNPCWeapons(_ table: TOMLTable, key: String) throws {
    guard table.contains(key: key) else { return }
    let weapons = try table.array(forKey: key)
    for index in 0..<weapons.count {
      let weapon = try weapons.table(atIndex: index)
      try keys(
        weapon,
        "id kind muzzle direction arc damage range interval energy heat cooling maximumHeat colour trackingRate projectileSpeed lifetime collisionRadius collisionDelay"
      )
      try keys(weapon.table(forKey: "muzzle"), "x y z")
      try keys(weapon.table(forKey: "direction"), "x y z")
    }
  }
  static func validateNPCDeclarations(_ manifest: ScriptManifest) throws {
    let npcs = manifest.npcs ?? []
    let models = manifest.models ?? []
    let profileEvents: Set<String> = [
      "actor.intent.accepted", "actor.arrived", "actor.target.lost",
      "actor.damaged", "component.destroyed", "weapon.fired",
    ]
    guard npcs.count <= 64, Set(npcs.map(\.id)).count == npcs.count,
      npcs.allSatisfy(\.valid), models.count <= 32,
      npcs.allSatisfy({
        $0.drive == nil || manifest.capabilities.contains("npc-wormhole-transit-v2")
      }),
      Set(models.map(\.id)).count == models.count, models.allSatisfy(\.valid),
      Set(models.map(\.path)).count == models.count,
      models.allSatisfy({ $0.path != manifest.module && $0.path != "manifest.toml" }),
      npcs.isEmpty && models.isEmpty
        && !manifest.handlers.contains(where: { profileEvents.contains($0.event) })
        || manifest.capabilities.contains("profiled-encounters-v2")
    else {
      throw MissionPackError(
        "Invalid NPC profiles/models or missing profiled encounter capability.")
    }
  }
}
