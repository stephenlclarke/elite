import Foundation

extension NativeOriginalRescueJourney {
  static func recordCarried(_ state: NativeOriginalRescueJourneyState) -> Bool {
    state.record != nil && state.recordReception == nil && state.terminalOperation == nil
  }
  static func recordReceiptValid(
    _ receipt: NativeOriginalRescueRecordReceipt, state: NativeOriginalRescueJourneyState,
    commander: borrowing Commander
  ) -> Bool {
    guard let capture = state.record, receipt.capture == capture.operation,
      receipt.carrier == state.carrier, receipt.physicalTime >= capture.physicalTime,
      receipt.physicalTime <= commander.flightSimulation.physicalTime,
      NativeStationPassengerJourney.historicalDock(receipt.dock, commander: commander)
    else { return false }
    return sourceMatches(receipt.dock) || destinationMatches(receipt.dock)
  }
}

extension Game {
  mutating func receiveOriginalRescueRecord(
    dock: NativeMainStationDockReceipt, operation: UUID
  ) throws {
    guard nativeMainStationDockEvidenceIsCurrent,
      dock == commander.nativeStations?.currentMainDock,
      var custody = commander.nativePeople, var source = custody.originalRescue,
      let record = source.record, NativeOriginalRescueJourney.recordCarried(source),
      NativeOriginalRescueJourney.destinationMatches(dock)
        || NativeOriginalRescueJourney.sourceMatches(dock),
      source.carrier == commander.hullInstanceID
    else { throw SaveError.invalidCommander }
    source.recordReception = .init(
      operation: operation, capture: record.operation, dock: dock, carrier: source.carrier,
      physicalTime: commander.flightSimulation.physicalTime, epoch: nativeStationRuntimeEpoch)
    custody.originalRescue = source
    commander.savedNativePeopleCustody = custody
  }
}
