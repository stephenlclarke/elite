import Foundation

/// Structural crossing policy only; no constructor or result here is docking authority.
enum NativeArkDockCrossing {
  static func admits(
    from start: ShipPose, to end: ShipPose,
    stationFrom: ShipPose, stationTo: ShipPose, delta: Double
  ) -> Bool {
    guard delta.isFinite, delta > 0, delta <= 0.100001,
      [start, end, stationFrom, stationTo].allSatisfy({
        $0.position.finite && $0.orientation.validRotation
      })
    else { return false }
    let port = MainStationGeometry.docking
    let from = stationFrom.orientation.inverse(start.position - stationFrom.position) - port.center
    let to = stationTo.orientation.inverse(end.position - stationTo.position) - port.center
    let relativeVelocity =
      (end.position - start.position - stationTo.position + stationFrom.position) * (1 / delta)
    return from.dot(port.outward) > 0 && to.dot(port.outward) <= 0
      && to.dot(port.outward) > -port.tunnelDepth && relativeVelocity.length < 144
      && end.orientation.z.dot(stationTo.orientation.apply(port.outward)) < -0.995
      && end.orientation.y.dot(stationTo.orientation.apply(port.up)) > 0.995
  }
}
