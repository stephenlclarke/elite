import CryptoKit
import Foundation

/// Versioned caller namespaces pin opaque identities without consuming simulation randomness.
enum ScriptIdentity {
  static func uuid(_ key: String) -> UUID {
    let bytes = Array(SHA256.hash(data: Data(key.utf8)))
    return UUID(
      uuid: (
        bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
        bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
      ))
  }
}
