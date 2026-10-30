import Foundation

public enum SoundEffect: Sendable, CaseIterable {
  case laser, launch, dock, explosion, ping, ecm
  public var duration: Double {
    switch self {
    case .laser: 0.12
    case .launch: 0.8
    case .dock: 0.6
    case .explosion: 0.35
    case .ping: 0.1
    case .ecm: 0.3
    }
  }
  public func frequency(_ progress: Double) -> Double {
    switch self {
    case .laser: 1100 - progress * 900
    case .launch: 180 + progress * 800
    case .dock: 900 - progress * 700
    case .explosion: 60 + progress * 30
    case .ping: 880
    case .ecm: 600 + sin(progress * .pi * 12) * 300
    }
  }
  /// Independent square-wave/noise synthesis; no original sound assets are bundled.
  public func wav() -> Data {
    let rate = 22050
    let count = Int(duration * Double(rate))
    var samples: [Int16] = []
    samples.reserveCapacity(count)
    var phase = 0.0
    var noise: UInt32 = 0x454c_4954
    for index in 0..<count {
      let progress = Double(index) / Double(count)
      phase += frequency(progress) / Double(rate)
      noise = noise &* 1_664_525 &+ 1_013_904_223
      let noiseSign: Double = noise & 1 == 0 ? -1 : 1
      let squareSign: Double = phase.truncatingRemainder(dividingBy: 1) < 0.5 ? -1 : 1
      let sign = self == .explosion ? noiseSign : squareSign
      samples.append(Int16(sign * 5000 * (1 - progress)))
    }
    var data = Data("RIFF".utf8)
    append(UInt32(36 + count * 2), to: &data)
    data.append(Data("WAVEfmt ".utf8))
    append(UInt32(16), to: &data)
    append(UInt16(1), to: &data)
    append(UInt16(1), to: &data)
    append(UInt32(rate), to: &data)
    append(UInt32(rate * 2), to: &data)
    append(UInt16(2), to: &data)
    append(UInt16(16), to: &data)
    data.append(Data("data".utf8))
    append(UInt32(count * 2), to: &data)
    for sample in samples { append(UInt16(bitPattern: sample), to: &data) }
    return data
  }
  private func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
    var little = value.littleEndian
    withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
  }
}
