import Foundation

extension Game {
  /// Native custody is projected for reading only; a Gallery row carries no service authority.
  var rrsCourierGallery: [GalleryMission] {
    guard let ledger = commander.contracts.rrs, ledger.valid(for: commander) else { return [] }
    return ledger.jobs.map { job in
      let delivered = job.terminal?.outcome == .delivered
      let failed = job.terminal != nil && !delivered
      let arrived =
        job.terminal?.arrival != nil
        || (job.terminal == nil && nativeMainStationArrivalContext(for: job.destination) != nil)
      let outcome = job.terminal.map { terminal in
        switch terminal.outcome {
        case .delivered: "Delivered: 30.0 CR / reputation +2, recorded once."
        case .departedSystem: "Failed: left the destination system."
        case .newGalaxy: "Failed: entered another galaxy."
        case .abandoned: "Failed: assignment abandoned."
        case .originalMainDestroyed: "Failed: the original main station was destroyed."
        }
      }
      let milestones: [MissionMilestone] = [
        .init(title: "Confirm acceptance at the RRS station", state: "Complete"),
        .init(
          title: "Carry the protected document packet",
          state: delivered || arrived ? "Complete" : (failed ? "Failed" : "Current")),
        .init(
          title: "Arrive through the original main station doorway",
          state: arrived ? "Complete" : (failed ? "Locked" : "Upcoming")),
        .init(
          title: outcome ?? "Confirm the original main station debrief",
          state: job.terminal != nil ? "Complete" : (arrived ? "Current" : "Upcoming")),
      ]
      let destination = Universe.systemsIncludingPlugh(number: job.destination.system.galaxy)[
        job.destination.system.system
      ].name
      let originSystem = Universe.systemsIncludingPlugh(number: job.origin.station.system.galaxy)[
        job.origin.station.system.system
      ].name
      let origin =
        job.origin.station.definition == "rrs_headquarters" ? "RRS Headquarters" : "RRS Waystation"
      let objective =
        outcome
        ?? (arrived
          ? "Confirm delivery in Station Contracts. Reading does not transfer the packet."
          : "Carry the packet to the original main station; current arrival is not proved.")
      return GalleryMission(
        name: RRSCourierContent.title, status: delivered ? .complete : (failed ? .failed : .active),
        objective: objective,
        briefing: RRSCourierContent.briefing + "\nOrigin: " + originSystem + " / Galaxy "
          + String(job.origin.station.system.galaxy + 1) + " / " + origin
          + "\nProtected document packet"
          + (job.carriesPacket ? " / protected custody retained." : " / custody ended.")
          + "\n" + RRSCourierContent.terms.joined(separator: "\n")
          + (failed ? "\nRecorded failure: 0 CR / reputation -10, once." : ""),
        destination: destination + " / original main orbital station",
        reward: "30.0 CR / reputation +2 on confirmed delivery",
        prerequisites: ["Accepted RRS document assignment. Confirm delivery in Station Contracts."],
        completed: milestones.filter { $0.state == "Complete" }.count, milestones: milestones,
        nativeRRSCourierID: job.id)
    }
  }
}
