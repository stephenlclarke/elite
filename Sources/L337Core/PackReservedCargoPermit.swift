import Foundation

/// Ephemeral, one-use authority for the bundled campaign's own reserved firearm.
/// External pack data cannot construct or persist this permission.
struct PackReservedCargoPermit: Sendable {
  private let digest: String
  private let version: String
  private let stage: String
  private var available = true

  private init(digest: String, version: String, stage: String) {
    self.digest = digest
    self.version = version
    self.stage = stage
  }

  static func blackjackHandoff(
    commander: Commander, entry: LoadedMissionPack, transition: PackTransition,
    state: MissionProgress
  ) -> Self? {
    guard entry.pack.mission.binding == "blackjack",
      let bundled = MissionPackLibrary.bundled.entries.first(where: {
        $0.pack.mission.binding == "blackjack"
      }),
      entry.digest == bundled.digest, entry.pack.stateID == bundled.pack.stateID,
      state.digest == entry.digest, state.version == entry.pack.version,
      transition.id == "robbery", transition.from == "deliver-firearm",
      transition.to == "hunt-witness", state.stage == transition.from,
      state.receipts.contains("firearmPickup"), !state.receipts.contains("robberyHandoff"),
      !state.receipts.contains("transition.robbery"),
      commander.blackjack.stage == .deliverFirearm, commander.markedFirearms == 1,
      commander.cargo[10] >= 1
    else { return nil }
    return .init(digest: state.digest, version: state.version, stage: state.stage)
  }

  mutating func consume(
    index: Int, amount: Int, digest: String, version: String, stage: String,
    markedFirearms: Int, physicalQuantity: Int
  ) -> Bool {
    guard available, index == 10, amount == 1, digest == self.digest, version == self.version,
      stage == self.stage,
      markedFirearms == 1, physicalQuantity >= 1
    else { return false }
    available = false
    return true
  }
}
