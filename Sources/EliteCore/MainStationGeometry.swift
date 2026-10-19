/// Runtime adaptation of the original main station's 180-unit cube.
/// The archival SH028 nativeDesign remains unchanged. This opening is designed,
/// not a recovered historical dimension; see PR-station-auto-moving-entry.md.
enum MainStationGeometry {
  static let docking = NativeStationGeometry.Port(
    center: .init(0, 0, -90), outward: .init(0, 0, -1), up: .init(0, 1, 0),
    tunnelDepth: 25,
    aperture: [.init(-70, -32, 0), .init(70, -32, 0), .init(70, 32, 0), .init(-70, 32, 0)])

  /// Four front rim panels surround a real opening; all other cube walls remain solid.
  static let mesh = Mesh(
    vertices: [
      .init(-90, -90, -90), .init(90, -90, -90), .init(90, 90, -90), .init(-90, 90, -90),
      .init(-90, -90, 90), .init(90, -90, 90), .init(90, 90, 90), .init(-90, 90, 90),
    ] + docking.aperture.map { docking.center + $0 },
    faces: [
      [0, 3, 11, 8], [3, 2, 10, 11], [1, 9, 10, 2], [0, 8, 9, 1],
      [4, 5, 6, 7], [0, 1, 5, 4], [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5],
    ])
}
