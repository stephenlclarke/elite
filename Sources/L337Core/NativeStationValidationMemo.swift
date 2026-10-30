import Foundation

/// Complete semantic world value, with no memo, Game, Commander or callback reference.
/// Array/ledger copies retain Swift value semantics when another snapshot is mutated.
struct NativeStationWorldContent: Equatable, Sendable {
  let adapterRevision: String
  let geometryRevision: String
  let clockOrigin: Double
  let ledger: NativeStationLedger
  let poses: [NativeStationSavedPose]
  let mainStations: [NativeMainStationIdentity]
  let mainObservations: [NativeMainStationObservation]
  let nextMainDockSequence: UInt64
  let currentMainDock: NativeMainStationDockReceipt?
  let stationInertia: [NativeStationInertia]
  let arkFuel: [NativeArkStationFuel]?

  init(_ world: NativeStationWorld) {
    adapterRevision = world.adapterRevision
    geometryRevision = world.geometryRevision
    clockOrigin = world.clockOrigin
    ledger = world.ledger
    poses = world.poses
    mainStations = world.mainStations
    mainObservations = world.mainObservations
    nextMainDockSequence = world.nextMainDockSequence
    currentMainDock = world.currentMainDock
    stationInertia = world.stationInertia
    arkFuel = world.arkFuel
  }
}
