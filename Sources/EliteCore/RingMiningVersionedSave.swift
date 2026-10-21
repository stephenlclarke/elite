import Foundation

/// A legacy header must not silently discard a ring tombstone, partial source or ore lot.
enum RingMiningVersionedSave {
  static func rejectFields(_ bytes: Data) throws {
    guard let root = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else {
      throw SaveError.invalidCommander
    }
    guard let ledger = root["savedMiningLedger"] as? [String: Any] else { return }
    func ringIdentity(_ value: Any) -> Bool {
      if let object = value as? [String: Any] {
        if let field = object["field"] as? Int, field >= 4 { return true }
        return object.values.contains(where: ringIdentity)
      }
      return (value as? [Any])?.contains(where: ringIdentity) == true
    }
    guard !ledger.keys.contains("generation"), !ledger.keys.contains("ringTerminal"),
      !ledger.keys.contains("legacyClusters"), !ledger.keys.contains("presenceOverrides"),
      !["partial", "pending", "offers", "bindings"].contains(where: {
        ledger[$0].map(ringIdentity) == true
      })
    else { throw SaveError.invalidCommander }
  }
}

/// New presence pins and cluster policy must never be interpreted through a pre-26 header.
enum EconomyMiningVersionedSave {
  static func rejectFields(_ bytes: Data) throws {
    guard let root = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else {
      throw SaveError.invalidCommander
    }
    guard let ledger = root["savedMiningLedger"] as? [String: Any] else { return }
    guard (ledger["generation"] as? Int) != 2,
      !ledger.keys.contains("legacyClusters"), !ledger.keys.contains("presenceOverrides")
    else { throw SaveError.invalidCommander }
  }
}
