import Foundation
import Testing

@testable import EliteCore

private func missionStackLayout<T>(_: T.Type) -> [String: Int] {
  [
    "size": MemoryLayout<T>.size,
    "stride": MemoryLayout<T>.stride,
    "alignment": MemoryLayout<T>.alignment,
  ]
}

/// Diagnostic only: reports value storage, not gameplay acceptance or total stack usage.
@Test func missionAdmissionRuntimeTypeLayouts() throws {
  let layouts = [
    "Game": missionStackLayout(Game.self),
    "Commander": missionStackLayout(Commander.self),
    "SpaceBody": missionStackLayout(SpaceBody.self),
    "SpaceBody?": missionStackLayout(Optional<SpaceBody>.self),
    "ScriptEngineState": missionStackLayout(ScriptEngineState.self),
    "ScriptInstance": missionStackLayout(ScriptInstance.self),
    "ScriptInstance?": missionStackLayout(Optional<ScriptInstance>.self),
    "ScriptPack": missionStackLayout(ScriptPack.self),
    "ShipDesign": missionStackLayout(ShipDesign.self),
    "FlightSimulationState": missionStackLayout(FlightSimulationState.self),
    "EncounterContext": missionStackLayout(EncounterContext.self),
    "EncounterContext?": missionStackLayout(Optional<EncounterContext>.self),
    "NativeMissionActorAdmissionPlanReference": missionStackLayout(
      NativeMissionActorAdmissionPlan.self),
    "NativeMissionActorAdmissionPreparation": missionStackLayout(
      NativeMissionActorAdmissionPreparation.self),
    "NativeMissionActorAdmissionReceipt": missionStackLayout(
      NativeMissionActorAdmissionReceipt.self),
    "MissionActorAdmissionSource": missionStackLayout(MissionActorAdmissionSource.self),
    "MissionActorAdmissionAuthority": missionStackLayout(MissionActorAdmissionAuthority.self),
    "MissionActorAdmissionTemplate": missionStackLayout(MissionActorAdmissionTemplate.self),
    "MissionActorAdmissionPart": missionStackLayout(MissionActorAdmissionPart.self),
    "MissionActorRetentionPatch": missionStackLayout(MissionActorRetentionPatch.self),
    "ScriptOwnedEncounter": missionStackLayout(ScriptOwnedEncounter.self),
    "ScriptOwnedEncounter?": missionStackLayout(Optional<ScriptOwnedEncounter>.self),
    "ScriptOwnedActor": missionStackLayout(ScriptOwnedActor.self),
    "ScriptNPCState": missionStackLayout(ScriptNPCState.self),
    "ScriptNPCState?": missionStackLayout(Optional<ScriptNPCState>.self),
  ]
  let data = try JSONSerialization.data(withJSONObject: layouts, options: [.sortedKeys])
  print("MISSION_STACK_LAYOUT_JSON " + String(decoding: data, as: UTF8.self))
}
