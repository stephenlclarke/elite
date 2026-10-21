import Foundation

/// Base scenario 2 only. Native scheduling and explicit confirmation are project adaptations.
enum RRSCourierContent {
  static let profile = "PROJECT-P30-COURIER-2-v1"
  static let source = "e109933b741e875e63fdf04ec595301ec4e62a0af2cc4c7ad8140f72f17dd193"
  static let title = "RRS / Sealed documents"
  static let briefing =
    "Carry a protected digital document packet to this system's original main orbital station. "
    + "Dock there and Confirm the debrief to transfer the packet."
  static let terms = [
    "Reward: 30.0 CR and RRS reputation +2, once on confirmed delivery.",
    "Protected digital packet: 0 tonnes; no equipment, pylon or cabin space.",
    "The packet cannot be sold, jettisoned or stored.",
    "No deadline. Intermediate docking within this system is allowed.",
    "Leaving this system, entering another galaxy, abandoning, or destruction of the original "
      + "main station fails the assignment: 0 CR and RRS reputation -10, once.",
    "An unproved or temporarily missing destination suspends delivery.",
    "Confirm accepts. Reading, Back and Decline create no packet.",
  ]

  static func boardKey(_ station: NativeStationIdentity, hour: Int64) -> String {
    "rrs:\(station.world.uuidString):\(station.key):\(hour):\(profile)"
  }
  static func seed(_ key: String) -> String {
    ScriptPackLibrary.hash(Data(("rrs-native-board-v1:" + key).utf8))
  }
  static func draw(_ seed: String) -> Double {
    guard let bits = UInt64(seed.prefix(16), radix: 16) else { return 1 }
    return Double(bits >> 11) / 9_007_199_254_740_992
  }
  static func eligible(reputation: Int, legal: Int, draw: Double) -> Bool {
    reputation >= -10 && legal <= 50 && draw.isFinite && draw >= 0 && draw < 0.5
  }
  static func offerID(_ key: String) -> UUID {
    ScriptIdentity.uuid("rrs-documents-offer-v1:" + key)
  }
  static func packetID(_ offer: UUID) -> UUID {
    ScriptIdentity.uuid("rrs-protected-digital-packet-v1:" + offer.uuidString)
  }
}
