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

  static var bundledMutualContributionDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent(
      "l337-mutual-contribution")
  }

  static var bundledNavigationTradeDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent(
      "l337-navigation-trade")
  }

  static var bundledSealedDispatchDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent(
      "l337-sealed-dispatch")
  }

  static var bundledVerifiedWarrantDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent(
      "l337-verified-warrant")
  }

  static var bundledCorridorDefenceDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent(
      "l337-corridor-defence")
  }

  static var bundledConsentedFreightDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent(
      "l337-consented-freight")
  }

  static var bundledOriginalRescueDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent(
      "l337-custody-rescue")
  }
  static var bundledOrbitalOutlookDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent(
      "l337-orbital-outlook")
  }

  static var bundledCabinJourneyDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent("l337-cabin-journey")
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
    do {
      let contribution = try read(bundledMutualContributionDirectory)
      if !library.packs.contains(where: { $0.digest == contribution.digest }) {
        library.packs.append(contribution)
      }
    } catch {
      library.errors.append("Bundled mutual contribution pack: " + error.localizedDescription)
    }
    do {
      let navigationTrade = try read(bundledNavigationTradeDirectory)
      if !library.packs.contains(where: { $0.digest == navigationTrade.digest }) {
        library.packs.append(navigationTrade)
      }
    } catch {
      library.errors.append("Bundled navigation/trade pack: " + error.localizedDescription)
    }
    do {
      let sealedDispatch = try read(bundledSealedDispatchDirectory)
      if !library.packs.contains(where: { $0.digest == sealedDispatch.digest }) {
        library.packs.append(sealedDispatch)
      }
    } catch {
      library.errors.append("Bundled sealed-dispatch pack: " + error.localizedDescription)
    }
    do {
      let warrant = try read(bundledVerifiedWarrantDirectory)
      if !library.packs.contains(where: { $0.digest == warrant.digest }) {
        library.packs.append(warrant)
      }
    } catch {
      library.errors.append("Bundled verified warrant pack: " + error.localizedDescription)
    }
    do {
      let corridor = try read(bundledCorridorDefenceDirectory)
      if !library.packs.contains(where: { $0.digest == corridor.digest }) {
        library.packs.append(corridor)
      }
    } catch {
      library.errors.append("Bundled corridor defence pack: " + error.localizedDescription)
    }
    do {
      let supplied = try read(bundledConsentedFreightDirectory)
      if !library.packs.contains(where: { $0.digest == supplied.digest }) {
        library.packs.append(supplied)
      }
    } catch {
      library.errors.append("Bundled consented freight pack: " + error.localizedDescription)
    }
    do {
      let journey = try read(bundledCabinJourneyDirectory)
      if !library.packs.contains(where: { $0.digest == journey.digest }) {
        library.packs.append(journey)
      }
    } catch {
      library.errors.append("Bundled native cabin journey pack: " + error.localizedDescription)
    }
    do {
      let outlook = try read(bundledOrbitalOutlookDirectory)
      if !library.packs.contains(where: { $0.digest == outlook.digest }) {
        library.packs.append(outlook)
      }
    } catch {
      library.errors.append("Bundled orbital outlook journey pack: " + error.localizedDescription)
    }
    do {
      let rescue = try read(bundledOriginalRescueDirectory)
      if !library.packs.contains(where: { $0.digest == rescue.digest }) {
        library.packs.append(rescue)
      }
    } catch {
      library.errors.append("Bundled original custody rescue pack: " + error.localizedDescription)
    }
    return library
  }
}
