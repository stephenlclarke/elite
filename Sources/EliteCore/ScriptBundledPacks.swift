import Foundation

extension ScriptPackLibrary {
  static var bundledIsolationWorkDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent(
      "l337-isolation-work-source")
  }
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
    do {
      let evacuation = try read(bundledOrbitalEvacuationDirectory)
      if !library.packs.contains(where: { $0.digest == evacuation.digest }) {
        library.packs.append(evacuation)
      }
    } catch { library.errors.append("Bundled evacuation pack: " + error.localizedDescription) }
    do {
      let survey = try read(bundledOriginalSurveyDirectory)
      if !library.packs.contains(where: { $0.digest == survey.digest }) {
        library.packs.append(survey)
      }
    } catch {
      library.errors.append("Bundled consented survey pack: " + error.localizedDescription)
    }
    do {
      let recovery = try read(bundledIdentifiedSalvageDirectory)
      if !library.packs.contains(where: { $0.digest == recovery.digest }) {
        library.packs.append(recovery)
      }
    } catch {
      library.errors.append("Bundled identified salvage pack: " + error.localizedDescription)
    }
    do {
      let recorder = try read(bundledRecordRecoveryDirectory)
      if !library.packs.contains(where: { $0.digest == recorder.digest }) {
        library.packs.append(recorder)
      }
    } catch {
      library.errors.append("Bundled crew record recovery pack: " + error.localizedDescription)
    }
    do {
      let relief = try read(bundledFieldReliefDirectory)
      if !library.packs.contains(where: { $0.digest == relief.digest }) {
        library.packs.append(relief)
      }
    } catch {
      library.errors.append("Bundled field-relief pack: " + error.localizedDescription)
    }
    do {
      let extraction = try read(bundledMeasuredExtractionDirectory)
      if !library.packs.contains(where: { $0.digest == extraction.digest }) {
        library.packs.append(extraction)
      }
    } catch {
      library.errors.append("Bundled measured extraction pack: " + error.localizedDescription)
    }
    do {
      let practice = try read(bundledFlightReceptionDirectory)
      if !library.packs.contains(where: { $0.digest == practice.digest }) {
        library.packs.append(practice)
      }
    } catch { library.errors.append("Bundled flight practice pack: " + error.localizedDescription) }
    do {
      let induction = try read(bundledWayfarerInductionDirectory)
      if !library.packs.contains(where: { $0.digest == induction.digest }) {
        library.packs.append(induction)
      }
    } catch { library.errors.append("Bundled Exchange induction: " + error.localizedDescription) }
    do {
      let ark = try read(bundledInductionArkDirectory)
      if !library.packs.contains(where: { $0.digest == ark.digest }) { library.packs.append(ark) }
    } catch { library.errors.append("Bundled registered seed ark: " + error.localizedDescription) }
    do {
      let source = try read(bundledInductionCrewLogDirectory)
      if !library.packs.contains(where: { $0.digest == source.digest }) {
        library.packs.append(source)
      }
    } catch {
      library.errors.append("Bundled Cevilis custody source: " + error.localizedDescription)
    }
    do {
      let source = try read(bundledInductionUtilityDirectory)
      if !library.packs.contains(where: { $0.digest == source.digest }) {
        library.packs.append(source)
      }
    } catch { library.errors.append("Bundled Enron utility source: " + error.localizedDescription) }
    do {
      let source = try read(bundledIsolationWorkDirectory)
      guard NativeIsolationWorkPack.matches(source) else { throw SaveError.invalidCommander }
      if !library.packs.contains(where: { $0.digest == source.digest }) {
        library.packs.append(source)
      }
    } catch {
      library.errors.append("Bundled Renas isolation source: " + error.localizedDescription)
    }
    do {
      let opening = try read(bundledGlassMeridianDirectory)
      if !library.packs.contains(where: { $0.digest == opening.digest }) {
        library.packs.append(opening)
      }
    } catch { library.errors.append("Bundled Glass Meridian: " + error.localizedDescription) }
    do {
      let clinic = try read(bundledInductionClinicDirectory)
      if !library.packs.contains(where: { $0.digest == clinic.digest }) {
        library.packs.append(clinic)
      }
    } catch {
      library.errors.append("Bundled original Renas clinic source: " + error.localizedDescription)
    }
    do {
      let workshop = try read(bundledInductionWorkshopDirectory)
      if !library.packs.contains(where: { $0.digest == workshop.digest }) {
        library.packs.append(workshop)
      }
    } catch {
      library.errors.append("Bundled original Enmadan workshop: " + error.localizedDescription)
    }
    return library
  }
}
