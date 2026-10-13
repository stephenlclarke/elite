extension Game {
  /// TACTICS recharges one unit, then considers ordnance below half energy.
  mutating func navalTactics() {
    let candidates = bodies.filter { $0.hostile && $0.energy > 0 && $0.hull.navalEnergy != nil }
      .map(\.id)
    for id in candidates {
      guard let index = bodies.firstIndex(where: { $0.id == id }),
        let maximum = bodies[index].hull.navalEnergy
      else { continue }
      bodies[index].energy = min(maximum, bodies[index].energy + 1)
      let remaining = bodies[index].missiles
      guard bodies[index].energy <= maximum / 2, remaining > 0,
        randomByte() & 31 < remaining, ecmFrames == 0
      else { continue }
      bodies[index].missiles -= 1
      guard bodies.count < (commander.executive ? 18 : 10) else { continue }
      let position = bodies[index].position
      if bodies[index].hull == .thargoid {
        addNavalShip(.thargon, position: position)
      } else {
        var missile = SpaceBody(id: nextBodyID, hull: .missile, position: position, hostile: true)
        missile.enemyMissile = true
        missile.missileSourceID = id
        bodies.append(missile)
        nextBodyID += 1
        notify("INCOMING MISSILE", voiced: false)
      }
    }
  }

  mutating func advanceNavalMissiles(delta: Double) {
    let ids = bodies.filter { $0.playerMissileTarget != nil || $0.enemyMissile }.map(\.id)
    for id in ids {
      guard let index = bodies.firstIndex(where: { $0.id == id }), bodies[index].energy > 0 else {
        continue
      }
      if ecmFrames > 0 {
        ecmControl.recordDestruction()
        confirmRetaliation(bodies[index])
        bodies[index].energy = 0
        continue
      }
      if bodies[index].enemyMissile {
        advanceEnemyMissile(index: index, delta: delta)
      } else {
        advancePlayerMissile(index: index, delta: delta)
      }
    }
  }

  private mutating func advancePlayerMissile(index: Int, delta: Double) {
    guard
      let target = bodies.firstIndex(where: {
        $0.id == bodies[index].playerMissileTarget && $0.energy > 0
      })
    else {
      bodies[index].energy = 0
      return
    }
    let vector = bodies[target].position - bodies[index].position
    let step = 44 * 18 * delta
    if vector.length <= step + 64 {
      bodies[target].energy = 0
      bodies[target].destroyedByPlayer = true
      bodies[index].energy = 0
    } else if bodies[target].ecmEnabled && randomByte() < 16 {
      // Missile TACTICS tests proximity first, then a 16/256 ECM chance.
      ecmFrames = 32
      enemyECMSource = bodies[target].id
      bodies[index].energy = 0
      notify("ENEMY ECM")
    } else {
      bodies[index].position = bodies[index].position + vector * (step / vector.length)
    }
  }

  private mutating func advanceEnemyMissile(index: Int, delta: Double) {
    let position = bodies[index].position
    let step = 44 * 18 * delta
    if position.length <= step + 64 {
      applyDamage(250, front: position.z >= 0)
      bodies[index].energy = 0
    } else {
      bodies[index].position = position * (1 - step / position.length)
    }
  }
}
