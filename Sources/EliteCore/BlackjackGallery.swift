import Foundation

extension Game {
  public var blackjackGalleryMission: GalleryMission {
    let mission = commander.blackjack
    let available = commander.galaxy == 1
    let status: GalleryStatus
    if mission.stage == .complete {
      status = .complete
    } else if mission.stage != .notStarted {
      status = .active
    } else {
      status = available ? .available : .locked
    }
    let objectives = [
      "Dock at Telace's main station in Galaxy 2 for Blackjack's contact.",
      "Destroy the unique Commander Bolts at Gerebied, Galaxy 2. Any killer counts.",
      "Report at any main station in Galaxy 2. Collect pending gold first if needed.",
      "Collect the one-tonne marked firearm at Tegete's main station, Galaxy 2.",
      "Deliver the marked firearm through Ceinerxe's dockside handoff, Galaxy 2.",
      "Destroy the unique witness at Edater, Galaxy 2. Any killer counts.",
      "Confirm the final report at Esdi's main station, Galaxy 2, for 9,500 CR and bounty clearance.",
      "Blackjack's Bullion complete. No further reward or bounty clearance is available.",
    ]
    let names = [
      "Receive Blackjack's contact", "Destroy Bolts; earn 20 kg gold",
      "Report at a G2 main station", "Collect the marked firearm",
      "Confirm Ceinerxe dockside handoff", "Destroy the unique witness",
      "Confirm Esdi report and final reward",
    ]
    let milestones = names.enumerated().map { index, name in
      let state: String
      if index < mission.stage.progress {
        state = "Complete"
      } else if index == mission.stage.progress && (available || mission.stage != .notStarted) {
        state = "Current"
      } else {
        state = available || mission.stage != .notStarted ? "Upcoming" : "Locked"
      }
      return MissionMilestone(title: name, state: state)
    }
    return GalleryMission(
      name: "Blackjack's Bullion", status: status, objective: objectives[mission.stage.progress],
      briefing:
        "A recovered Oolite 1.2.9 campaign: revenge, a dockside firearm transfer, a witness chase and final report. No score gate or deadline. This project replaces the station robbery with explicit Confirm/Back transfers and repairs witness, custody, wanted-level and duplicate-reward defects.",
      destination:
        "Spoilers, Galaxy 2: Telace 241 > Gerebied 88 > any main station > Tegete 233 > Ceinerxe 127 > Edater 99 > Esdi 67. System IDs are zero-based.",
      reward:
        "20 kg gold earned directly on Bolts' death, then 9,500 CR and one-time bounty clearance at Esdi. Gold is not a scoop objective.",
      prerequisites: [
        "Galaxy 2 main-station contact at Telace. No combat-score prerequisite.",
        "One free tonne is required at Tegete. Marked firearms cannot be sold or stored.",
        "Seven chronological milestones; optional clues are not progress.",
      ], completed: mission.stage.progress, milestones: milestones)
  }
}
