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

  static var bundledFieldReliefDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent("l337-field-relief")
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

  static var bundledOrbitalEvacuationDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent(
      "l337-orbital-evacuation")
  }

  static var bundledOriginalRescueDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent(
      "l337-custody-rescue")
  }
  static var bundledWayfarerInductionDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent(
      "l337-wayfarer-induction")
  }

  static var bundledGlassMeridianDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent(
      "l337-glass-meridian")
  }
  static var bundledDefensiveFlightDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent(
      "l337-defensive-flight")
  }
  static var bundledSafeGunneryDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent("l337-safe-gunnery")
  }
  static var bundledFlightReceptionDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent(
      "l337-flight-reception")
  }
  static var bundledMeasuredExtractionDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent(
      "l337-measured-extraction")
  }
  static var bundledRecordRecoveryDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent(
      "l337-record-recovery")
  }
  static var bundledIdentifiedSalvageDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent(
      "l337-identified-salvage")
  }
  static var bundledOriginalSurveyDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent(
      "l337-consented-survey")
  }
  static var bundledOrbitalOutlookDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent(
      "l337-orbital-outlook")
  }

  static var bundledCabinJourneyDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent("l337-cabin-journey")
  }

  @inline(never)
  static func defaultLibrary(directory: URL = userDirectory) -> (
    packs: [ScriptPack], errors: [String]
  ) {
    // Keep installed versions and their original ordering. Only identical content deduplicates.
    var library = installed(directory: directory)
    appendBundledPack(bundledCourierDirectory, errorPrefix: "Bundled courier pack: ", to: &library)
    appendBundledPack(
      bundledBondedFreightDirectory, errorPrefix: "Bundled bonded freight pack: ", to: &library)
    appendBundledPack(
      bundledColdChainDirectory, errorPrefix: "Bundled cold-chain pack: ", to: &library)
    appendBundledPack(
      bundledRepairLoopDirectory, errorPrefix: "Bundled repair-loop pack: ", to: &library)
    appendBundledPack(
      bundledSeedTransferDirectory, errorPrefix: "Bundled seed-transfer pack: ", to: &library)
    appendBundledPack(
      bundledMutualContributionDirectory, errorPrefix: "Bundled mutual contribution pack: ",
      to: &library)
    appendBundledPack(
      bundledNavigationTradeDirectory, errorPrefix: "Bundled navigation/trade pack: ", to: &library)
    appendBundledPack(
      bundledSealedDispatchDirectory, errorPrefix: "Bundled sealed-dispatch pack: ", to: &library)
    appendBundledPack(
      bundledVerifiedWarrantDirectory, errorPrefix: "Bundled verified warrant pack: ", to: &library)
    appendBundledPack(
      bundledCorridorDefenceDirectory, errorPrefix: "Bundled corridor defence pack: ", to: &library)
    appendBundledPack(
      bundledConsentedFreightDirectory, errorPrefix: "Bundled consented freight pack: ",
      to: &library)
    appendBundledPack(
      bundledCabinJourneyDirectory, errorPrefix: "Bundled native cabin journey pack: ", to: &library
    )
    appendBundledPack(
      bundledOrbitalOutlookDirectory, errorPrefix: "Bundled orbital outlook journey pack: ",
      to: &library)
    appendBundledPack(
      bundledOriginalRescueDirectory, errorPrefix: "Bundled original custody rescue pack: ",
      to: &library)
    appendBundledPack(
      bundledOrbitalEvacuationDirectory, errorPrefix: "Bundled evacuation pack: ", to: &library)
    appendBundledPack(
      bundledOriginalSurveyDirectory, errorPrefix: "Bundled consented survey pack: ", to: &library)
    appendBundledPack(
      bundledIdentifiedSalvageDirectory, errorPrefix: "Bundled identified salvage pack: ",
      to: &library)
    appendBundledPack(
      bundledRecordRecoveryDirectory, errorPrefix: "Bundled crew record recovery pack: ",
      to: &library)
    appendBundledPack(
      bundledFieldReliefDirectory, errorPrefix: "Bundled field-relief pack: ", to: &library)
    appendBundledPack(
      bundledMeasuredExtractionDirectory, errorPrefix: "Bundled measured extraction pack: ",
      to: &library)
    appendBundledPack(
      bundledDefensiveFlightDirectory, errorPrefix: "Bundled defensive flight pack: ", to: &library)
    appendBundledPack(
      bundledSafeGunneryDirectory, errorPrefix: "Bundled safe gunnery pack: ", to: &library)
    appendBundledPack(
      bundledFlightReceptionDirectory, errorPrefix: "Bundled flight practice pack: ", to: &library)
    appendBundledPack(
      bundledWayfarerInductionDirectory, errorPrefix: "Bundled Exchange induction: ", to: &library)
    appendBundledPack(
      bundledInductionArkDirectory, errorPrefix: "Bundled registered seed ark: ", to: &library)
    appendBundledPack(
      bundledInductionCrewLogDirectory, errorPrefix: "Bundled Cevilis custody source: ",
      to: &library)
    appendBundledPack(
      bundledInductionUtilityDirectory, errorPrefix: "Bundled Enron utility source: ", to: &library)
    appendBundledPack(
      bundledGlassMeridianDirectory, errorPrefix: "Bundled Glass Meridian: ", to: &library)
    appendBundledPack(
      bundledInductionClinicDirectory, errorPrefix: "Bundled original Renas clinic source: ",
      to: &library)
    appendBundledPack(
      bundledInductionWorkshopDirectory, errorPrefix: "Bundled original Enmadan workshop: ",
      to: &library)
    appendBundledPack(
      bundledInductionSeedDirectory, errorPrefix: "Bundled original Enlirin seed: ", to: &library)
    return library
  }

  @inline(never)
  private static func appendBundledPack(
    _ directory: URL, errorPrefix: String,
    to library: inout (packs: [ScriptPack], errors: [String])
  ) {
    // Only one decoded pack is live here while its reader validates nested declarations.
    do {
      let pack = try read(directory)
      if !library.packs.contains(where: { $0.digest == pack.digest }) { library.packs.append(pack) }
    } catch {
      library.errors.append(errorPrefix + error.localizedDescription)
    }
  }
}
