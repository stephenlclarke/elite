import Foundation

extension ScriptPackLibrary {
  public static var userDirectory: URL {
    FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
      ".xyzzy/elite/script-packs")
  }

  static var bundledCourierDirectory: URL {
    let resources =
      Bundle.main.resourceURL.flatMap {
        Bundle(url: $0.appendingPathComponent("Elite_EliteCore.bundle"))
      } ?? Bundle.module
    return resources.resourceURL!.appendingPathComponent("ScriptPacks/generated-couriers")
  }

  static var bundledBondedFreightDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent(
      "l337-bonded-freight")
  }

  static var bundledColdChainDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent("l337-cold-chain")
  }

  static var bundledRepairLoopDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent("l337-repair-loop")
  }

  static var bundledSeedTransferDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent("l337-seed-transfer")
  }

  static func defaultLibrary(directory: URL = userDirectory) -> (
    packs: [ScriptPack], errors: [String]
  ) {
    // Keep installed versions and their original ordering. Only identical content deduplicates.
    var library = installed(directory: directory)
    do {
      let courier = try read(bundledCourierDirectory)
      if !library.packs.contains(where: { $0.digest == courier.digest }) {
        library.packs.append(courier)
      }
    } catch {
      library.errors.append("Bundled courier pack: " + error.localizedDescription)
    }
    do {
      let bonded = try read(bundledBondedFreightDirectory)
      if !library.packs.contains(where: { $0.digest == bonded.digest }) {
        library.packs.append(bonded)
      }
    } catch {
      library.errors.append("Bundled bonded freight pack: " + error.localizedDescription)
    }
    do {
      let coldChain = try read(bundledColdChainDirectory)
      if !library.packs.contains(where: { $0.digest == coldChain.digest }) {
        library.packs.append(coldChain)
      }
    } catch {
      library.errors.append("Bundled cold-chain pack: " + error.localizedDescription)
    }
    do {
      let repairLoop = try read(bundledRepairLoopDirectory)
      if !library.packs.contains(where: { $0.digest == repairLoop.digest }) {
        library.packs.append(repairLoop)
      }
    } catch {
      library.errors.append("Bundled repair-loop pack: " + error.localizedDescription)
    }
    do {
      let seedTransfer = try read(bundledSeedTransferDirectory)
      if !library.packs.contains(where: { $0.digest == seedTransfer.digest }) {
        library.packs.append(seedTransfer)
      }
    } catch {
      library.errors.append("Bundled seed-transfer pack: " + error.localizedDescription)
    }
    return library
  }
}
