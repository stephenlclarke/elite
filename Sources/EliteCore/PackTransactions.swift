import Foundation

extension Commander {
  mutating func mirror(_ pack: MissionPack, state: MissionProgress) {
    guard let raw = pack.stage(state.stage)?.legacyWrite else { return }
    if pack.mission.binding == "naval", let stage = NavalMissionStage(rawValue: raw) {
      missionStage = stage
    }
    if pack.mission.binding == "blackjack", let stage = BlackjackStage(rawValue: raw) {
      blackjack.stage = stage
      blackjack.pendingGold = state.flags["pendingGold"] == 1
      blackjack.transfers = Set(
        BlackjackTransfer.allCases.filter { state.receipts.contains($0.rawValue) })
    }
  }
  mutating func apply(_ action: PackAction, state: inout MissionProgress) throws {
    var permit: PackReservedCargoPermit?
    try apply(action, state: &state, reservedCargo: &permit)
  }

  mutating func apply(
    _ action: PackAction, state: inout MissionProgress,
    reservedCargo: inout PackReservedCargoPermit?
  ) throws {
    let amount = action.amount ?? 0
    let key = action.key ?? ""
    switch action.kind {
    case "credits":
      guard credits <= 4_294_967_295 - amount else {
        throw MissionPackError("Spend credits before collecting reward.")
      }
      credits += amount
    case "creditsWrapped": credits = (credits + amount) & 0xffff_ffff
    case "killsWrapped": kills = (kills + amount) & 0xffff
    case "legalSet": legal = amount
    case "legalFloor": legal = max(legal, amount)
    case "equipmentAdd": try grantMissionEquipment(key, digest: state.digest)
    case "equipmentRemove": try removeFittedEquipment(key)
    case "flagSet": state.flags[key] = amount
    case "receipt": state.receipts.insert(key)
    case "payloadAdd":
      guard cargoTonnes + amount <= capacity else {
        throw MissionPackError("Mission parcel needs free hold space.")
      }
      state.payloads[key, default: 0] += amount
    case "payloadRemove":
      guard state.payloads[key, default: 0] >= amount else {
        throw MissionPackError("Mission parcel required.")
      }
      state.payloads[key, default: 0] -= amount
    case "cargoAdd", "cargoRemove", "cargoRewardOrPending":
      guard let index = Int(key), cargo.indices.contains(index) else {
        throw MissionPackError("Invalid commodity.")
      }
      if action.kind == "cargoRemove" {
        let consumesOwnReservedItem =
          reservedCargo?.consume(
            index: index, amount: amount, digest: state.digest, version: state.version,
            stage: state.stage,
            markedFirearms: markedFirearms, physicalQuantity: cargo[index]) ?? false
        guard consumesOwnReservedItem || sellableCargo(index) >= amount else {
          throw MissionPackError("Marked mission cargo required.")
        }
        cargo[index] -= amount
      } else if cargo[index] > Int.max / 17 - amount {
        if action.kind == "cargoRewardOrPending" {
          state.flags["pendingGold"] = 1
        } else {
          throw MissionPackError("Make space for mission cargo.")
        }
      } else {
        guard Commodity.all[index].unit != "t" || cargoTonnes + amount <= capacity else {
          throw MissionPackError("One free tonne required - back to trade.")
        }
        cargo[index] += amount
        if action.kind == "cargoRewardOrPending" { state.receipts.insert("goldDelivery") }
      }
    default: throw MissionPackError("Unsupported action.")
    }
  }
}

extension GameRuntime {
  public func loadMissionPacks(directory: URL = MissionPackLibrary.userDirectory) {
    game.replaceMissionPacks(.installed(directory: directory))
    game.migrateMissionProgress()
  }
  public func installMissionPack(from url: URL, directory: URL = MissionPackLibrary.userDirectory)
    throws
  {
    let entry = try MissionPackLibrary.read(url)
    guard
      game.commander.missionProgress[entry.pack.stateID].map({
        $0.version == entry.pack.version && $0.digest == entry.digest
      }) ?? true
    else {
      throw MissionPackError(
        "This commander needs the original pack version/content. Keep that pack to resume safely.")
    }
    let disk = MissionPackLibrary.installed(directory: directory)
    guard disk.errors.isEmpty else { throw MissionPackError(disk.errors.joined(separator: "\n")) }
    let existing = disk.entries.first { $0.pack.id == entry.pack.id }
    guard existing == nil || existing?.digest == entry.digest else {
      throw MissionPackError(
        "Pack ID already installed. Remove the old file deliberately before updating.")
    }
    let library = try MissionPackLibrary.checked(
      disk.entries.filter { $0.pack.id != entry.pack.id } + [entry])
    let files =
      FileManager.default.fileExists(atPath: directory.path)
      ? try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "toml" } : []
    let existingFile = try files.first { try MissionPackLibrary.read($0).pack.id == entry.pack.id }
    guard files.count + (existingFile == nil ? 1 : 0) <= 64 else {
      throw MissionPackError("At most 64 external packs may be installed.")
    }
    // Reinstall the original file, even if its name differs from the pack ID.
    let destination = existingFile ?? directory.appendingPathComponent(entry.pack.id + ".toml")
    guard existingFile != nil || !FileManager.default.fileExists(atPath: destination.path) else {
      throw MissionPackError("Another installed pack uses this filename.")
    }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let data = try Data(contentsOf: url)
    // Revalidate the exact bytes copied, including the identity/hash, before enabling them.
    guard try MissionPackLibrary.decode(data).digest == entry.digest else {
      throw MissionPackError("Pack changed during installation; retry with a stable file.")
    }
    try data.write(to: destination, options: .atomic)
    game.replaceMissionPacks(library)
    game.notify("MISSION PACK INSTALLED - SEE MISSION GALLERY")
  }
}
