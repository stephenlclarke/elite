import Foundation

extension Game {
  func packGallery(_ entry: LoadedMissionPack) -> GalleryMission {
    let pack = entry.pack
    let state = progress(for: entry)
    let stage = pack.stage(state.stage) ?? pack.stages[0]
    let available: Bool
    if pack.mission.binding == "blackjack" {
      available = commander.galaxy == 1
    } else {
      available = pack.transitions.filter { $0.from == pack.mission.initialStage }.contains {
        matches($0.conditions ?? [], state: state, target: nil)
      }
    }
    let compatible = packMatchesSave(entry)
    let status: GalleryStatus
    if !compatible {
      status = .locked
    } else if stage.terminal == true {
      status = stage.outcome == .failed ? .failed : .complete
    } else if stage.completed > 0 {
      status = .active
    } else {
      status = available ? .available : .locked
    }
    let milestones = pack.mission.milestones.enumerated().map { index, name in
      let label: String
      if index < stage.completed {
        label = "Complete"
      } else if status == .failed {
        label = "Failed"
      } else if index == stage.completed && status != .locked {
        label = "Current"
      } else {
        label = status == .locked ? "Locked" : "Upcoming"
      }
      return MissionMilestone(title: name, state: label)
    }
    return GalleryMission(
      name: pack.mission.title, status: status,
      objective: compatible
        ? stage.objective : "Suspended: restore the saved pack version/content.",
      briefing: pack.mission.briefing, destination: pack.mission.destination,
      reward: pack.mission.reward, prerequisites: pack.mission.prerequisites.map(packText),
      completed: stage.completed, milestones: milestones)
  }
  var missingPackGallery: [GalleryMission] {
    let installed = Set(missionPacks.entries.map { $0.pack.stateID })
    return commander.missionProgress.keys.sorted().filter { !installed.contains($0) }.map { key in
      GalleryMission(
        name: key, status: .locked, objective: "Suspended: reinstall the matching mission pack.",
        briefing: "Saved progress and reserved cargo remain intact.", destination: "Pack missing",
        reward: "No actions or rewards run while suspended.", prerequisites: [], completed: 0,
        milestones: [])
    }
  }
}
