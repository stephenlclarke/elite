import Foundation

extension ScriptPackLibrary {
  static func validateNPCTransit(_ manifest: ScriptManifest) throws {
    let hasDrive = (manifest.npcs ?? []).contains { $0.drive != nil }
    guard
      !hasDrive
        || [
          "npc-wormhole-transit-v2", "profiled-encounters-v2",
          "mission-calendar-v2", "story-v2", "durable-commands-v2",
        ]
        .allSatisfy(manifest.capabilities.contains),
      !manifest.capabilities.contains("npc-wormhole-transit-v2") || hasDrive,
      (manifest.npcs ?? []).allSatisfy(\.valid)
    else {
      throw MissionPackError(
        "NPC transit requires a closed fitted-drive declaration and native calendar.")
    }
  }
}
