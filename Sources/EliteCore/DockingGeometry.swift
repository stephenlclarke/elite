import Foundation

extension SpaceBody {
  public var containsPlayer: Bool {
    let relative = position * -1
    let axes = [modelVector(.init(1, 0, 0)), entranceUp, modelVector(.init(0, 0, 1))]
    return axes.allSatisfy { abs(relative.dot($0)) < 90 }
  }
  public func canEnter(roll: Double, speed: Double) -> Bool {
    let toPlayer = entrancePosition * -1
    let x = toPlayer.dot(modelVector(.init(1, 0, 0)))
    let y = toPlayer.dot(entranceUp)
    let depth = toPlayer.dot(entranceNormal)
    let facing = entranceNormal.z < -0.98
    let phase = abs(atan2(entranceUp.x, entranceUp.y)) < 0.1
    let matchedRate = abs(roll + rotationRate * orientation.z.z) < 0.1
    return abs(x) < 25 && abs(y) < 8 && depth <= 1 && depth > -25 && facing && phase
      && speed < 144 && (matchedRate || abs(roll) < 0.15)
  }
}
