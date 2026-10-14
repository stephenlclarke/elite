import CryptoKit
import Foundation
import Testing

@testable import EliteCore

// Independent binary geometry digests captured before moving the native blueprints.
@Test func nativeShipFilesPreserveEveryOriginalCoordinateFaceAndDetail() {
  let expected: [(Hull, String)] = [
    (.cobra, "f09c9c467536200111b5352e7a4fbfcdc84977e0af301025ac7c827207fa98f7"),
    (.viper, "24f8bfd532dc259c2f9d94129b59f58ed28607f21a31de989b5a0c6417a1b47f"),
    (.sidewinder, "24f8bfd532dc259c2f9d94129b59f58ed28607f21a31de989b5a0c6417a1b47f"),
    (.station, "7722a282e7859a2a2986ae5238b393575ba8cc957d593c97f2aacf695992b3c1"),
    (.constrictor, "fd3e2c6ea84dea89a573e103bd323b88e1a93604b47c830151d9dfebe127ed2e"),
    (.thargoid, "4b3824b47cd6d488c451aaa5f32468dbc8c06459fe0e1a72d08daf58b82a715c"),
    (.thargon, "2bd2bb98046f0ea9c579c9ca644c949d41ef1c07a14ec93ecf3143680809a281"),
  ]
  for (hull, digest) in expected {
    let mesh = Mesh.hull(hull)
    var data = Data()
    func integer(_ value: Int) {
      var bits = Int64(value).bigEndian
      withUnsafeBytes(of: &bits) { data.append(contentsOf: $0) }
    }
    for vertex in mesh.vertices {
      for value in [vertex.x, vertex.y, vertex.z] {
        var bits = value.bitPattern.bigEndian
        withUnsafeBytes(of: &bits) { data.append(contentsOf: $0) }
      }
    }
    for face in mesh.faces {
      integer(face.count)
      for index in face { integer(index) }
    }
    for detail in mesh.details {
      integer(detail.start)
      integer(detail.end)
      integer(detail.face)
    }
    let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    #expect(actual == digest, "\(hull.rawValue)")
    #expect(ShipCatalogue.nativeShip(hull) != nil)
  }
  #expect(Hull.constrictor.navalEnergy == 252 && Hull.constrictor.navalMissiles == 4)
  #expect(Hull.thargoid.navalSpeed == 39 && Hull.thargoid.navalBounty == 500)
  #expect(Hull.thargon.navalLaserDamage == 8 && Hull.thargon.hasECM)
}
