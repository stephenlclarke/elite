import Testing

@testable import L337Core

@Test func fuelGaugeNormalizationKeepsInvalidInputsEmptyAndNormalGreenFillUnchanged() {
  let cases: [(fuel: Double, capacity: Double, fraction: Double, pixelsWide: Int)] = [
    (0, 0, 0, 0),
    (35, 0, 0, 0),
    (35, -70, 0, 0),
    (35, .nan, 0, 0),
    (35, .infinity, 0, 0),
    (35, -.infinity, 0, 0),
    (.nan, 70, 0, 0),
    (.infinity, 70, 0, 0),
    (-.infinity, 70, 0, 0),
    (0, 70, 0, 0),
    (35, 70, 0.5, 23),
    (70, 70, 1, 46),
    (105, 70, 1, 46),
  ]
  for sample in cases {
    let fraction = Game.equipmentResourceLevel(sample.fuel, from: sample.capacity, to: 1)
    #expect(fraction.isFinite && fraction == sample.fraction)
    var frame = Frame()
    Display.bar(&frame, 24, 10, fraction, .green, 46)
    let lines = frame.graphics.compactMap { graphic -> WireLine? in
      if case .line(let line) = graphic { return line }
      return nil
    }
    #expect(lines.count == (sample.pixelsWide == 0 ? 0 : 4))
    for (row, line) in lines.enumerated() {
      #expect(line.ink == .green)
      #expect(line.x0 == 24 && line.x1 == Double(24 + sample.pixelsWide - 1))
      #expect(line.y0 == Double(10 + row) && line.y1 == Double(10 + row))
    }
    #expect(frame.pixels.filter { $0 == Ink.green.rawValue }.count == sample.pixelsWide * 4)
    #expect(frame.graphics.count == lines.count)
  }
}
